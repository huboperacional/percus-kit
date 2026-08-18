## "Sessão de 30 dias" que morre em 2 segundos: o wipe do refresh token em falha TRANSITÓRIA {#refresh-wipe-transitorio}

`tags: refresh token, sessao curta, logout inesperado, volta pro otp, wipe de credencial, erro transitorio, 5xx, timeout, rotacao, familia de refresh, auth`

**Sintoma:** usuários voltam pro OTP o tempo todo apesar do refresh token de 30 dias. A auditoria de
código passa — o item "renova no 401?" está **PASS e correto**. A medição do lado do auth mostra
famílias de refresh com **vida mediana 0,0h**: nascem no login e nunca rotacionam.

**Causa raiz (a que mais machuca):** o cliente descarta a credencial em erro que **não é rejeição**.
No caso real: `if (!res.ok) { clearTokens() }` — que inclui **5xx** — mais `catch { clearTokens() }`
— que inclui **timeout/rede/CORS**. Com o servidor de auth reiniciando ou a rede oscilando, **um
soluço de 2 segundos custa a sessão de 30 dias**, em silêncio. O interceptor ainda completava o
serviço redirecionando pro `/login?expired=1`.

**Causa raiz (a irmã, mais citada e menos frequente):** *cold start* que não consulta o refresh. Se o
gate de sessão é `!!accessToken` e o refresh só roda reativamente no 401, então **sem access token
não sai request → não há 401 → nunca se apresenta o refresh**. O app vai pro login com a credencial
de 30 dias válida no storage e **zero** chamadas de refresh na aba Network.

**Solução:**
1. Descartar a credencial **somente** em rejeição definitiva do servidor (`401/403/422`). 5xx, 429,
   timeout e rede **preservam** — o servidor não disse que a sessão morreu.
2. O interceptor só derruba/redireciona se a credencial **já foi descartada** por quem sabe
   distinguir. Caso contrário: falha a request, não a sessão.
3. Gate de sessão conta **access OU refresh**. Mudar na fonte única cobre N telas sem editar N
   arquivos (no caso real, 21).
4. Refresh proativo no boot quando falta o access e sobra o refresh.
5. **Timeout** no fetch do refresh (8–10s). Sem ele, um servidor pendurado prende o single-flight
   pra sempre e enfileira toda renovação seguinte atrás dele — troca re-OTP por tela branca.

**Por que preservar em 5xx é seguro (confirmado no código do servidor):** o consumo do refresh é
posterior ao claim atômico. Em 502/503 de proxy e em 500 antes do claim, o token **não foi
consumido** e segue válido. E quando foi consumido, o filho se perdeu junto com a resposta — aquela
sessão já estava perdida. **Não existe cenário em que preservar piore a vida do usuário.**

**O perigo que sobra NÃO é o retry pós-5xx — é staleness entre abas:** aba A rotaciona e recebe o
filho; aba B, que leu o **mesmo** token antes, tenta 60s depois com o valor velho, cai fora da janela
de graça (~10s) e **queima a família viva** — matando a sessão que A acabou de renovar (RFC 6749
§10.4). Defesas: single-flight por aba; **ler o token do storage imediatamente antes de cada
chamada**, nunca de variável/closure capturada antes; e nada de backoff martelando o mesmo token.
Corolário: **"o token mudou?" não é sinal de nada** — `localStorage` é compartilhado entre abas; o
sinal confiável é estado por aba.

**Armadilha do teste:** os casos de falha transitória passam **antes e depois** do fix se você só
exercitar o boot — sem access token, o código antigo nem chegava no wipe. O teste que prova é o do
caminho do **interceptor**: access presente + API 401 + refresh 503 → a sessão tem que sobreviver.
Prove revertendo o fonte (`git stash`) e mantendo o spec: se não ficar vermelho, o teste é teatro.

**Ref:** Família Milionária (2026-07-27), commits `4f8c88e`/`75eb2bc`. Parente de
[#verificar-runtime-nao-estrutura](verificar-runtime-nao-estrutura.md).
