## O `set -e` não dispara dentro de `$( )` — e isso mascara uma degradação que na verdade mata {#set-e-nao-dispara-dentro-de-substituicao-de-comando-e-mascara-degradacao-que-mata}

`tags: bash, set -e, errexit, pipefail, substituicao de comando, command substitution, degradacao, fallback, grep exit 1, helper sourced, falso verde, R11, seguranca por acidente`

**Sintoma:** uma função `.sh` foi escrita para **degradar com honestidade** — se não conseguir
medir, devolve uma frase explicando e segue. Os testes passam, os call sites funcionam. Mas a
guarda que produz a frase degradada **nunca é alcançada**: quem chamar a função de um jeito
ligeiramente diferente vê o script inteiro morrer.

**A causa, medida em 2026-09-13.** A função tinha esta forma:

```bash
saida="$(grep -oE '^##[[:space:]]+R[0-9]+\..*' "$arq" | sed ... | sort ... )"
[[ -n "$saida" ]] || { printf '%s' "$degradado"; return 0; }   # <-- a guarda honesta
```

Com `set -e` e `pipefail` ativos (e eles estavam: `deepseek-review.sh` usa `set -euo pipefail`),
um canon que **existe mas não tem nenhuma linha `## R<N>.`** faz o `grep` devolver 1 → o pipeline
devolve 1 → a **atribuição** devolve 1 → `set -e` mata o script **antes** da linha seguinte. A
guarda é código morto no exato caso para o qual ela foi escrita.

**Por que ninguém percebeu — e esta é a parte que vale o verbete.** Todos os call sites existentes
chamavam assim:

```bash
FAIXA_REGRAS="$(percus_faixa_regras)"     # dentro de $( )
```

E **dentro de substituição de comando o `errexit` não se propaga do jeito esperado**. Medido, mesma
função, mesmo canon, mesmo `set -euo pipefail`:

| Como chamou | Resultado |
|---|---|
| `percus_regras_do_canon "$dir"` (direta) | **exit 1** — o script morre |
| `r="$(percus_regras_do_canon "$dir")"` | **exit 0** — degrada certinho |

Ou seja: **a segurança de hoje é acidente da forma da chamada, não propriedade da função.** O
primeiro call site direto que alguém escrever quebra, e vai parecer defeito do call site novo.

> ⚠️ Não generalize "`$( )` protege". O que se mediu é que o modo de falha **muda** conforme a
> forma da chamada — e é isso que torna o teste enganoso. Uma sonda mínima no mesmo shell
> (`x="$(grep zzz /dev/null | cat)"` dentro de uma função, chamada direta) **mata** o script.
> Bash tem cantos aqui que variam com versão e contexto; a lição é **não depender do canto**.

**Por que engana:** o teste da degradação passa — desde que ele chame como os call sites chamam. O
meu chamava. Só quando o R11 cross-provider apontou o `||` faltando e eu **medi as duas formas** é
que a diferença apareceu. Um teste que copia a forma de chamada de produção prova produção, não
prova a função.

**Como aplicar:**

1. **Toda atribuição que captura pipeline com `grep`/`find` leva `|| true`** (ou a guarda explícita)
   quando o vazio é um resultado legítimo, e não um erro:
   ```bash
   saida="$(grep ... | sed ... || true)"
   [[ -n "$saida" ]] || { printf '%s' "$degradado"; return 0; }
   ```
   `grep` devolver 1 significa *"não achei"*, que muitas vezes é exatamente o caso que você quer
   tratar — não uma falha.
2. **Teste a função em CHAMADA DIRETA sob `set -euo pipefail`**, não só dentro de `$( )`. É uma
   linha de teste e é a única que exercita o caminho fatal:
   ```bash
   bash -c "set -euo pipefail; . '$helper'; minha_funcao '$dir'; echo ' VIVO'"
   ```
   Asserte o `VIVO` **e** o valor exato — `Should -Match '0'` casaria com qualquer saída que
   contivesse um zero, inclusive a mensagem de erro (outro achado do mesmo review).
3. **Desconfie de "degrada bem" que só foi medido de um jeito.** Caminho de erro e resultado
   negativo desembocando no mesmo lugar é a família de
   [[revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida]]; aqui é o inverso e
   igualmente ruim — o caminho degradado existe, está escrito, e é inalcançável.
4. Ao escrever helper **sourced por vários scripts**, lembre que ele herda o `set` de quem
   sourceou. `deepseek-review.sh` usa `set -euo pipefail`, `council-orchestrator.sh` e
   `cross-claude.sh` usam `set -eo pipefail`, `percus-review-auto.sh` usa só `set -u`. O helper tem
   de ser correto no mais estrito de todos.

**Guarda:** `plugin/percus-review/tests/faixa-regras-derivada.tests.ps1`, contexto *"as funcoes .sh
sobrevivem a set -euo pipefail em chamada DIRETA"*.
