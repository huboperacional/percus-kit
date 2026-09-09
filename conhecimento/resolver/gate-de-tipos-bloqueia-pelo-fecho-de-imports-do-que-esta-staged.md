## Gate de tipos bloqueia pelo fecho de imports do que está staged, não pelo que você mudou {#gate-de-tipos-bloqueia-pelo-fecho-de-imports-do-que-esta-staged}

`tags: pre-commit, git hook, PreToolUse, mypy, tsc, types-check, staged, fecho transitivo, imports, divida herdada, arvore compartilhada, teto de exibicao, gate intransponivel`

**Sintoma:** o gate de tipos reprova o seu commit listando erros em **arquivos que você não
tocou** — e que `git status` mostra limpos. A lista parece curta (10 erros), o que sugere "conserto
rápido". Você tenta corrigir os 10 e descobre que não acabam.

**Causa raiz — duas coisas se somam:**

1. O hook coleta os arquivos por `git diff --cached` (o **índice**) e roda `mypy --strict` neles.
   Mas `mypy` **segue os imports**: o alvo real é o **fecho transitivo** do que está indexado, não
   o que mudou. Basta um arquivo de entrada larga no índice — um `main.py` que importa a aplicação
   inteira — para o gate passar a medir o projeto todo, inclusive dívida herdada de anos.
2. A saída é **truncada** (`Select-Object -First N` / `head -N`). O número exibido é **teto de
   exibição**, não contagem. No caso medido: o hook mostrava **10**; o real, medido à mão, era
   **1367** — nenhum deles em arquivo que a sessão tivesse tocado, e dois deles sem alteração desde
   a derivação do fork, um mês antes.

**Por que é intransponível por esforço:** não há caminho que evite os dois lados. `git commit --
<pathspec>` **não alcança arquivo untracked** (`did not match any file(s) known to git`), então
arquivo novo obriga a passar pelo índice; e passar pelo índice expõe ao fecho transitivo. E o hook
sendo `PreToolUse`, `git reset && git commit` na MESMA chamada não ajuda: o bloqueio mata a chamada
inteira antes de o `reset` rodar.

**Como medir antes de decidir** — o passo que separa "conserto de 10 minutos" de "escopo de dias":

```
mypy --version                      # controle positivo: sem ele, "0 erros" pode ser o comando falhando
mypy --strict --no-error-summary <seus arquivos>   | grep -c ': error:'
mypy --strict --no-error-summary <o main/entrypoint> | grep -c ': error:'
```

A diferença entre os dois números **é** o fecho transitivo. Depois separe por arquivo
(`awk -F: '{print $1}' | sort | uniq -c`) para ver quantos erros são realmente seus — no caso
medido eram **5 de 38**, e 3 desses eram `dict` sem parâmetro de tipo, corrigidos em minutos.

**Como resolver:**

- **Corrija os seus** (a separação por arquivo diz quais são), e **declare os herdados** — não os
  conserte de carona: dívida alheia consertada sob pressão de gate vira commit de 24 arquivos.
- **O escape do hook mora no ambiente do harness.** Setar `$env:VAR` DENTRO do comando não alcança
  um hook `PreToolUse` — ele já rodou. Em Claude Code, o caminho que funciona é `env` no
  `settings.json` (projeto ou local); em CI, a variável do runner.
- **Se desligar o gate, escreva o motivo NO arquivo de config** — medição, data, quem decidiu, como
  reverter, e o que isso **não** dispensa (rodar o checador nos arquivos próprios). Gate desligado
  sem motivo escrito é a armadilha seguinte.

⚠️ **Em árvore compartilhada o bloqueio é contagioso:** o gate lê o índice INTEIRO, então arquivos
que **outra sessão** deixou staged reprovam o SEU commit, sem dizer que a reprovação é de terceiro.
Antes de caçar o defeito, rode `git diff --cached --name-only` e veja de quem são os arquivos. A
recíproca também vale: deixar os seus staged bloqueia os outros — commite ou desestague.

**Relacionados:** [[gate-le-o-indice-e-o-commit-por-pathspec-nao-passa-por-ele]] é o **oposto
exato** — lá o gate vê de MENOS (índice vazio, análise não roda, verde falso); aqui ele vê de MAIS.
Vale ler os dois juntos: as duas falhas nascem da mesma escolha de coletar por índice.
[[debito-de-linter-medido-de-um-ponto-de-entrada-so-e-piso]] descreve a outra face do "segue
imports": lá o fecho faz o baseline ser **piso**; aqui faz o gate ser **teto** que ninguém alcança.

**Atualização — o hook em si foi corrigido (canon v6.44.4, 2026-09-09):** as duas causas listadas
acima deixaram de exigir workaround. `types-check-pre-commit.ps1` passou a rodar `mypy` com
`--follow-imports=silent` (mypy só type-checa os arquivos passados, para de seguir o fecho
transitivo de import) **e** a filtrar a saída por linha realmente alterada — um novo helper
`Get-PercusChangedLines` (`hooks/_helpers.ps1`) faz `git diff --cached --unified=0`, parseia os
hunks (`@@ -a,b +c,d @@`) num `HashSet[int]` de linhas adicionadas/mudadas por arquivo, e o
parsing de erro do mypy (regex gulosa `'^(.+):(\d+): error:'`, path normalizado `/`→`\`) só bloqueia
o commit se a linha do erro está nesse conjunto. Resultado: erro em arquivo importado mas não
staged nunca aparece; erro em LINHA não tocada do próprio arquivo staged (o "arquivo legado
inteiro") também para de bloquear. As duas limitações residuais (staged vs. working-tree podem
divergir; um erro pode nascer de mudança em OUTRA linha do mesmo arquivo mas ser reportado numa
linha não tocada) ficaram documentadas como comentário no próprio hook, não resolvidas — casos
raros o bastante pra não valer o custo de resolver agora.

**Isso NÃO substitui o "como medir antes de decidir" acima** — em projeto rodando canon anterior a
6.44.4 (ou com o hook local desatualizado) o sintoma original ainda se aplica. Ver
[[plugin-cache-nao-recebe-fix]] pra esse desalinhamento entre cópia de trabalho e o que roda de
fato: aqui havia o agravante de que o `.cmd` do hook redireciona pra `%PERCUS_CANON_DIR%` quando o
arquivo existe lá, então o fix precisou ser aplicado nas DUAS cópias (cache do plugin e canon) pra
valer.
