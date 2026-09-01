## Filtro `pytest -k <palavra>` não pega guarda de conjunto fechado quando o nome do arquivo não contém a palavra {#filtro-k-de-teste-nao-pega-guarda-de-conjunto-fechado-em-arquivo-de-nome-nao-obvio}

`tags: pytest, -k filtro, conjunto fechado, closed-set guard, regressao, cron jobs, verificacao parcial, full suite`

**Sintoma:** uma mudança aditiva e aparentemente segura (registrar mais um cron job num worker que já
tem N outros) quebra dois testes que NINGUÉM viu falhar — nem a verificação do implementador, nem a
checagem seguinte do controller/revisor — porque ambos rodaram `pytest tests/ -k "worker"` em vez da
suíte inteira, e o arquivo que guarda a regra ("a lista de crons registrados é EXATAMENTE esta,
contada e nomeada") tinha um nome que não continha a palavra `worker`
(`test_wa_ghl_inbound_cron.py` — sobre WhatsApp/GHL, não sobre "worker" per se, mesmo testando código
de `app/workers/`).

**Causa raiz:** `-k <palavra>` filtra por **nome do teste/arquivo**, não por **o que o teste
realmente guarda**. Um teste de conjunto fechado (`CRONS_ESPERADOS = {...}` + `assert len(x) ==
len(CRONS_ESPERADOS)`) é exatamente o tipo de guarda que qualquer adição precisa atualizar — mas o
nome do arquivo que o contém pode não sinalizar isso de jeito nenhum pra quem só olha a lista de
arquivos rapidamente ou usa um filtro de conveniência.

**Por que os dois filtros (implementador E revisor) bateram na mesma cegueira:** os dois escolheram
`-k "worker"` pelo MESMO motivo razoável (a mudança era em `app/workers/`) — mas a palavra "worker"
não aparece no nome do arquivo que guarda a contagem, então os dois filtros erraram do mesmo jeito,
de forma correlacionada. Um segundo par de olhos não ajuda quando os dois usam a mesma heurística de
busca.

**Solução:** para QUALQUER mudança que adiciona/remove algo que algum teste em algum lugar pode
contar exaustivamente (crons, rotas, migrations, feature flags, itens de menu), a única verificação
que realmente fecha é a suíte **inteira**, sem filtro de palavra-chave:

```bash
python -m pytest tests/ -q   # sem -k, sem --collect-only, a suíte toda
```

Um filtro `-k` é aceitável pra iteração RÁPIDA durante o desenvolvimento (loop apertado, ver se a
lógica que você está mexendo passa), mas nunca é a evidência final antes de aceitar uma task/PR como
pronta — só a suíte cheia prova que nada em qualquer lugar do repo quebrou, inclusive testes cujo
nome não sugere relação com o que você mudou.

**Ref:** Paid Media Automation, fila #7, Task 5 (registrar `hubspot_deals_sync_job` no cron) —
quebrou `test_wa_ghl_inbound_cron.py::test_cron_jobs_registrados_sao_exatamente_os_esperados` e
`::test_cron_jobs_count`. Só apareceu quando a Task SEGUINTE (Task 6) rodou a suíte inteira sem
filtro como parte da própria verificação, revelando que uma task já marcada "completa" tinha uma
regressão viva havia duas tasks.
