## Geometria medida durante a animação de entrada não descreve layout nenhum {#geometria-medida-durante-animacao-nao-descreve-layout}

`tags: e2e, playwright, animacao, css, transform, flake, boundingBox, geometria, dialogo, modal, tailwindcss-animate, radix, corrida, guarda, medicao`

**Contexto:** teste E2E que abre um diálogo/menu/tooltip e mede posição — `boundingBox()`,
`getBoundingClientRect()`, "cabe na viewport?", "o botão está visível?". `toBeVisible()` resolve
assim que o elemento entra no DOM com tamanho, e isso acontece no **primeiro quadro** da animação
de entrada. A medição sai no meio do caminho.

**O sintoma que confunde:** o número medido é incompatível com QUALQUER layout em repouso. Você
mede o CSS, confere que o `max-height` está certo, confere que nenhum ancestral tem `transform`,
e nada explica o valor. Some e volta sem padrão — costuma dar 0 em 10 repetições isoladas e
reaparecer quando a máquina está ocupada. É corrida, não layout.

**Caso medido (Empresa Milionária, 2026-08-20 → 2026-08-29):** um diálogo de pagamento acusou
`658 > 640` (rodapé de ações fora da viewport). Em repouso ele mede 608, centrado, de 16 a 624 —
cabe com 57px de folga. A falha ficou 9 dias sem explicação e duas hipóteses estruturais foram
levantadas e refutadas corretamente (o `max-h` valia mesmo; o contêiner do portal não tinha
`transform`). O que faltava era instrumentar a medida.

Quando a geometria foi despejada junto da asserção, o `transform` entregou tudo:

```
matrix3d(0.992602, 0,0,0, 0,0.992602, 0,0, 0,0,0.992602,0, -238.572, -259.021, 0, 1)
```

**A aritmética fecha e não deixa dúvida.** O `zoom-in-95` interpola a escala de `.95` a `1`:

```
0,95 + 0,05p = 0,992602   ->   p = 0,85204
```

O keyframe do `tailwindcss-animate` anima a propriedade `transform` **inteira**, e a
centralização (`-translate-x-1/2 -translate-y-1/2`) vive nela. Então, no mesmo `p`, a
centralização também valia só 85%:

```
0,85204 x -280 = -238,57   (largura 560)
0,85204 x -304 = -259,02   (altura  608)
```

Exatamente os componentes de translação medidos. O diálogo não estava grande demais: estava
**45px mais baixo** do que ficaria parado, porque ainda não terminou de subir para o centro.

**Conserto — espere o FATO, não o relógio:**

```ts
await dialogo.evaluate((el) =>
  Promise.all(el.getAnimations({ subtree: true }).map((a) => a.finished)),
)
```

`{ subtree: true }` importa: overlay e conteúdo animam separados, e esperar só o nó raiz deixa
metade da corrida de pé. `waitForTimeout(300)` "resolve" na sua máquina e volta a flakar na
primeira mais lenta — e pior, esconde regressão de performance.

**Duas consequências que valem mais que o conserto:**

1. **Ponha a geometria DENTRO da mensagem de falha**, não só o número que estourou. Foi o
   `transform` no texto do erro que fechou o caso; sem ele, o defeito sobreviveu a duas
   investigações competentes. Medida sem contexto vira palpite.
2. **Desconfie do diagnóstico herdado.** O achado circulou 9 dias como "o conserto é no
   componente (`max-h` + `overflow`)" — e o `max-h` já estava lá e já funcionava, o que a
   própria medida dizia (`maxHeight: 608px`). O defeito era da guarda. Reproduza antes de
   consertar o que outro mediu.

**Armadilha irmã, achada no mesmo dia:** depois de consertar a espera, sabotar o componente não
reprovava o teste. O alvo da asserção era o botão de confirmar — que é irmão `flex` fixado no fim
da caixa do diálogo, ou seja, **protegido por construção**: ele acompanha a caixa, e a caixa é
limitada pelo `max-h`. A guarda só passou a morder quando a asserção mudou para a **caixa do
diálogo** (com `max-h` fora e conteúdo alto, ela mediu `-110` a `750` numa viewport de 640 —
transbordando pelos dois lados). Asserte no elemento que a regra REALMENTE governa; ver
[a sabotagem prova o que você imaginou](a-sabotagem-prova-o-que-voce-imaginou.md).
