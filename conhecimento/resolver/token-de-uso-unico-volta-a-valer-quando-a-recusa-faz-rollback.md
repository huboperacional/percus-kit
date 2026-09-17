## Token de uso único volta a valer quando a recusa que vem depois do consumo faz rollback {#token-de-uso-unico-volta-a-valer-quando-a-recusa-faz-rollback}

`tags: uso unico, state, OAuth, PKCE, link de capacidade, UPDATE usado_em, rowcount, rollback, getSession, close, HTTPException, recusa, commit, FastAPI, SQLAlchemy, R23`

**Sintoma:** o token (state OAuth, link de capacidade, código) é consumido por
`UPDATE ... SET usado_em = agora WHERE usado_em IS NULL ... ` com `rowcount == 1`, e o teste "mesmo token duas vezes" passa.
Mesmo assim, depois de uma recusa, o mesmo token é aceito de novo.

**Causa:** a recusa acontece DEPOIS do `UPDATE` (provedor externo fora, escopo negado, passo seguinte falhou) e vira exceção
no handler. A dependência de sessão só faz `close()` — sem commit, o `UPDATE` de consumo é desfeito junto com o resto. O
teste de reuso só cobria **sucesso → reapresentar**; ninguém testou **recusa → reapresentar**.

**Caso concreto, medido em 16/09/2026 (Empresa Milionária, guarda do documento, Task 10 — conectar o Google Drive):**
`POST .../conexao-drive/retorno` com escopo sem `drive.file` → `422 permissao_do_drive_nao_concedida`; o MESMO `state`
com um `code` novo (reabrir a URL de consentimento dentro dos 10 min gera outro `code` para o mesmo `state` e desafio PKCE)
→ `200`, conexão ativa. O docstring da rota afirmava que o `state` "continua sem valer". 23 testes verdes.

**Conserto:** decidir o desfecho dentro do `try` (resposta OU erro), fazer **um** `commit` e só então `raise`:

```python
resposta, erro = None, None
try:
    obj = await caso.executar(...)
    resposta = Resposta(...)          # montada antes do commit (contexto SET LOCAL morre nele)
except Recusa as r:
    erro = httpDe(r)
await session.commit()                # grava o consumo também na recusa
if erro is not None:
    raise erro
return resposta
```

Só vale se, no ponto da recusa, a sessão carrega apenas o consumo (nada de escrita parcial): confira o caso de uso. Commit
dentro de cada `except` resolve o comportamento mas reprova guarda estática que lê ordem de statement ("sessão usada depois
do commit").

**Teste que pega:** parametrizar as recusas posteriores ao consumo e, para cada uma, reapresentar o token com o provedor
normalizado — esperar a recusa de token inválido e nenhuma chamada ao provedor. Sabotagem: levantar o erro antes do commit.
