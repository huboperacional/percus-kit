## Quem envia NÃO sabe o que o turno foi — deixar o ponto de envio decidir o desfecho apaga o vocabulário de recusa {#quem-envia-nao-sabe-o-que-o-turno-foi}

`tags: telemetria, observabilidade, diario de turno, bot conversacional, desfecho, precedencia, vocabulario fechado, recusa tipada, alarme, R23`

**Sintoma:** você instrumenta uma tabela de telemetria de conversa (uma linha por turno) com um campo
`desfecho` de vocabulário fechado — algo como `escreveu / perguntou / informou / recusou / fallback /
silencio` — e uma regra de precedência para quando mais de um valor caberia. Meses depois, `recusou` e
`fallback` aparecem em taxa **próxima de zero** no dashboard, enquanto o suporte segue recebendo
reclamação de bot que não entendeu. O alarme de qualidade nunca dispara.

**Causa raiz:** o ponto de envio foi ensinado a mexer no desfecho. É tentador e parece óbvio: "houve
envio, logo o turno não foi silêncio, logo é `informou`". O erro é de **autoridade** — o funil de
saída é o mesmo para um dado gravado, um card de confirmação, um "não entendi" e uma recusa
deliberada. **Quem envia não sabe o que o turno foi.**

E o estrago é silencioso por causa da precedência: se `informou` vence `recusou` e `fallback` (o que é
natural, porque informar é mais específico que falhar), e se **toda** recusa e **todo** fallback mandam
mensagem — e mandam, é a mensagem que os anuncia —, então os dois desfechos tipados são apagados **pela
própria mensagem que existe para comunicá-los**. Em qualquer ordem de chamada:

- envio **antes** da tipagem → a tipagem é bloqueada pela precedência, e o `motivo` vai junto (ele só é
  gravado dentro do ramo que passa);
- envio **depois** → o envio rebaixa o desfecho já tipado.

O resultado é `informou` com `motivo` preenchido — combinação que o próprio contrato costuma proibir —
e a queda sai do numerador do alarme. Ou seja: **o vocabulário de recusa morre calado dentro do remédio
contra o silêncio**, que é exatamente o defeito que a tabela existe para acabar.

**Correção:** separe **contar** de **decidir**.

1. O ponto de envio **só conta** (`mensagensEnviadas += n`). Não toca no desfecho.
2. Um passo de **consolidação no fim do turno** preenche o que ninguém reivindicou: se o desfecho ainda
   é `silencio` e houve envio, vira `informou`. Aplicado no fim, a **ordem das chamadas deixa de
   importar** — que é a propriedade que torna o desenho robusto a refactor.
3. A consolidação **também limpa o `motivo`** quando o desfecho não o admite. Necessário porque
   handlers registram motivo sem tipar desfecho (um filtro de privacidade negando um item, um portão
   recusando uma escrita), e sem a limpeza a promoção produziria `informou` + `motivo`.

**Não faça a viagem de volta:** desfecho tipado com **zero envios** deve ser **preservado**, nunca
rebaixado a `silencio`. Dois casos decidem: `fallback` com 0 envios é a queda de um caminho que não
manda mensagem de erro (e "caiu" ≠ "calou"); e `escreveu` com 0 envios é **escrita silenciosa** — mudou
estado e não avisou ninguém —, o alarme mais grave que a tabela pode dar. Rebaixá-lo apaga o sinal mais
importante que ela produz.

**Como provar que está certo:** teste as **quatro** combinações (envio antes/depois × `recusou`/
`fallback`) e afirme que o desfecho tipado e o motivo sobrevivem às quatro. Um teste só, numa ordem só,
passa com o bug vivo.

**Sinal de que você está diante disto:** um helper local com nome tipo `_registrarFalhaComEnvio` que
mexe no acumulador **na mão**, com um comentário explicando por que não usa a API normal. O comentário
é o bilhete de suicídio da API: o defeito é dela, não do call-site.

**Corolário para reconciliação:** o par "escreveu **e** falou" vs "escreveu e **não** falou" não precisa
sair do enum. Uma coluna de domínio do tipo `notificado_em`, NULL enquanto ninguém foi avisado, resolve
melhor: o diário é append-only e descreve o que aconteceu; a coluna é **estado corrente** e diz o que
ainda está pendente — e é consultável por quem cuida do pedido, não só por quem cuida da telemetria.
