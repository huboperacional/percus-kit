## Dois autômatos que sempre respondem formam loop, e a denylist trata o caso, não a classe {#dois-automatos-que-sempre-respondem-formam-loop}

tags: whatsapp, bot, loop, anti-ban, incidente, guarda

**Sintoma.** O bot troca dezenas de mensagens com um único número em poucos minutos, sempre as
mesmas. Medido na Família Milionária em 2026-09-17: **46 mensagens em ~3 min, 23 nossas, uma a cada
~4 s**, até o operador desconectar o dispositivo na mão.

**O que era.** O outro lado era o bot de auto-resposta do suporte de um banco. O nosso fluxo de
número sem cadastro respondia qualquer entrada inválida **reenviando o menu inteiro**; o deles
respondia qualquer coisa com texto fixo. Nenhum dos dois sabia parar.

**A classe.** Não é "aquele número". Dois autômatos que **sempre respondem** formam loop infinito,
independente de quem esteja do outro lado — e basta **um** dos dois parar de responder o que não
entende para o loop morrer. Bloquear o número resolve aquele caso e deixa a classe aberta: o próximo
bot tem outro número. Pior, o payload do provedor (GOWA) **não diz** se o interlocutor é conta
business — só há `chat_id`, `body`, `push_name`, `id`, `is_from_me` —, então não dá para identificar
"é um bot" pela identidade. A detecção tem de ser por **comportamento**.

**Por que importa mais que o barulho.** Pingue-pongue entre dois autômatos é exatamente o padrão que
derruba um número no WhatsApp. Naquele projeto o dispositivo já tinha sido banido uma vez.

### Conserto imediato (um estado, uma linha)

No estado de menu, resposta inválida **não** reenvia o menu: fica em silêncio e registra em log. O
menu já foi mandado; quem for humano responde a opção e segue. Corta a amplificação sem depender de
detectar nada.

### Conserto da classe (guarda no ponto de saída)

Dois gatilhos por número, avaliados **no facade de envio** — não no handler de entrada, senão job em
massa passa por fora:

1. **Repetição:** N mensagens idênticas consecutivas numa janela curta.
2. **Teto de volume:** M envios na janela, independente do conteúdo.

O primeiro dispara cedo mas só enxerga texto fixo; resposta gerada por IA muda a cada vez e nunca
casa. O segundo é insensível a conteúdo e cobre esse caso. **Um sem o outro deixa metade do produto
exposto.**

⚠️ **Meça os limiares no seu histórico antes de escolher.** Na FM, repetição idêntica consecutiva
com usuário real aconteceu **1 vez em toda a história** (35 s), e o pico real foi 32 envios/hora e 14
por 10 min — daí 3 e 20. Travar na 2ª cópia teria barrado gente de verdade.

⚠️ **Se o replay histórico acusar falso positivo, não suba o limiar por reflexo.** Mensagem curta
legítima repetida ("ok", "sim") aparece, alguém sobe o limiar "para passar", e a detecção morre
justamente na faixa onde o loop vive — o incidente teve 23 cópias, mas a 3ª já era loop. Subir o
limiar troca um falso positivo **visível** por um falso negativo **invisível**.

⚠️ **Isente o canal transacional e o canal do próprio aviso.** Guard no ponto de saída pega *tudo*:
código de login (tranca a pessoa fora do sistema) e o aviso ao operador (se o número dele for
silenciado, o aviso de que existe um silêncio morre junto).

⚠️ **Fail-open, mas não fail-silent.** Erro de banco no guard deixa passar; se não houver teto em
memória e alarme de bypass, o mecanismo morre calado justamente nos dias em que o banco está
agitado — mesma família de [[fail-open-esconde-teste-vacuo]].

**Onde isto foi medido:** `Familia-Milionaria/docs/superpowers/specs/2026-09-17-guarda-anti-loop-whatsapp-design.md`.
