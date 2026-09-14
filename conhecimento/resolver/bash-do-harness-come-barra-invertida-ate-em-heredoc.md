## A ferramenta Bash do Claude Code no Windows come barra invertida até em heredoc citado e em `node -e '...'` {#bash-do-harness-come-barra-invertida-ate-em-heredoc}

`tags: bash, git bash, harness, claude code, windows, barra invertida, backslash, escape, heredoc, heredoc citado, node -e, node, regex, SyntaxError, Unterminated regexp literal, Write, pdf, pdftoppm, poppler, zlib, inflateSync, extrair texto`

**Quando:** Claude Code no Windows, ferramenta Bash (Git Bash), script inline com `\\` em regex ou
string — `node - <<'EOF'` ou `node -e '...'`.

**Sintoma:** `SyntaxError` num script que está certo no texto. A regex `/[.*+?^${}()|[\]\\]/g`
chegou ao Node como `/[.*+?^${}()|[\]\]/g`, e o Node deu `Unterminated regexp literal`.

**Causa:** o comando da ferramenta perde barras invertidas antes de chegar ao shell. Delimitador de
heredoc entre aspas não protege. `node -e '...'` com aspas simples também não.

**Passos:**

1. Grave o script num arquivo com a ferramenta Write. Ela não reescreve o conteúdo. Use o scratchpad
   da sessão.
2. Rode `node arquivo.cjs`.

**Armadilhas:**

- Nem sempre falha alto. Em regex, a barra perdida costuma dar `SyntaxError`. Em string, o script
  pode rodar e gravar texto errado — ver
  [heredoc-citado-do-bash-come-barra-invertida](heredoc-citado-do-bash-come-barra-invertida.md).
- Conferir o resultado pelo produto, não pelo "ok" do script
  ([escape-atravessa-camadas-noop](escape-atravessa-camadas-noop.md)).

**Caso de uso onde apareceu — texto de PDF sem poppler.** A ferramenta Read não abre PDF sem
`pdftoppm`. Um script Node resolve para PDF com texto em fonte simples: percorre os blocos
`stream ... endstream`, faz `zlib.inflateSync` em cada um e junta os pedaços entre parênteses.
O script tem regex com barra invertida, por isso vai por Write:

```js
// extrair-pdf.cjs — gravar com Write e rodar: node extrair-pdf.cjs arquivo.pdf
const fs = require('fs');
const zlib = require('zlib');

const s = fs.readFileSync(process.argv[2]).toString('latin1');
const blocos = /stream\r?\n([\s\S]*?)\r?\n?endstream/g;
const saida = [];
let m;
while ((m = blocos.exec(s))) {
  let txt;
  try {
    txt = zlib.inflateSync(Buffer.from(m[1], 'latin1')).toString('latin1');
  } catch {
    continue; // stream sem deflate ou binário
  }
  const pedacos = txt.match(/\((?:\\.|[^\\)])*\)/g);
  if (pedacos) saida.push(pedacos.map((p) => p.slice(1, -1)).join(''));
}
console.error(`streams com texto: ${saida.length}`);
console.log(saida.join('\n'));
```

- O texto sai com o escape do PDF (`\(`, `\)`) e sem quebra de linha entre os pedaços de um mesmo
  stream.
- Fonte CID escreve o texto em `<hex>`, não entre parênteses. Nesse caso o script devolve pouco ou
  nada.

**Ref:** LiliCalc, 2026-09-14. O script funcionou num PDF de artigo acadêmico (32 streams de
texto).
