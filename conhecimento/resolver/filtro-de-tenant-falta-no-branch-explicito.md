## Filtro de tenant falta no branch EXPLICITO enquanto o implicito, no mesmo metodo, ja o tinha {#filtro-de-tenant-falta-no-branch-explicito}

tags: multi-tenant, vazamento, isolamento, cross-tenant, filtro de tenant, branch, id no corpo, IDOR, autorizacao, review, 404 vs 403

**Sintoma:** um metodo resolve "qual tenant usar" por dois caminhos — um recebendo o id **explicito** e outro **descobrindo** pelo usuario. O caminho descoberto filtra por papel; o explicito busca so por id. Resultado: IDOR classico, com escalada.

**Contexto medido (2026-08-16):**

```python
if grupoId is not None:                       # veio do CORPO da requisicao
    return select(Grupo).where(Grupo.id == grupoId)          # SEM filtro de papel

existente = (select(Grupo)                    # caminho descoberto
    .join(PapelGrupo, PapelGrupo.grupoId == Grupo.id)
    .where(PapelGrupo.usuarioId == usuarioId))               # COM filtro de papel
```

O atacante que descobrisse o UUID de um grupo alheio criava recurso dentro dele, ganhava papel de administrador no recurso novo **e papel no grupo da vitima**, ainda consumindo a cota do plano dela.

**Causa raiz, e e o que torna o caso instrutivo:** o padrao de checagem **existia tres linhas abaixo, no mesmo metodo**. Nao foi desconhecimento da regra — foi o branch de cima nao ter recebido o tratamento que o de baixo ja tinha. E a mesma familia de "o filtro falta na consulta SECUNDARIA, nao na principal", com uma variante nova: **falta no ramo alternativo da MESMA funcao**.

**Solucao:** ponha o filtro de autorizacao **dentro da mesma consulta**, nunca como checagem posterior — separar as duas deixa a porta aberta para alguem reordenar depois e nao perceber:

```python
doUsuario = (select(Grupo)
    .join(PapelGrupo, PapelGrupo.grupoId == Grupo.id)
    .where(Grupo.id == grupoId, PapelGrupo.usuarioId == usuarioId)).first()
if doUsuario is None:
    raise GrupoNaoEncontrado("grupo nao encontrado")   # 404, nao 403
```

**404 e nao 403**, com mensagem identica a de "nao existe": resposta diferente para "nao e seu" transforma a recusa em **oraculo de quais ids existem** no banco.

**Como cacar isto no seu codigo:** procure `if <id> is not None:` (ou `??`, `||`) em funcoes que resolvem tenant/dono, e confira se **os dois ramos** aplicam o mesmo filtro. Um teste de ataque por ramo — usuario B passando o id de A — e barato e e o que faltava aqui.

**Ref:** Empresa Milionaria, 2026-08-16 — `app/casos_uso/registrar_empresa.py`, achado pelo review cross-provider (Cross-Claude) e falsificado antes do fix.
