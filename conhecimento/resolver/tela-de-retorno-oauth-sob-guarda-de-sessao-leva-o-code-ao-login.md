## Tela de retorno de OAuth sob a guarda de sessão leva o `code` para o `next` do login {#tela-de-retorno-oauth-sob-guarda-de-sessao-leva-o-code-ao-login}

`tags: oauth, code, state, next.js, app router, route group, layout, guarda de sessão, login, next, redirect, replaceState, referer, histórico, analytics, gtag, rastreador`

**Sintoma:** a spec manda a tela fixa de retorno do provedor (`/integracoes/<provedor>/retorno?code=...&state=...`) limpar a URL
com `history.replaceState` "antes de qualquer outra coisa". A tela faz isso na primeira linha do efeito, e os testes com sessão
passam. Sem sessão (expirou durante o consentimento), o navegador vai para `/login?next=%2Fintegracoes%2F...%3Fcode%3D...`: o
código fica na URL do login, no histórico e no `Referer`. Medido em 2026-09-16 (Empresa Milionária, guarda do documento, RP2).

**Causa raiz:** a página mora num grupo de rota cujo layout envolve tudo num guarda de sessão. Sem token, o guarda
**não renderiza os filhos** e redireciona com um helper que copia `pathname + search` para o `next`. O efeito da página, que
limparia a URL, nunca roda. Layout aninhado não resolve: no App Router os layouts compõem, e a página continua dentro do guarda
do pai.

**Solução:**

1. Ponha a tela de retorno num **grupo de rota próprio**, com layout sem guarda (`(app-retorno)/...`). Grupo não aparece na
   URL, então o endereço cadastrado no provedor não muda.
2. A tela confere a sessão **ela mesma, depois** de limpar a URL. Sem sessão, diz para recomeçar e não chama a API.
3. **Tire a rota dos rastreadores.** GA4 (`page_location`) e script de terceiro leem `location.href`. `afterInteractive` não
   promete rodar depois do efeito que limpa. Excluir a rota vale mais que sanear, porque script de terceiro não se saneia.
4. Teste com rede gravada: sem sessão, zero requisições, `page.url()` sem `code`, e o link de recomeçar chega ao login sem o
   `code` no `next`. Com sessão, capture `page.url()` no handler da **primeira** requisição à API.
