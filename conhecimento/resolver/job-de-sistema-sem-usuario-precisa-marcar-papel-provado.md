## Job de sistema sem usuário logado lê `papeis_empresa` vazio sob RLS — falta `marcarPapelProvado` {#job-de-sistema-sem-usuario-precisa-marcar-papel-provado}

`tags: rls, row level security, postgres, multi-tenant, scheduler, background job, papel_provado, tenant_context, whatsapp, sqlite, falso verde`

**Contexto:** um job do agendador (sem requisição HTTP, sem usuário autenticado) itera empresas e
precisa notificar **todos os membros com um perfil específico** de cada uma — por exemplo, mandar
WhatsApp para admins/responsáveis financeiros quando um orçamento estoura. O código declara o
tenant (`aplicarContextoDaEmpresa`) e consulta `Usuario JOIN PapelEmpresa WHERE empresa_id = ...`.
A suíte inteira passa em SQLite. Em produção (PostgreSQL, RLS ativa), o job roda sem erro nenhum,
sem log de falha — e **nunca encontra destinatário nenhum**, em nenhuma empresa, sempre.

**Causa raiz:** a política de `papeis_empresa` (ver [[contexto-de-tenant-nao-e-prova-de-acesso]])
libera leitura por dois ramos:

```sql
usuario_id = app.usuario_id
OR (empresa_id = app.empresa_id AND app.papel_provado = 'true')
```

Um job de sistema não tem usuário de sessão — `app.usuario_id` nunca é definido, então o primeiro
ramo nunca casa. E `aplicarContextoDaEmpresa` sozinho só define `app.empresa_id`; ele **não** marca
`app.papel_provado`, porque essa marca é, por design, reservada para depois que uma dependência de
autorização de request (`getPapelNaEmpresa`) já encontrou o papel do chamador. Sem os dois ramos do
`OR` satisfeitos, o `SELECT` devolve **zero linhas**, sempre — não uma exceção, não um log, um
conjunto vazio indistinguível de "esta empresa não tem ninguém com este perfil".

**Por que ninguém viu antes:** SQLite não tem RLS — o `SELECT` enxerga tudo, e os 3-5 testes do job
(disparo, dedup, falha de envio) passam verdes idênticos com e sem o `marcarPapelProvado`. O mesmo
mecanismo de "ausência de mecanismo mascara o defeito" do
[[script-sob-rls-sem-contexto-duplica-calado]], só que aqui o sintoma não é duplicar, é **calar**:
o job "funciona" (não quebra o tick, `_rodarJob` isola a exceção que não existe) e simplesmente
nunca envia nada, para sempre, em silêncio.

**Solução:** chame `marcarPapelProvado(session)` logo depois de `aplicarContextoDaEmpresa(session,
empresaId)`, dentro do mesmo bloco por empresa — o job de sistema, tendo acabado de estabelecer
(e limitar) o contexto de uma empresa específica, é exatamente o consumidor legítimo do segundo
ramo do `OR`: ele não representa nenhum usuário, mas está autorizado a enxergar a empresa inteira
que ele mesmo já escolheu processar.

```python
await aplicarContextoDaEmpresa(sessaoEmpresa, empresaId)
await marcarPapelProvado(sessaoEmpresa)   # sem isto, papeis_empresa devolve zero linhas sempre
await _rodar(sessaoEmpresa, apenasEmpresaId=empresaId)
```

**Como provar sem PostgreSQL real:** SQLite não reproduz a negação de RLS, então a prova possível
na suíte é por **chamada**, não por efeito — monkeypatch nas duas funções com um spy que registra
ordem, chama `checkJob()` sem `session` (caminho de produção, que abre a própria sessão), e afirma
que ambas foram chamadas e na ordem certa:

```python
monkeypatch.setattr(job, "AsyncSessionLocal", TestSessionLocal)  # aponta pro banco da suíte
chamadas = []
monkeypatch.setattr(job, "aplicarContextoDaEmpresa", _spy("contexto", original1))
monkeypatch.setattr(job, "marcarPapelProvado", _spy("papel", original2))
await job.checkJob()  # sem argumento — caminho SEM session que abre sessão própria
assert chamadas.index("contexto") < chamadas.index("papel")
```

Sabotagem obrigatória: comente a chamada, rode o teste, confirme o vermelho — senão a guarda não
prova nada.

**Medido em:** Empresa Milionária, `orcamento_alerts_pj.py` (Task 11, Orçamento PJ backend,
2026-08-28) — achado por review cross-provider (R11), não pela suíte. Mesma classe do defeito
histórico de `getPapelNaEmpresa` (ADR-0009).

**Relacionados**

- [[contexto-de-tenant-nao-e-prova-de-acesso]]
- [[script-sob-rls-sem-contexto-duplica-calado]]
