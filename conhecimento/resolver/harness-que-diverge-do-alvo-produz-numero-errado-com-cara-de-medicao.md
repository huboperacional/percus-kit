## Harness que diverge do alvo produz número errado com cara de medição {#harness-que-diverge-do-alvo-produz-numero-errado-com-cara-de-medicao}

`tags: css, geometria, playwright, harness, box-sizing, fonte, medição, reprodução, ui`

**Sintoma:** você monta uma página isolada para medir um defeito de layout, linka o CSS **real** do
projeto, mede com precisão de décimo de pixel — e o número está errado. Pior que estimar no olho:
um número medido carrega autoridade que a estimativa não tem.

**Duas divergências que aconteceram na MESMA sessão, e nas duas o harness parecia fiel:**

1. **Faltou o reset do framework.** O app importa Tailwind, cujo preflight aplica
   `box-sizing: border-box` em tudo. O harness não tinha. Resultado: uma célula com
   `flex-basis: 74px` media **92,9px** (74 + padding), e o estouro saiu **25px** em vez dos 15,5
   reais. Só apareceu porque o `width` computado (73,99) **não batia** com o
   `getBoundingClientRect` (92,9) — a contradição foi o que denunciou.
2. **Faltou a fonte.** O harness caiu num `monospace` genérico; produção usa a fonte carregada pelo
   framework, mais larga. O harness previu folga de 7,6px onde havia **déficit de 2px** — e o
   conserto "verificado" foi para produção cortando o valor do dia a dia.

**O que fazer:**
- Linkar o CSS real **não basta**. Reproduza também o **reset global** e a **fonte** — são as duas
  coisas que moram fora do arquivo de componente e mudam largura.
- **Confira duas medidas do mesmo box** (`computedStyle.width` × `getBoundingClientRect().width`).
  Divergirem é a assinatura de `box-sizing` diferente, e é barato de checar.
- Melhor que corrigir o harness: **iterar na tela viva**, injetando CSS candidato na página real e
  medindo ali. Fonte real, dado real, largura real — e nada é gravado.
- Feche sempre contra o **artefato que produção serve** (buscar o CSS pela URL pública), não contra
  a cópia local do arquivo.

🪤 O sinal de alarme é o harness **concordar** com sua expectativa. Nos dois casos o número errado
era plausível e confirmava o que eu já achava; foi a contradição interna, não a implausibilidade,
que expôs a divergência.
