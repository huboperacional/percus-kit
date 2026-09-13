## `grep` sensível a caixa inventa defeito em atributo HTML — o framework emite `hrefLang`, você procurou `hreflang` {#grep-sensivel-a-caixa-inventa-defeito-em-atributo-html}

`tags: grep, case sensitive, falso negativo, medicao, html, atributo, hreflang, seo, next.js, react, auditoria, R23`

**Sintoma.** Você audita um site em produção com `curl | grep`, procura um atributo que
deveria estar lá, recebe **zero em todas as rotas**, e conclui que o projeto inteiro tem
um defeito grave — "nenhuma página emite `hreflang`", "nenhuma declara `charset`". Escreve
o achado como crítico, às vezes já começa o conserto. Aí abre o HTML e o atributo **está
lá**, em todas.

**Causa raiz.** Nome de atributo em HTML é **case-insensitive**, mas `grep` não é. React e
os frameworks em cima dele emitem vários atributos na grafia camelCase do JSX, que é como
a propriedade se chama no DOM — e não na grafia minúscula que a especificação do HTML usa
nos exemplos. Next.js emite `<link rel="alternate" hrefLang="en" …>`, não `hreflang=`. O
navegador e o crawler leem os dois igual; o seu `grep` só lê um.

A mesma armadilha pega `charSet` (React emite `charSet`, não `charset`), `viewBox` em SVG,
`tabIndex`, `srcSet`, `crossOrigin`, `autoComplete`.

**O que torna caro:** o falso negativo não parece falso. Vem em **todas** as rotas, com
zero variação, e uniformidade é justamente o que faz um achado parecer sistêmico e
verdadeiro. Um defeito real quase nunca é perfeitamente uniforme.

**Correção.**

```sh
curl -s "$URL" | grep -oi 'rel="alternate" hreflang="[^"]*"'   # -i, sempre
```

Use `-i` em **toda** medição de HTML por texto. E antes de escrever "nenhuma rota tem X",
faça a checagem inversa que custa dez segundos: pegue **uma** rota e olhe o HTML bruto
(`curl -s "$URL" | grep -o '<head.*</head>'`, ou só abra). Se o atributo está lá, o
defeito é do seu padrão, não do código.

**Sinal de alerta antes de gastar a noite:** achado que vale para 100% das rotas, sem uma
única exceção, num código que outras pessoas já revisaram. Conte as exceções: um defeito
real costuma ter algumas. Uniformidade perfeita é assinatura de erro de instrumento.

**Armadilha de método.** É tentador partir direto do "zero" para o plano de conserto —
o achado é grande, a correção parece óbvia, e medir de novo parece perda de tempo. É o
contrário: quanto **maior** o achado, mais barato sai reconferir antes, porque o custo do
falso positivo cresce junto com ele.

**Família:** mesma raiz de [numerar seção nova buscando `§00x` não acha a
colisão](buscar-a-ancora-com-o-sigilo-nao-acha-o-cabecalho-sem-sigilo.md) — lá o `grep`
varre o conjunto errado, aqui escreve o padrão errado. Nos dois casos a medição parece
rigorosa e responde uma pergunta que não é a sua.

**Ref:** LiliFlow, auditoria de SEO das 48 URLs do sitemap (2026-09-13). Cheguei a
escrever num documento de decisão que "nenhuma rota do site emite `hreflang`" e a chamar
isso de defeito maior que o problema real. Os ~20 pares PT/EN estavam corretos o tempo
todo. Refeita a medição com `-i`, sobrou **um** defeito verdadeiro e isolado: as 9 rotas
de `/templates` sem `canonical`.
