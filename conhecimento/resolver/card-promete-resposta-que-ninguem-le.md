## Card promete forma de resposta que ninguém lê — audite pelo ESTADO de sessão {#card-promete-resposta-que-ninguem-le}

`tags: copy promete capacidade, card sem estado, menu beco sem saida, responda com o numero, matcher, FR-8.1, auditar por estado de sessao, teste bicondicional, substring sem acento, reusar estado existente`

**Sintoma.** O card diz *"responda com o número ou com o nome"*. O usuário responde `2` e cai no
fluxo genérico, como se não tivesse respondido nada. Ninguém percebeu por meses.

**Causa.** O emissor devolve o TEXTO e não abre estado de sessão nenhum. Não existe quem leia a
resposta. Quando há N emissores do mesmo card, cada um com copy e resolvedor próprios, não existe
um lugar onde a divergência apareça.

**O método que funciona — siga o ESTADO, não o nome do handler.** Para cada card: (a) quem GRAVA o
estado que ele abre, e (b) quem LÊ esse estado. Se ninguém grava, o card é beco sem saída. Auditar
pelo nome do handler engana: em 2026-08-15 o handler que parecia responder ao card era outro — o
estado dele só nascia num emissor diferente, com copy diferente.

**Correção, nos DOIS sentidos.**
- Capacidade não existe → **tire a oferta da copy** e ensine a sintaxe que realmente re-entra.
- Capacidade existe → ofereça, mas **condicionalmente**: a linha só entra quando o estado foi
  gravado de fato. Erro cometido no mesmo dia: passar a oferecer *"ou o nome"* de forma
  INCONDICIONAL, quando o matcher recusa nomes curtos.
- **Antes de criar resolvedor/estado novo, procure o que já existe.** No mesmo caso a capacidade já
  morava em DOIS estados distintos; reusar custou 40 linhas, criar teria custado um dia e um
  caminho a mais para divergir.

**Trava:** teste **bicondicional** — `promete ⇔ resolve`. Ele pega os dois defeitos: prometer sem
capacidade e capacidade escondida. Valide a substring **sem acento** nos dois lados, senão a mutação
sem acento passa verde.
