## Suíte E2E que roda contra produção mede a tela VELHA — verde antes do deploy é falso {#suite-e2e-contra-producao-mede-a-tela-velha}

`tags: playwright, e2e, baseURL, producao, falso-verde, ordem deploy, seletores, storageState, refresh token, rotacao, CORS localhost`

**Contexto:** plano mandava "atualizar os testes E2E da página no MESMO commit" e rodar a suíte logo
após implementar. Parece disciplina; na verdade produz um verde que não significa nada.

**Causa raiz:** a suíte aponta para **produção** (`playwright.config.ts` → `baseURL:
https://app.exemplo.com`, comum quando se evita configurar CORS para localhost). O código novo está
no **repo**, não na imagem em produção. Rodar antes do deploy exercita a tela **antiga**.

**A medida que expõe:** com a versão antiga no ar e a tela nova só no repo, o spec da página passou
**2/2 — com os seletores VELHOS**, exatamente os que a tela nova quebra de propósito. Seguir o plano
teria respondido "0 seletores quebraram" e dimensionado a fase seguinte com o número errado.

**Regra:** **o deploy PRECEDE a verificação E2E.** Atualizar seletor antes do deploy é adivinhação;
rodar a suíte antes do deploy é falso-verde. Só com o vermelho real na mão o seletor novo é
verificável.

**Rodar local não é a saída barata:** `OPTIONS` da API com `Origin: http://localhost:4173|5173`
devolve **400 sem `access-control-allow-origin`** — exigiria mexer no CORS do backend de produção,
risco maior que o do deploy.

**Consequência para mudança só de CSS:** nenhum teste falha se o deploy não pegar. Nesse caso o gate
tem de conferir a **regra dentro do CSS servido** (`curl` no `/assets/*.css` procurando
`font-display:optional`, `padding-left:15px`, etc.), e não "200 na página".

**Armadilha vizinha, do token:** depois de uma corrida cheia, o renovador headless do storageState
pode devolver **401 invalid refresh**. Os testes renovam **em página** e rotacionam; se o write-back
do arquivo só existir dentro de um spec, um teste que rotacione **depois** dele deixa o arquivo uma
geração atrás. Não é determinístico. Diagnóstico em 10s: se o renovador dá 401 mas o browser com o
**mesmo** storageState ainda abre a app logado, o *access* está vivo e só o *refresh* do arquivo está
velho — dá para trabalhar até o access expirar. Conserto estrutural: write-back no **global teardown**,
não dentro de um spec.
