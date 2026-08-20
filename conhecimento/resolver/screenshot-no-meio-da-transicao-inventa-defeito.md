## Screenshot tirado no meio da transição inventa um defeito visual que não existe {#screenshot-no-meio-da-transicao-inventa-defeito}

`tags: screenshot, evidência visual, Playwright, transition-colors, Tailwind, tema escuro, dark mode, contraste, Radix, animação, zoom-in, data-theme, falso positivo, obturador`

**Contexto:** spec de evidência que troca o tema por atributo (`setAttribute('data-tema', 'escuro')`,
`data-theme`, classe `.dark`) e fotografa em seguida, para provar que a tela funciona nos dois temas.

**O sintoma:** a foto do tema escuro mostra **um cartão claro com texto branco por cima**, ao lado de
outro elemento já escuro. Parece contraste quebrado — o tipo de defeito que se persegue por meia hora
inspecionando tokens de cor, escopo de CSS e ordem de cascata. Diálogo fotografado logo depois de
abrir sai **translúcido**, com o conteúdo de trás vazando através dele.

**Causa raiz:** o obturador é mais rápido que a transição. O elemento que "não trocou" tem
`transition-colors` (ou `transition: background-color`) e o vizinho que trocou **não tem** — então um
interpola por 150ms enquanto o outro salta no mesmo frame. A foto congela o meio do caminho. No
diálogo é a animação de entrada do Radix (`zoom-in-95` + `fade-in`, ~200ms) pega em voo.

**Como distinguir de contraste realmente quebrado, em 10 segundos:** dois elementos **do mesmo tema**
discordando na mesma foto já é a assinatura. Contraste quebrado de verdade é estável — ele não
depende de quando você apertou o botão. Confirme colocando uma espera antes do obturador e
refotografando: se some, era o instrumento.

**Fix:** espera explícita entre trocar o tema e fotografar, e a asserção do atributo **não serve** —
`toHaveAttribute('data-tema', 'escuro')` passa no primeiro frame, antes de qualquer pixel mudar.

```ts
async function trocarTema(page: Page, tema: string) {
  await page.locator('.app').evaluate((el, t) => el.setAttribute('data-tema', t), tema)
  await expect(page.locator('.app')).toHaveAttribute('data-tema', tema)
  await page.waitForTimeout(500)   // transições de 150ms + animação do Radix (~200ms)
}
```

`waitForTimeout` é o que a documentação do Playwright desaconselha, e aqui é o certo: não existe
evento de "todas as transições da árvore terminaram" que valha a pena montar, e o custo é meio
segundo por foto. Se quiser precisão, desligue a animação para a foto
(`page.emulateMedia({ reducedMotion: 'reduce' })` ou CSS `* { transition: none !important }`) — mas
aí a evidência deixa de ser da tela que o usuário vê.

**Por que isso importa mais do que parece:** evidência que fotografa animação é **pior que evidência
nenhuma**. Ela produz um defeito para alguém perseguir e não encontrar, e gasta a confiança no
próprio mecanismo de evidência — que é o que existe justamente porque build, `tsc`, teste e `grep`
não pegam defeito visual.

**Armadilha vizinha, mesma família:** spec de screenshot que **só fotografa** passa verde
fotografando a página 404. Toda foto precisa de asserção antes: um elemento que só existe na tela
certa, e a ausência do texto de erro do framework.

**Onde apareceu:** Empresa Milionária, 2026-08-20, tela de arquivar empresa. A primeira leva de
quatro fotos saiu com o "defeito"; a segunda, com 500ms de espera, saiu limpa e provou que o produto
sempre esteve certo.
