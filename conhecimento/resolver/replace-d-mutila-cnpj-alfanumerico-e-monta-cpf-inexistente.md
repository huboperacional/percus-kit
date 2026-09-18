## `replace(/\D/g, '')` mutila o CNPJ alfanumérico e o formatador monta um CPF que não existe {#replace-d-mutila-cnpj-alfanumerico-e-monta-cpf-inexistente}

`tags: cnpj, cnpj alfanumérico, cpf, máscara, documento, formatação, regex, frontend, dado falso na tela, R23`

**Sintoma:** um formatador de documento brasileiro "limpa" a entrada com `replace(/\D/g, '')` e escolhe a máscara pelo
comprimento (11 → CPF, 14 → CNPJ). Com o CNPJ alfanumérico (válido desde 2026), a tela mostra **um CPF que não existe**,
sem erro nenhum. Medido em 18/09/2026 (Empresa Milionária, Task 20 da leitura de NFS-e), na função real transpilada:
`"12ABC678000195"` → `"126.780.001-95"`. As três letras somem, sobram 11 caracteres, e a máscara de CPF se aplica.

**Causa:** `\D` foi escrito quando documento era só número. O CNPJ alfanumérico tem letras nas 12 primeiras posições
(os 2 dígitos verificadores continuam numéricos), e a limpeza que era inofensiva passa a trocar de tipo o documento.

**Por que passa despercebido:** o cadastro costuma gravar só dígitos, então os chamadores que mostram documento de
PESSOA seguem certos, e os testes com número puro ficam verdes. O defeito só aparece por documento que NÃO vem do
cadastro — ali, a identidade de uma nota fiscal (`documento_prestador` aceita `[0-9A-Z]{14}`), que já estava no ar
numa tela de proposta antes de ser notado.

**Solução:** limpe preservando letra e dígito (`toUpperCase().replace(/[^0-9A-Z]/g, '')`); CPF só com **11 dígitos**
(`/^\d{11}$/`); 14 letras-ou-dígitos recebem a máscara de CNPJ com as letras (`"12.ABC.678/0001-95"`). Antes de mexer
numa função compartilhada: liste os chamadores, teste a **regressão numérica** (CPF e CNPJ, com e sem máscara, saindo
idênticos) e o caso que discrimina (a versão com `\D` produz exatamente o CPF inventado — afirme que ele é impossível),
e sabote voltando ao `\D`. Meça também de onde o documento vem: o alcance real é "tudo o que não passa pelo cadastro".

**Verbetes relacionados:** `validate-docbr-2-ja-confere-cnpj-alfanumerico.md`,
`mascara-de-documento-por-comprimento-nao-alcanca-o-numero-formatado.md`.
