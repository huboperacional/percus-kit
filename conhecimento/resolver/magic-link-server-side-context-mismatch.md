## Magic-link mintado server-side morre no consume: `context_mismatch` {#magic-link-server-side-context-mismatch}

`tags: auth, magic-link, whatsapp, webhook, device fingerprint, context_mismatch, precedente`

**Sintoma:** o produto manda um magic-link por um canal assíncrono (WhatsApp, e-mail de worker) e o
usuário clica minutos depois: **"link expirou ou já foi usado"**. Não é TTL, não é preview do
mensageiro consumindo o código de uso único — o log do auth-service diz `outcome=context_mismatch`.

**Causa:** o auth-service **vincula o magic ao IP/UA de quem o mintou** (device fingerprint). Num
caminho que responde a webhook não existe browser no instante da emissão, e não há
`forwarded_for`/`user_agent` do usuário para propagar. O fingerprint do container nunca vai bater
com o aparelho de quem clica. Só funciona quando quem minta é a request do próprio browser.

**O que fazer:** mandar o **link simples** para a tela de destino. Quem tem sessão longa entra
direto; quem não tem cai no login — e o login precisa preservar o destino (`?next=`, com guard de
path relativo). Magic que falha é **beco sem saída**: a página de erro é do auth-service e não
conhece o destino, então o usuário perde o objeto de vista.

🪤 **A lição que custou mais que o bug:** o plano citava um call-site existente como prova de que o
padrão funcionava — e a **docstring daquele próprio call-site** avisava que ele falha
`context_mismatch` nesse cenário. **Precedente que EXISTE não é precedente que FUNCIONA**; ler as
três linhas do docstring custava menos que o deploy.

Relacionado: {#rota-inexistente-deixa-teste-verde}.
