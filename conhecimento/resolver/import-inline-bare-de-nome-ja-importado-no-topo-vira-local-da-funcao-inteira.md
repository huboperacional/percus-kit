## Um `from X import nome` sem alias, no MEIO de uma função, torna `nome` local da função INTEIRA {#import-inline-bare-de-nome-ja-importado-no-topo-vira-local-da-funcao-inteira}

`tags: python, escopo, UnboundLocalError, import inline, shadowing, service.py, funcao longa, alias`

**Contexto:** função de centenas/milhares de linhas com vários `if`/`elif` de intenção — comum em
handlers de webhook/dispatcher que cresceram por acréscimo (ex.: `_dispatchInboundText`, 836 linhas).
O módulo importa `date` no topo do arquivo (`from datetime import date`). Uma branch da função, bem
mais abaixo do ponto onde você está editando, faz `from datetime import date` de novo — **sem
alias** — porque parecia local e inofensivo.

**O sintoma:** `UnboundLocalError: cannot access local variable 'date' where it is not associated
with a value`, disparado numa linha que só LÊ `date.today()`, **antes** de qualquer `import` visível
naquele ponto do código. Não há `nonlocal`/`global` na função, e o `date` do topo do arquivo existe e
funciona em toda função VIZINHA.

**A causa:** Python decide se um nome é local ou de escopo externo analisando a função **inteira** em
tempo de compilação — não linha a linha em tempo de execução. Uma única atribuição a `date` em
QUALQUER lugar da função (inclusive um `import` inline, que é sintaticamente uma atribuição) faz
**todas as ocorrências de `date` naquela função** — mesmo antes da linha do import — serem tratadas
como a variável local, nunca o `date` de módulo. Sem a declaração local ainda ter rodado, a leitura
falha.

**Por que passa despercebido até doer:** o `import` inline culpado pode estar centenas de linhas
abaixo, numa branch de intenção que você nunca leu enquanto editava a sua. `git blame`/revisão do
diff não mostra o import culpado porque ele já existia antes da sua mudança — só a SUA leitura de
`date` é nova, e é ela que quebra.

**Correção:** nunca reintroduza um import inline com o MESMO nome que já existe no topo do arquivo.
Se precisar de um import local dentro de uma função grande (padrão comum para quebrar import
circular ou adiar custo), **sempre com alias** — `from datetime import date as _date` — mesmo que
pareça redundante naquele ponto específico. Antes de usar um nome de módulo bare dentro de uma
função grande, `grep` a função inteira por `from .* import {nome}` sem alias.

**Como achar todos os já existentes:** `grep -n "from datetime import date$"` (ou equivalente pro
nome em questão) dentro do arquivo — qualquer ocorrência SEM `as` é suspeita se o mesmo nome também
é importado no topo do módulo.
