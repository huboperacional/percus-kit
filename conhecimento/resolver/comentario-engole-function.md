## Comentário `//` na mesma linha de `function nome(){` engole a declaração inteira — nada no app funciona, e o erro aponta pra linha errada {#comentario-engole-function}

`tags: JavaScript, comentario de linha, single-line comment, SyntaxError, Illegal return statement, Unexpected token, script inteiro falha, HTML single-file app, node --check`

**Contexto:** copiando/adaptando um app HTML+JS single-file de terceiros (sem build step, tudo num
`<script>` inline) pra produção — cenário comum quando se prioriza velocidade e se copia um repo
pronto em vez de reescrever do zero.

**Sintoma:** o app carrega normalmente (HTTP 200, título certo, HTML/CSS renderizam), mas **nenhuma
interação funciona** — nenhum botão responde, nenhum listener dispara, mesmo os completamente
alheios ao trecho quebrado. O usuário relata um sintoma específico ("não consigo adicionar X"), mas
na verdade é o app INTEIRO que está morto. Console mostra um erro de sintaxe (`Illegal return
statement`, ou dependendo do parser, `Unexpected token '}'`) numa linha que não tem relação óbvia
com a feature reportada como quebrada.

**Causa raiz:** em algum lugar do arquivo, uma linha tem `// comentário` seguido, na MESMA linha, de
código real — ex.: `let x={}; // nota function minhaFuncao(){`. O comentário de linha única comenta
tudo até o fim da linha, **incluindo a declaração da função que vinha logo depois**. O corpo da
função (as linhas seguintes, que o autor pretendia que ficassem dentro dela) vira código solto fora
de qualquer função: qualquer `return` ali dispara `Illegal return statement`, e a chave `}` de
fechamento no fim da função vira `Unexpected token '}'` sem abertura correspondente. Como isso quebra
o **parse** do arquivo JS inteiro (não é um erro de runtime isolado numa função), o script inteiro
falha ao carregar e **nada depois dele roda** — inclusive `addEventListener`/`.onclick=` de features
completamente não relacionadas ao trecho quebrado.

**Solução:**
1. Antes de assumir "só tem um bug pequeno na feature X", valide a sintaxe do `<script>` isolado:
   ```bash
   awk '/<script>/{flag=1;next}/<\/script>/{flag=0}flag' index.html > /tmp/script.js
   node --check /tmp/script.js
   ```
   Um `SyntaxError` aqui explica sintomas "o app inteiro está morto" muito mais rápido que debugar a
   feature relatada isoladamente.
2. Localize o padrão com `grep -n '//[^\n]*function'` (comentário de linha seguido de `function` na
   mesma linha) — é o caso mais comum, mas qualquer código real após `//` na mesma linha serve.
3. Mova o código real pra linha própria, deixando o comentário sozinho:
   ```diff
   - let x={}; // nota function minhaFuncao(){
   + let x={}; // nota
   + function minhaFuncao(){
   ```
4. Re-rode `node --check` pra confirmar antes de commitar/deployar.

**Relacionado:** [Guarda que o entrypoint real nunca alcança](guarda-morta-entrypoint.md) — mesma
família "o gate/código parece existir mas nunca roda", causa raiz diferente (aqui é parse-time, não
um guard mal-cabeado). [Ferramenta de monitoramento roda INERTE com os testes verdes](source-clobra-entry-point.md)
— mesmo padrão de "sintoma isolado esconde falha total", root cause diferente.

**Ref:** Caxeta (marcador de partidas de cacheta), sessão 2026-08-07 — bug herdado do repo original
copiado (`ricardolaquino/Marcador-de-Caxeta-`), linha `let settleShares={}; // id -> reais string
function openSettle(){`. Usuário reportou "não consigo adicionar jogador"; reproduzido ao vivo via
Playwright (`browser_console_messages` mostrava `Illegal return statement`); causa raiz confirmada
com `node --check` no `<script>` extraído (apontou `Unexpected token '}'` na chave de fechamento
órfã, ~150 linhas depois do defeito real). Corrigido movendo `function openSettle(){` pra linha
própria — commit `3973e1a`.
