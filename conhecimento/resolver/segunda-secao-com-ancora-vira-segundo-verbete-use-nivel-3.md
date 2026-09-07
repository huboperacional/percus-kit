## Segunda seção `##` com âncora não é uma subseção — é um SEGUNDO verbete, e o gate acusa {#segunda-secao-com-ancora-vira-segundo-verbete-use-nivel-3}

`tags: gate, percus-gate.sh, conhecimento, ancora, slug, nanc, malha, subsecao, variante, um verbete por arquivo, R11`

**Sintoma:** um verbete cresce com uma seção "Variante"/"Caso relacionado" e o gate acusa
`BLOQUEADO: ... precisa da ancora {#slug} FECHANDO a linha` numa linha que **parece** um
título comum de subseção (`## Variante X: ...`). Tentar "corrigir" adicionando `{#outro-slug}`
troca o erro por um pior: `e UM verbete por arquivo (achei 2 titulos de verbete)`.

**Causa raiz:** desde a 6.38.0 a base é um-arquivo-por-verbete, e o gate impõe isso via awk: só a
linha que casa `^##[ \t]+..*\{#[^}]+\}[ \t]*$` conta como título válido, e incrementa `nanc[f]`
(número de âncoras no arquivo) — que **precisa ser exatamente 1**. Qualquer outra linha `##...`
sem esse formato cai no catch-all (`malha[f]`) e vira "falta âncora". Não existe combinação de
`##` + âncora que passe como SEGUNDA seção do mesmo verbete — âncora sempre significa "isto é UM
verbete completo", nunca "isto é uma subseção".

**Correção:** subseção dentro do MESMO verbete usa nível 3 (`###`), sem âncora. `###` não casa
nem o padrão de título válido nem o catch-all `malha` (ambos exigem literalmente dois `#`
seguidos de espaço/tab) — passa limpo. Confirmado contra a base: `###` já é convenção usada em
várias entradas para subseção/variante.

```diff
- ## Variante MAIS PERIGOSA: o fake que COMPENSA o defeito (tiatendo, 06/09)
+ ### Variante MAIS PERIGOSA: o fake que COMPENSA o defeito (tiatendo, 06/09)
```

**Achado 2026-09-07:** já mordeu duas vezes na base — `fixture-que-mente-faz-a-mutacao-mentir-junto.md`
(bloqueando o gate para QUALQUER commit no repo, porque o gate varre `git ls-files`, o índice
inteiro, não o pathspec do commit) e `review-diz-sem-findings-por-cima-de-chamada-que-falhou.md`
(já committado antes desta regra existir — grandfathered, só voltaria a acusar se alguém tocasse
o arquivo de novo).

**Princípio geral:** ao editar um verbete existente pra acrescentar um caso relacionado, a
pergunta que decide o nível do heading não é "isto merece destaque visual" — é "isto é o MESMO
conceito com uma variante, ou um conceito novo que merece slug próprio e entrada própria no
índice". Se for variante do mesmo, `###`. Se for conceito novo, arquivo novo.
