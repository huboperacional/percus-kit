## Rota nunca chama `commit()` — resposta 200 correta, escrita nunca sobrevive ao fim da sessão {#rota-nunca-comita-resposta-200-com-escrita-fantasma}

tags: fastapi, sqlalchemy, async session, commit, rollback implicito, row level security,
transacao, getSession, caso de uso, escrita fantasma, 200 enganoso

**O padrão que engana:** um projeto adota a disciplina certa de "caso de uso não commita" —
`ProvisionarUsuario.executar()`, `CriarPedido.executar()` etc. só fazem `session.add()` /
`session.flush()`, nunca `session.commit()`. A razão costuma ser boa e documentada: com RLS
por `SET LOCAL`, o primeiro `commit()` de um handler mata o contexto de isolamento pro resto
da função (ver o parente [[rls-with-check-nao-existe-para-delete]] e a classe geral "não use a
sessão depois do commit"). A disciplina "quem escreve não commita, quem orquestra commita" é
correta — mas só funciona se **alguém, em algum lugar, realmente commitar**.

**O buraco:** a rota que ORQUESTRA o caso de uso — que deveria ser esse "alguém" — só monta a
resposta e retorna. Sem `await session.commit()` em lugar nenhum do caminho de sucesso. O
dependency de sessão (`getSession()` do FastAPI) só **fecha** a sessão no `finally`:

```python
async def getSession():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()   # SEM commit — se nada commitou antes, isto é ROLLBACK
```

`session.close()` numa transação com mudanças pendentes e nenhum commit é **rollback
implícito** do SQLAlchemy — não um erro, não um aviso, silêncio total.

**Por que o sintoma é o pior possível — pior que um 500:**
- A rota devolve **200**, com o objeto de resposta construído a partir dos dados que ACABARAM
  de ser escritos na sessão (via `flush()`, que empurra pro banco DENTRO da transação aberta —
  visível pra si mesma, exatamente como qualquer leitura dentro da mesma transação veria).
- O cliente (frontend, teste, humano lendo a tela) vê sucesso genuíno: toast de boas-vindas,
  navegação pra tela seguinte, nenhum erro.
- **Nada disso prova que o dado sobreviveu.** A única forma de descobrir é olhar o banco por
  uma conexão/sessão DIFERENTE, depois que a requisição original já terminou — exatamente o
  que nenhuma suíte de teste comum faz, porque teste comum ASSERTA sobre a resposta HTTP ou
  sobre a MESMA sessão que fez a escrita.

**Por que a suíte padrão (SQLite, mesma sessão) nunca pega isso:** um teste típico de rota via
`TestClient`/`AsyncClient` com dependency override reusa a MESMA sessão (ou uma sessão que
compartilha a mesma transação) pra fazer a chamada E pra inspecionar o resultado depois. Ler a
própria escrita dentro da mesma transação funciona perfeitamente **com ou sem commit** — é
comportamento SQL básico, não RLS, não Postgres-específico. A suíte fica verde por construção,
não por acerto. Só uma verificação que abre uma sessão NOVA (um segundo `AsyncClient`, uma
query direta com outro `engine`, ou — o caso real que achou isto — uma consulta manual ao banco
de PRODUÇÃO horas depois) revela que a linha nunca existiu fora daquela transação.

**A guarda estática irmã não cobre esta classe.** Um guard tipo "nenhuma rota usa a sessão
DEPOIS do commit" (AST, procura `session.<verbo>` após `await session.commit()` na mesma
função) prova o oposto do que se precisa aqui: ele confirma que ONDE HÁ commit, nada vem
depois — mas não tem como provar "existe commit nenhum". Ausência de padrão não é padrão
capturável por grep/AST sem uma lista positiva do que É esperado (ex.: todo handler POST/PATCH
que chama um caso de uso não-commitante DEVE ter exatamente um `session.commit()` no caminho de
sucesso) — que é um guard mais caro de escrever e mais fácil de esquecer de manter.

**Como se prova certo:**
```python
resposta = MinhaResposta(...)      # monta ANTES, contexto de RLS ainda vivo se houver
await session.commit()             # só agora a escrita sobrevive ao fim da requisição
return resposta
```
E a prova real, não a de papel: rode a rota de verdade (via HTTP, contra Postgres real ou até
SQLite com uma sessão SEPARADA pra reler), then **abra uma sessão nova** e confirme a linha —
nunca confie na resposta 200 nem numa leitura feita pela MESMA sessão que escreveu.

**Como foi achado:** não por teste nenhum — por medir a tela em produção (Playwright real,
OTP real) e DEPOIS checar o banco de produção por uma conexão independente (`docker exec` +
uma nova engine SQLAlchemy). A tabela tinha 1 linha só, de 11 dias atrás; a que a tela acabara
de "criar com sucesso" nunca apareceu. R1 (só produção prova) provou de novo por que existe.

**Ref:** Empresa Milionária, Frente A (primeiro acesso via WhatsApp provado), achado na prova
final pela tela em produção, 2026-08-27. `app/modules/pj/rotas_convite.py::primeiroAcesso`,
`app/core/database.py::getSession`, `app/core/commit_e_contexto.py` (o parente que documenta
"monte a resposta antes do commit" — mas só pro caso onde o commit JÁ acontece).
