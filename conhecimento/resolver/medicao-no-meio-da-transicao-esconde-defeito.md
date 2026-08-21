## Medir cor no meio da transição faz a GUARDA passar verde com o defeito de pé {#medicao-no-meio-da-transicao-esconde-defeito}

`tags: getComputedStyle, transition, transition-colors, contraste, WCAG, guarda visual, Playwright, tema escuro, dark mode, verde falso, valor interpolado, data-tema, medição`

**Contexto:** guarda automatizada que troca o tema por atributo e **mede** o par de cores (texto × fundo) para reprovar contraste abaixo de 4,5:1 — a versão em número da evidência por screenshot.

**Sintoma:** a guarda passa. A foto da mesma tela, tirada no mesmo teste, mostra o botão **branco sobre branco**. Dois instrumentos sobre o mesmo pixel, discordando.

**Causa raiz:** `getComputedStyle` durante uma transição devolve o **valor interpolado**, não o de destino. Medindo no instante do `setAttribute('data-tema', 'escuro')`, o fundo lido ainda é o do tema anterior — quase-preto — e o texto branco passa com folga. A asserção do atributo não protege: `toHaveAttribute('data-tema','escuro')` é verdadeira no primeiro frame, antes de qualquer pixel mudar.

**É o espelho do screenshot prematuro, e o espelho é pior.** A foto tirada cedo **inventa** um defeito que não existe ([[screenshot-no-meio-da-transicao-inventa-defeito]]) — alguém persegue e não acha. A medição feita cedo **esconde** um defeito que existe: ninguém persegue nada, e a guarda vira carimbo. Custo de descobrir: a guarda foi escrita para pegar um defeito conhecido, e passou verde com ele de pé.

**Fix:** a mesma espera do screenshot, no mesmo helper compartilhado — trocar tema e medir são a mesma operação sujeita ao mesmo tempo de interpolação.

```ts
await trocarTema(page, tema)          // setAttribute + assert + waitForTimeout(500)
const razao = await contrasteDoBotao(page, 'Aceitar')
expect(razao).toBeGreaterThanOrEqual(4.5)
```

**Como saber se a sua guarda tem o defeito, em uma rodada:** desfaça o conserto que ela deveria cobrar e rode. Se continuar verde, ela está medindo o instante errado — não o produto. Medido assim: **1,10:1** com a espera contra **passa** sem ela, no mesmo commit.

**Regra geral:** guarda que nunca foi vista **vermelha** não prova nada, e para guarda de cor isso tem um passo a mais — ela precisa ser vista vermelha **depois** da espera. Sem a espera, o vermelho que você viu pode ter sido sorte de timing.

**Ref:** Empresa Milionária, 2026-08-20 — `--accentTexto` fixo em `#ffffff` contra um `--accent` que é `var(--t1)`: no tema claro o par funciona, no escuro `--t1` é quase branco.
