## Código de sucesso não prova efeito — meça o campo que descreve o que aconteceu {#status-de-sucesso-nao-prova-efeito}

`tags: 201, 202, http status, verificacao, canal de saida, whatsapp, gowa, otp, credencial vazia, falha silenciosa, dropped_no_account, envelope de resposta`

**Contexto:** um endpoint que dispara um efeito externo (mandar WhatsApp, e-mail, push, webhook)
responde **201/202 mesmo quando o efeito não aconteceu**. O status descreve a *aceitação do pedido*,
não a *execução dele* — e essa distinção é correta em desenho assíncrono, mas destrói a verificação
de quem confere pelo código de retorno.

**Dois casos medidos no mesmo dia (2026-08-24):**

1. **Convite por WhatsApp.** `POST /convites` → **201** com o convite gravado. A credencial do
   gateway (`GOWA_BASIC_AUTH`) estava **vazia desde a primeira instalação**, seis dias antes. Todo
   convite emitido no período falhou em silêncio. O que distinguia estava no corpo, não no status:

   ```
   canais_enviados:     []                                        ← tentou e não saiu
   canais_nao_enviados: [{canal: whatsapp, motivo: Unauthorized}]
   ```

   Depois de armar a credencial, o **mesmo 201** passou a trazer `canais_enviados: ["whatsapp"]`.

2. **OTP de login.** `POST /otp/request` → **202** com `expires_at` e `destination_canonical`
   preenchidos — resposta que *parece* confirmação. Quando a audience roda com
   `otp_require_existing_account=true` e a identidade não existe, o serviço responde exatamente o
   mesmo 202 e **descarta o envio** (`outcome=dropped_no_account`). O usuário pede o código, recebe
   sucesso, e o código nunca chega.

**A regra:** verifique por um campo que descreva **efeito**, não por status. Bons campos de efeito
são os que distinguem *não tentei* de *tentei e falhou*: `canais_enviados` (`null` ≠ `[]`),
`criados`/`ja_existiam` numa varredura idempotente, `outcome` no log do serviço.

⚠️ **`null` e `[]` não são a mesma coisa, e essa é a metade que se perde primeiro.** `null` = "ainda
não tentei"; `[]` = "tentei e não saiu". Um envelope que colapse os dois em `null` já perdeu a
informação antes de chegar em quem lê.

**Diagnóstico quando o corpo não distingue:** vá ao **log do serviço que executa**, não ao da API
que aceitou. No caso do OTP, o par decisivo estava lá e em nenhum outro lugar:

```
otp.request.accepted   outcome=accepted
gowa.sent              destination=+55…  status=200      ← saiu
```

versus um `outcome=dropped_no_account` sem `gowa.sent` nenhum. **Sem esse log, os dois cenários são
indistinguíveis do lado do cliente.**

**Fix de produto:** quando o efeito é assíncrono e o status não pode carregá-lo, exponha o campo de
efeito **e mostre-o na tela**. No caso do convite, a interface já dizia `não saiu` no lugar certo —
o defeito sobreviveu porque ninguém tinha olhado, não porque o produto escondia.

⚠️ **Corolário para quem verifica deploy:** o mesmo vale para `/health` e para a tag da imagem. As
duas respondem igual antes e depois. Meça o **conteúdo** — um campo do contrato que só existe na
versão nova.

Relacionado: [[build-dir-compartilhado-tag-nova]].
