## Implementador de subagent-driven NÃO cumpre review duplo de pasta sensível — o hook vê review fresco e deixa passar {#implementador-sdd-nao-cumpre-review-duplo-de-pasta-sensivel}

`tags: R11, review duplo, cross-claude, deepseek, pasta sensivel, percus-review.json, subagent-driven-development, pre-commit hook, garantia vazia`

**Sintoma:** numa execução `superpowers:subagent-driven-development`, cada implementador roda o review
antes do commit e o hook de pré-commit libera todos os commits. Semanas depois (ou no review de uma
task seguinte) alguém nota que a pasta tocada é **sensível** e exigia review **duplo** — e só uma perna
rodou em todos eles.

**Reprodução real** (Paid Media / `Melhoria na VPS`, 2026-09-14): o `.percus-review.json` do
repositório declara `(^|[/\\])watchdogs[/\\].*\.sh$` como padrão sensível; para caminho sensível, sem
trailer `Co-implemented-by: deepseek` e com até 10 arquivos, o `review-router.ps1` decide **`dual`**
(DeepSeek + subagente Cross-Claude). O controlador escreveu no dispatch das tasks 1 a 4 "rode
`deepseek-review.ps1` antes do commit". Os quatro commits passaram. Quem pegou foi o revisor de tarefa
da task 4, lendo o `.percus-review.json` e o código do router.

**Por que o hook não pega:** o `pre-commit-check` confere que existe um review com menos de 5 minutos
na pasta de reviews do repositório — **frescor**, não **roteamento**. Um review DeepSeek fresco satisfaz
o hook mesmo quando o router teria exigido as duas pernas.

**Por que o implementador não tem como cumprir:** a perna Cross-Claude é um **subagente**, e o
contrato do implementador de SDD proíbe disparar subagentes. "Rode o review R11" dentro do dispatch é
uma instrução impossível de cumprir inteira — é uma garantia vazia por construção, não descuido. E o
review de tarefa do SDD não substitui a perna: julga spec e qualidade, não o canon.

**Como aplicar:**
- Antes de despachar, classifique cada task pelo router (`review-router.ps1 -Json` sobre os caminhos
  que ela toca, ou leia o `.percus-review.json`; sem o arquivo valem os padrões do router — auth,
  payment, migrations, credentials, `.env`).
- Task em caminho sensível: o implementador **para antes do commit** com o diff no índice e reporta; o
  controlador dispara a perna Cross-Claude sobre o diff preparado; o implementador corrige e só então
  commita.
- Se já passou: rode a perna Cross-Claude sobre o intervalo inteiro (`--base <commit anterior>`) e trate
  os achados como rodada de correção da última task — não reescreva a história.
