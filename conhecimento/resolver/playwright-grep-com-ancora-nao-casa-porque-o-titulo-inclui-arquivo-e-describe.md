## `playwright test -g "^5 "` não casa nada: o título que o `--grep` vê inclui arquivo e `describe` {#playwright-grep-com-ancora-nao-casa-porque-o-titulo-inclui-arquivo-e-describe}

`tags: playwright, grep, -g, titulo, describe, sabotagem, no tests found, filtro, regex, ancora`

**Sintoma:** para rodar só um teste numa rodada de sabotagem, usa-se `-g "^5 "` (o teste se chama `5 · retorno sem a empresa…`).
O comando termina com `Error: No tests found` e código de saída diferente de zero. Num script que só olha "falhou/passou", isso
parece a sabotagem pegando, e não é: nada rodou. Medido em 2026-09-16 (Empresa Milionária, Task 17 da guarda).

**Causa raiz:** o `--grep` casa contra o título COMPLETO, que junta o caminho do arquivo, os `describe` e o nome do teste
(`pj-google-drive.spec.ts 5 · retorno…`). A âncora `^` aponta para o começo do arquivo, não do nome.

**Solução:**

1. Filtre por um trecho único do nome, sem âncora: `-g "5 · retorno sem a empresa"`.
2. Antes da rodada que importa, rode o mesmo filtro com `--list` e confira `Total: 1 test` (na mesma chamada, para não mudar o
   filtro entre a conferência e a rodada).
3. Numa rodada de sabotagem, trate `No tests found` como **não medido**, nunca como vermelho. Prima de
   [[sabotagem-que-nao-aplica-reporta-verde]].
