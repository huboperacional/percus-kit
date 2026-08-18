## O aviso promete o que o gate não entrega (promessa e decisão em módulos diferentes) {#promessa-e-decisao-separadas}

`tags: feature que mente, copy, enforcement, gate, bonus, acesso, paywall, billing, admin, classe de defeito`

**Origem:** Família Milionária — bot em 28/07, billing em 31/07. A **mesma classe**, em camadas diferentes.

O painel admin tinha um botão *bonificar* que estendia `familias.acesso_bonus_ate` e mandava no
WhatsApp *"🎁 sua família ganhou N meses de acesso bônus"*. Mas o **único** gate de acesso
(`familiaTemAcesso`, usado pelo 402 da API e pelo paywall do bot) lia só `Subscription.status`. O
campo era enfeite na listagem do admin. O usuário recebia a promessa e continuava bloqueado.

Três dias antes, no bot: o card dizia *"me diz o que tá errado pra eu corrigir"* e o handler só sabia
corrigir 3 dos 5 campos.

- **Onde procurar essa classe:** todo lugar que **escreve uma promessa** (copy, aviso, card, e-mail)
  sem que o mesmo commit toque o código que **decide**. Quando promessa e decisão moram em módulos
  diferentes (admin escreve, billing decide), nada acusa a divergência — nem tipo, nem teste.
- **Agravante:** o model até documentava a verdade (*"overlay visual — não altera a subscription"*),
  enquanto o texto ao usuário dizia o contrário. **Comentário honesto não conserta aviso mentiroso.**
- **Teste que pega:** afirme o EFEITO, não a escrita. "Depois de bonificar, o usuário CONSEGUE
  escrever" — não "o campo foi gravado".
