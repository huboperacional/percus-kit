## Texto em ARRAY DE PROPS escapa de grep, de curl e ate de screenshot {#texto-em-array-de-props-escapa-de-tudo}

tags: marca, rebrand, fork, vazamento de identidade, grep nao acha, curl nao acha, screenshot, animacao, wordswap, carousel, props, copy

**Sintoma:** um produto derivado por fork sobe em producao e continua exibindo o nome/copy do produto de ORIGEM numa tela critica — mas toda verificacao passou: `grep` limpo, `curl | grep` no HTML limpo, teste de identidade verde, build verde.

**Contexto medido (2026-08-16):** a tela de **login** e a de **cadastro** de um produto PJ exibiam "Financas da Familia" — o nome do produto de pessoa fisica de onde ele foi forkado. Sobreviveu a uma varredura de identidade que corrigiu 95 pontos em 83 arquivos, a 8 asseroes automatizadas, e a uma correcao de vazamento feita no MESMO DIA em outra pagina.

**Causa raiz:** o texto vivia num **array de props** de um componente de animacao:

```jsx
<WordSwap words={['suas Financas', 'Financas da Familia']} />
```

Isso o torna invisivel para as tres verificacoes usuais, e cada uma falha por um motivo diferente:

| Verificacao | Por que nao pega |
|---|---|
| `grep` por texto visivel | o texto nao esta entre tags, esta num literal de array |
| `curl` + `grep` no HTML | a string e montada em **runtime**, nao vem no HTML servido |
| **screenshot** | o componente ALTERNA: metade do ciclo mostra a palavra certa e passa limpo |

O terceiro e o mais perigoso, porque screenshot costuma ser a verificacao "definitiva" — e aqui ela da **falso negativo dependendo do instante em que o print foi tirado**.

**Solucao:** ao cacar vazamento de marca, varra tambem os arrays de props, nao so o texto entre tags:

```sh
grep -rn "WordSwap\|Typewriter\|Carousel\|words={" src/ | head -40
# e depois LEIA cada array encontrado
```

E trave por teste que varra o array, nao a renderizacao.

**A regra que sai daqui, e ela vale alem de marca:** *screenshot prova o que a tela mostra NAQUELE QUADRO.* Para conteudo animado, rotativo ou condicional a tempo, ou voce espera o ciclo inteiro, ou le a fonte do array. Vale igual para banner rotativo, tooltip com delay, toast, e estado que so aparece em hover.

**Ref:** Empresa Milionaria (fork da Familia Milionaria), 2026-08-16 — `src/app/login/page.tsx:76,649` e `src/app/cadastro/page.tsx:69`.
