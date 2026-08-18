## Feature que depende de LLM ou dado real não fecha [5-T] sem smoke em prod com a FRASE/DADO EXATO do caso original {#smoke-prod-feature-llm}

`tags: smoke prod llm 5t frase-exata dado-real validacao feature`

**Sintoma:** feature "pronta" com testes verdes + review/conselho aprovando, mas que quebra no
caso real. Aconteceu no D16/tiatendo (2026-07-16): **1128 testes verdes + 3 passadas de conselho
cross-Claude + GO explícito**, e o smoke da frase exata do print em prod achou **2 defeitos que
matavam a feature inteira**.

**Por quê teste e review não pegam:** ambos provam o que você IMAGINOU que acontece. Os defeitos
vivem no que só o ambiente real sabe:
1. **Por qual guard/branch o texto real passa.** No D16 eu instrumentei o guard errado — a frase
   caía num TERCEIRO guard de defer (`unknown_item`), não no que eu cobri. Meus testes, montados em
   cima da minha hipótese, passavam. O conselho leu o mesmo código com a mesma premissa.
2. **Em que formato o LLM/serviço real devolve os dados.** O LLM mandava `ref='Feijoada [G]'` (com
   a variante); meu consumo comparava com o nome canônico `'Feijoada'` → **nunca casava**. Toda a
   lógica estava "certa" contra o formato que EU supus.

**Solução:**
- Feature LLM/integração **não fecha `[5-T]` sem smoke em prod com a FRASE/DADO EXATO do caso
  original** — não vale phrasing "equivalente" (foi phrasing limpo que passou o tempo todo enquanto
  o do print quebrava).
- Conferir o resultado **no destino final** (ex.: `order_items.line_notes` no banco), não na resposta
  intermediária.
- Quando achar o defeito, **procure a CLASSE**: achei 1 guard não coberto → varri e achei 4 →
  virou ponto único (`_deferToFlow`) + **teste estrutural** que reprova se aparecer um defer cru
  novo. Fix pontual deixaria o próximo guard reabrir o buraco.
- Casamento de identificador vindo de LLM: **conjunto fechado** de formas aceitas
  (`name`, `name var`, `name [var]`, `name (var)`), nunca substring (`in`) — "coca" bateria em
  "Coca-Cola Zero" e colaria no item errado.

**Reincidência 2026-07-31 (tiatendo, 3 deploys num dia) — e o que ela acrescenta:** **6088 testes
verdes**, **conselho de 3 membros**, **2 rodadas de review R11** (que bloquearam e acharam defeito
real), e ainda assim **2 defeitos só apareceram quando uma frase de gente de verdade entrou por um
WhatsApp de verdade** — cada um **minutos depois** do deploy anterior:
- `0.267.0` → o smoke achou o bot **reperguntando o bairro que estava na frase**, no caminho de
  **troca** de endereço, que **tinha nascido naquele mesmo lote**. Código novo violando a invariante
  do próprio lote é ponto cego estrutural: a suíte foi escrita olhando o caminho novo, não o velho.
- `0.268.0` → o smoke achou o **primeiro** defeito vindo do interpretador LLM: ele entendeu o pedido
  **certo** e mesmo assim duplicou o rótulo de tamanho num campo de texto livre, que virou pergunta
  órfã e **engoliu o "pode fechar"** do cliente.

Corolário de cadência: **smoke não é a última linha do checklist, é etapa de descoberta.** Se cada
deploy do dia rendeu um defeito no smoke seguinte, o ciclo é `deploy → smoke com frase de gente →
fix → deploy`, e "acabou" é o smoke que **não** achou nada — não a suíte verde. E confira o payload
**no destino final** (aqui: a linha na tabela `pendency`), não a resposta que o bot mandou.

**Ref:** tiatendo D16/B7 Fase 2 (2026-07-16→17). Fixes `4dd5bd5` (`_deferToFlow` + guard estrutural),
`e27834f` (`_refMatchesItem`). Reincidência de 2026-07-31: commits `4f369ca`, `bcd8ccf` (PROD
`0.268.0`/`0.269.0`), ADR-0014 do tiatendo. Memórias
`feedback-smoke-prod-pega-o-que-teste-e-conselho-nao-pegam`,
`project-4-frentes-e1-i1-reaper-d16-0222-2026-07-16`. Irmão: renderizar template sem DB p/ `[5-T]`
de tela, e pg efêmero p/ testes de DB que pulam em silêncio.
