## `toBeVisible()` não detecta oclusão — e `toBeInViewport()` também não {#tobevisible-nao-detecta-oclusao}

`tags: playwright, e2e, assercao que nao discrimina, falso verde, layout, sticky, dialogo, screenshot, scrollIntoView, guarda`

**Contexto:** um campo novo foi acrescentado ao fim do corpo rolável de um diálogo cujo rodapé é
`position: sticky; bottom: 0`. Sete testes e2e passaram — inclusive os que preenchiam o campo e
conferiam o payload. **O screenshot mostrou o campo cortado, terminando debaixo do rodapé.**

**Por que a suíte não pegou:** o Playwright **preenche e clica em elemento fora da área visível**.
`fill()` rola até ele, escreve, e segue. A interação nunca exige que uma pessoa consiga **ver** o
campo — e é essa a diferença entre *"o dado viaja"* e *"alguém consegue digitar o dado"*.

🔴 **A primeira guarda que escrevi para isso PASSOU com o defeito presente.** Usei
`toBeInViewport()`, achando que ele mediria "está à vista". Ele aceita **interseção parcial** com
a janela, e o campo estava na janela: o que acontecia era **oclusão** por um elemento que fica por
cima, que é outra coisa. Nem `toBeVisible()` nem `toBeInViewport()` sabem o que está na frente.

**A asserção que discrimina compara as CAIXAS:**

```ts
const alvo = await dialogo.getByTestId('campo').boundingBox()
const rodape = await dialogo.getByRole('button', { name: 'Confirmar' }).boundingBox()
expect(alvo!.y + alvo!.height, 'a base do campo fica acima do topo do rodapé')
  .toBeLessThanOrEqual(rodape!.y)
```

Ela deu `628.125 <= 627` → falhou por **1,1px**, que é o defeito real medido.

🔑 **E o primeiro conserto PIOROU — só a medição mostrou.** `scrollIntoView({ block: 'nearest' })`
alinha o **topo** do bloco e empurra o resto para dentro do rodapé: a sobreposição foi de **1px
para 18px**. `block: 'center'` resolveu. O número saiu da medição, não do raciocínio — e sem a
asserção por caixa eu teria "consertado" às cegas e piorado com a suíte verde.

**Como aplicar:**
- Em diálogo com rodapé `sticky` (ou header fixo, ou barra de ação flutuante), **toda** asserção de
  "o usuário vê X" precisa comparar caixas. `toBeVisible` só garante caixa não-vazia; `toBeInViewport`
  só garante interseção com a janela.
- O alvo da comparação é o elemento que **ocluí**, não a viewport. Ancore no botão do rodapé, que é
  estável e tem papel acessível.
- Quando o texto for **requisito** da tela (um aviso legal, uma consequência que a pessoa precisa
  ler antes de confirmar), a asserção por caixa não é zelo: sem ela, "visível" é falso na única
  acepção que importa.
- Vale para acordeão pelo mesmo motivo, por outro caminho: `innerText` é cego em acordeão fechado,
  e `toBeVisible` reprova ali (caixa vazia) — mas não reprova o que está **atrás** de outra coisa.

⚠️ **A foto é o oráculo de classe diferente, e foi ela que abriu o caso** — ver
[[o-screenshot-pega-o-que-a-guarda-nao-ve]]. A diferença que este verbete acrescenta é o passo
seguinte: depois que a foto acusa, a guarda que **impede a volta** não é a que você escreveria por
reflexo. Parente de [[guarda-verde-porque-nao-mede-nada]] — aqui a guarda mede, mede a coisa quase
certa, e a diferença entre "quase" e "certa" é o defeito inteiro.
