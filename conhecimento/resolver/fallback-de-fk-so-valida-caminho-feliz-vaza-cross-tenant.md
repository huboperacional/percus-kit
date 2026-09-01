## Fallback de FK/coluna só valida o caminho "honrado" — o caminho de FALLBACK herda o valor sem checar o dono {#fallback-de-fk-so-valida-caminho-feliz-vaza-cross-tenant}

`tags: multi-tenant, foreign key, fallback, column_id, validação parcial, data leak, project_id, defense in depth, E2E ao vivo`

**Classe de sintoma:** um endpoint de criação recebe um `id` estrangeiro opcional do cliente (ex.
`column_id`, `category_id`) junto com o `id` do "dono" real (`project_id`/`tenant_id`). Existe uma
checagem explícita `if target.owner_id == body.owner_id: honra o id enviado` — e ELA está correta.
O problema mora no `else` (fallback): quando a checagem falha, o código tenta resolver um valor
PRÓPRIO do dono correto, mas só sobrescreve a variável se ela "ainda não tiver sido setada"
(`if final_id is None: final_id = novo_id`) — só que `final_id` foi inicializada ANTES da checagem
com o valor ESTRANGEIRO enviado pelo cliente (`final_id = body.column_id`), então nunca está `None`.
Se a busca do "valor próprio do dono correto" não encontrar nada (ex. o dono não tem esse recurso
configurado ainda), o fallback não substitui nada — o valor ESTRANGEIRO original sobrevive e é
gravado. Registro nasce com `owner_id` correto mas uma FK apontando pra um recurso de OUTRO dono.

**Por que passa despercebido:** o caminho "honrado" (o `if` que casa) está certo e é o caminho mais
testado — testes que exercitam criação normal (mesmo dono do início ao fim) nunca acionam o
fallback com um dono DIFERENTE. O bug só aparece quando: (a) o cliente ganha uma nova capacidade de
enviar um `owner_id` diferente do contexto de onde o FK estrangeiro veio (ex.: um seletor novo na
UI que permite trocar de projeto no mesmo formulário que antes sempre criava no projeto atual), E
(b) o dono de destino especificamente NÃO tem o recurso-padrão que o fallback tentaria usar (ex.:
projeto sem nenhuma coluna Kanban ainda). A combinação das duas condições é rara o bastante pra não
aparecer em teste unitário comum, mas acontece na primeira vez que um usuário real testa a
combinação.

**Fix — não confiar em "fallback só sobrescreve se ainda vazio" quando a variável nasceu com um
valor estrangeiro:** ou (1) resetar explicitamente a variável pra `None`/vazio ANTES de tentar o
fallback, sempre que a checagem de "honrado" falhar — nunca deixar o valor estrangeiro sobreviver
implicitamente; ou (2) no lado do CLIENTE, nunca enviar o `id` estrangeiro quando o dono de destino
já é conhecido como diferente do dono de origem — não gerar o payload ambíguo. A opção (2) é mais
rápida de aplicar com escopo pequeno; a opção (1) é a correção estrutural, que faz o `create`
propriamente multi-tenant-safe pra QUALQUER caller futuro, não só o caller que motivou o achado.

**Como pegar isso:** um review de código que só lê o `if` (caminho feliz) marca "ok, valida contra
o project_id" e para aí — precisa also ler o `else`/fallback até o fim e perguntar "essa variável
pode chegar aqui com um valor de OUTRO dono, e o fallback tem certeza de sobrescrevê-la em TODOS os
casos, ou só quando já está vazia?". Prova real: reproduzir o caso onde o fallback NÃO encontra
nada pra si mesmo (dono de destino sem o recurso padrão) e inspecionar o registro gravado.

**Ref:** Plexco Tasks, 2026-09-01, `create_task` (`backend/app/api/v1/tasks.py`) — `column_id`
enviado pelo board de ORIGEM sobrevivia quando o projeto de DESTINO (escolhido num Select novo do
diálogo "Nova Tarefa") não tinha coluna `column_role='todo'` própria; task nascia com `project_id`
certo mas `column_id` de um KanbanColumn de OUTRO projeto. Contido do lado cliente (nunca manda o
FK de origem quando o dono muda); o fallback do servidor não foi hardened nesta leva — fica como
dívida registrada. Achado em E2E ao vivo contra prod (org descartável), não em teste unitário nem
em review de código isolado — só apareceu inspecionando o payload real do POST via devtools de
rede depois que o comportamento pareceu "quase certo" (funcionou 1x, falhou noutra tentativa
idêntica, porque o "quase certo" dependia de o projeto de destino JÁ ter ou não uma coluna própria).
