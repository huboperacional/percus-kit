## Edição por índice em arquivo grande cruza fronteira de função e apaga centenas de linhas {#edicao-por-indice-cruza-fronteira-de-funcao}

`tags: edicao de codigo, s.index, ancora, primeira ocorrencia, arquivo grande, service.py, refactor, dry-run, git checkout, perda de codigo, migracao de sitio`

**Contexto:** substituir um bloco de código dentro de uma função específica de um arquivo grande
(8 mil linhas), localizando início e fim por `s.index("...")` e fazendo `s[:ini] + novo + s[fim:]`.

**O que aconteceu:** o texto do *fim* (`"    if len(matches) > 1:"`) ocorria **antes** do texto do
*início*, numa outra função sem relação nenhuma. `s.index()` devolve a **primeira** ocorrência, então
o par (ini, fim) ficou invertido e o splice apagou **280 linhas** — incluindo a definição da função
que eu estava editando. O arquivo continuou **compilando** (`py_compile` passou), e o sintoma só
apareceu como `AttributeError: module has no attribute '_handleSmartCorrection'` num teste.

**Por que é traiçoeiro:** `py_compile` não vê nada errado num arquivo que perdeu funções inteiras, e
o diff só denuncia se você olhar o `--numstat`. Um "+41 −280" num commit de migração de um sítio
passa por refactor agressivo se ninguém conferir.

**Como resolver:**

1. **Escopar toda busca à função alvo.** Ache primeiro `async def <alvo>(` e passe esse índice como
   `desde` em todas as buscas seguintes.
2. **Assertar a ordem antes de escrever:** `assert fn < a0 < a1 < b0 < b1`. É uma linha e teria
   barrado o estrago (o assert real disparou: `(3790, 3795, 3217, 3231)`).
3. **Dry-run que IMPRIME o bloco** a ser substituído, num arquivo `utf-8` (o console Windows é cp1252
   e emoji no código-fonte estoura o print). Só aplicar depois de ler o que vai sair.
4. **Substituir de trás pra frente** quando há mais de um bloco: mexer no primeiro desloca os índices
   do segundo.
5. **Conferir `git diff --numstat` depois.** Insersões e deleções fora de proporção com o que você
   pretendia é o sinal mais barato que existe.

**Recuperação:** `git checkout -- <arquivo>` restaura na hora se o trabalho anterior já estava
commitado — mais um motivo pra commitar cada task fechada antes de começar a próxima.

**Relacionado, e ainda NÃO escrito:** a mesma família aparece com `str.replace` **sem contagem** —
âncora frouxa que casa em sítios irmãos e corrompe todos de uma vez. Fica aqui como prosa, e não
como link, porque o verbete não existe: link morto nasce calado, e o gate do canon o barra (foi o
que aconteceu em 21/08, quando este arquivo foi versionado).
