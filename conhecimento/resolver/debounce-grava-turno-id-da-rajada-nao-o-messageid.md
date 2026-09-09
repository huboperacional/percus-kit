## Smoke/observabilidade que busca `diario_turno` pelo `messageId` enviado falha em silêncio quando o debounce está ligado — o `turno_id` gravado é o hash da rajada {#debounce-grava-turno-id-da-rajada-nao-o-messageid}

tags: debounce, diario de turno, turno_id, messageId, rajada, redis, lua, smoke, observabilidade, MSG_DEBOUNCE_ENABLED, falso inconclusivo, mid

**Contexto:** um smoke ou script de verificação envia uma mensagem com `messageId` conhecido (você
mesmo gerou o mid), espera o bot processar, e então consulta `SELECT desfecho FROM diario_turno WHERE
turno_id = '<mid>'` pra confirmar o desfecho do turno. Em produção com `MSG_DEBOUNCE_ENABLED=true`
(o caminho DOMINANTE, não um modo alternativo raro), a query não acha nenhuma linha — não porque o
turno não rodou, mas porque `turno_id` nunca foi o `messageId`.

**Causa raiz:** o debounce (`message_debounce.py`, Lua no Redis) buffer-iza mensagens de entrada numa
rajada e, ao dar flush, abre o turno com o **hash da rajada** como `turno_id` — não o `messageId` de
nenhuma mensagem individual que compôs a rajada. Isso vale mesmo pra rajada de 1 mensagem só. O
mid que você gerou pra rastrear a mensagem enviada simplesmente não é a chave que o turno usa quando o
caminho é debounced.

**Sintoma:** consulta por `turno_id = '<mid>'` volta vazia; um script que trata "vazio" como
"inconclusivo, talvez debounced" segue correto, mas um script que trata "vazio" como "não escreveu" ou
"falhou" produz falso-negativo. Casos que respondem uma pergunta curta a um menu JÁ aberto (ex.: `"1"`
como resposta a um menu de seleção) tendem a NÃO entrar no buffer de debounce (sessão não está mais
`idle`) e por isso são os únicos que a busca por mid consegue confirmar — o que faz o smoke "funcionar
parcialmente" e mascarar o buraco em vez de estourá-lo.

**Correção real (não feita ainda neste projeto):** resolver o `turno_id` da rajada via Redis (a mesma
chave/hash que o Lua do debounce usa) antes de consultar `diario_turno`, em vez de assumir
`turno_id == messageId`.

**Mitigação aceita quando a correção real não vale o custo:** documentar o caminho como
`INCONCLUSIVO` (não `PASS` nem `FAIL`) sempre que a busca por mid não achar linha, e provar os
desfechos que IMPORTAM por um caminho que não é sensível a isso — ex.: resposta curta a um menu já
aberto (sessão não-idle, não entra no buffer) ou rodando com debounce desligado nesse trecho do smoke.

**Armadilha irmã, MESMO script:** se o script também faz cleanup (`DELETE FROM diario_turno WHERE
turno_id LIKE '<prefixo-do-mid>%'`), o mesmo motivo faz o cleanup deixar órfãos: linhas com `turno_id`
= hash da rajada nunca casam o padrão do mid e sobrevivem à limpeza, acumulando silenciosamente em
produção a cada rodada do smoke. Cleanup correto: apagar por uma chave que independe do caminho de
escrita (aqui, `familia_id` via subquery em `familias.nome = <fixture>`), nunca por padrão de
`turno_id`.

**Ref:** Família Milionária, incidente da mesada, Fase 2 (diario_turno ganha `escreveu`/`perguntou`/
`recusou`), 2026-09-09. `execution/smoke_escrita_gate.py`, achado ao rodar contra produção com o
debounce ligado; 5 linhas órfãs em `diario_turno` encontradas e apagadas manualmente antes do fix de
cleanup.
