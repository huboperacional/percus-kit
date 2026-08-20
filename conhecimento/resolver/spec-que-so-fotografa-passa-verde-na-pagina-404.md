## Spec que só fotografa passa verde na página 404 {#spec-que-so-fotografa-passa-verde-na-pagina-404}

`tags: playwright, screenshot, evidência, e2e, falso-verde, verde por ausência de mecanismo, next, grupo de rota`

**Sintoma:** você escreve um spec de Playwright só para gerar evidência visual — navega, espera
`networkidle`, chama `page.screenshot()`. O spec passa. Você abre o PNG e ele é a **página 404**.

**A armadilha:** `page.goto()` de uma rota inexistente **não levanta** — 404 é uma resposta HTTP
válida, e `screenshot()` fotografa o que estiver na tela. Um spec sem `expect` não tem como estar
errado: ele não afirma nada. É "verde por ausência de mecanismo" no arquivo cuja razão de existir é
justamente provar coisa.

O erro de URL que costuma causar isso tem nome próprio no Next.js: **grupo de rota não aparece na
URL**. `src/app/(pj)/empresas/[id]/page.tsx` atende `/empresas/{id}` — o `(pj)` é pasta de
organização e some do endereço. Quem copia o prefixo da API (`/api/v1/pj/...`) para o front monta
`/pj/empresas/...` e cai em 404. O mesmo engano aparece em **código de produção**: um link enviado
por WhatsApp ou e-mail montado com o prefixo da API dá 404 no clique — e link morto não levanta
exceção, não entra em log e não vira chamado. O destinatário só desiste.

**O que fazer:** todo spec que gera evidência afirma **antes** de fotografar. Duas asserções, e as
duas importam:

```ts
async function fotografar(page, url, arquivo, ancora: RegExp) {
  await page.goto(url)
  await page.waitForLoadState('networkidle')
  // 1. âncora POSITIVA: conteúdo que só a tela certa tem
  await expect(page.getByRole('link', { name: /Visão geral/i }).first()).toBeVisible()
  await expect(page.locator('body')).toContainText(ancora)
  // 2. âncora NEGATIVA: o texto da 404 do projeto E o do framework
  await expect(page.locator('body')).not.toContainText('Essa página não existe')
  await page.screenshot({ path: arquivo, fullPage: true })
}
```

A âncora positiva ideal é algo que a 404 **estruturalmente** não tem — o menu do app, a barra
lateral, o nome do usuário logado. Texto que a 404 poderia conter por acaso (o nome do produto, que
está no `<title>` de tudo) não serve.

**Se o spec varia um estado, afirme o estado também.** Ao fotografar tema claro e escuro, confirme
o atributo ou a classe que governa o tema antes do clique do obturador. Sinal barato de que a
variação **não** aconteceu: os arquivos saem com o **mesmo `md5`**.

```bash
md5sum evidencias/*.png   # pares idênticos = você fotografou o mesmo estado duas vezes
```

Isso já pegou dois enganos seguidos no mesmo arquivo: primeiro uma chave de `localStorage` que não
existia, depois a chave **certa** — mas do tema errado, porque o painel usava um atributo próprio
(`data-tema` no elemento raiz do app) e ignorava a classe global do `<html>`.

**Relacionado:** [[teste-que-reimplementa-a-expressao-nao-prova-nada]],
[[grep-com-regex-em-css-emitido-mente]].
