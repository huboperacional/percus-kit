## Pester expande `<algo>` no nome do teste: um `<->` no título mata o bloco inteiro antes de rodar {#pester-placeholder-no-nome-do-teste}

`tags: pester, powershell, teste, Describe, It, ForEach, placeholder, template, CommandNotFoundException, bloco sumiu, falso verde, nome de teste`

**Sintoma:** um `Describe` inteiro falha com `CommandNotFoundException: The term '$-' is not recognized as a name of a cmdlet`, apontando pra `<ScriptBlock>, <No file>:1` — um arquivo que não existe, uma linha que não é sua. Nenhuma asserção do bloco roda. O relatório mostra o bloco como falha única, sem detalhe, e o resto da suíte parece normal.

**Causa raiz:** o Pester 5 trata `<algo>` em nome de `Describe`/`It` como **placeholder de dado** (é o mecanismo que faz `It "<Prov> responde" -ForEach @(...)` virar "deepseek responde"). A expansão troca `<algo>` por `$algo` e avalia. Um título com **`<->`** — escrito pra dizer "ida e volta", como em `paridade .ps1 <-> .sh` — vira `$-`, que é uma variável automática do PowerShell, e a avaliação explode. O bloco morre na **discovery**, antes de qualquer teste.

**Por que é perigoso além do susto:** o modo de falha é "o bloco não roda", não "o teste falha". Num arquivo grande, um `Describe` que some do relatório é fácil de ler como "não tinha nada ali". Se o bloco fosse o único guardando uma classe de defeito, você fica sem guarda **achando** que tem.

**Solução:** não use `<` `>` em nome de teste a não ser como placeholder de verdade. Escreva "ps1 vs sh", "ida e volta", "A para B". Se precisar de seta literal, use `->` sozinho (não dispara) ou o nome por extenso.

**Como reconhecer na hora:** erro de `CommandNotFoundException` com nome de variável estranho (`$-`, `$>`) + origem `<No file>:1` + um `Describe` inteiro sem detalhe = placeholder no título, não bug no seu código.

**Ref:** percus-kit 6.36.4, 2026-08-16 — custou um relatório de "8 falhas" que eram 1 bloco não-executado.
