## `$?` dentro de string PowerShell com aspas duplas interpola o PRÓPRIO `$?` do PowerShell, não sobra `$?` literal pro bash remoto {#powershell-dollar-question-interpola-antes-de-chegar-no-bash-remoto}

tags: PowerShell, aspas duplas, interpolação, $?, exit code, SSH, vps_exec, bash remoto, string quoting, paramiko, RC, build, docker build, falso sucesso, falso positivo

**Sintoma:** um comando remoto construído para capturar o exit code do bash (`echo
BUILD_DONE_RC=\$? >> log`) e disparado via `pwsh -Command "... vps_exec.py \"...\$?...\""`
grava no log remoto `BUILD_DONE_RC=True` — nunca um número. `True`/`False` é sintaxe de
booleano do **PowerShell**, não do bash: o marcador de sucesso do build virou lixo antes de
sair da máquina local.

**Causa:** PowerShell usa aspas duplas para strings **interpoladas** (ao contrário de single
quotes, que são literais). `$?` dentro de uma string `"..."` não é passado como texto — o
PowerShell resolve **o próprio `$?`** (booleano de sucesso do ÚLTIMO comando PowerShell,
completamente sem relação com o exit code do bash remoto que o comando pretendia capturar) e
substitui pelo `True`/`False` resultante ANTES de o texto virar argumento do processo seguinte
(aqui, `python vps_exec.py`). Prefixar com `\` (`\$?`) não protege — PowerShell não usa
backslash como caractere de escape; `\$?` dentro de aspas duplas ainda deixa o `$?` sujeito à
interpolação.

**Como reconhecer:** o valor gravado é `True`/`False` (PascalCase, sem aspas) em vez de um
inteiro pequeno (`0`, `1`, `2`…). Isso por si só já denuncia que quem escreveu o valor foi o
PowerShell, não o bash — exit codes reais nunca são booleanos.

**Verificação que não depende do RC corrompido:** não confie no marcador quebrado nem tente
"consertar" a leitura dele. Confirme o resultado real por uma via independente — `docker images
<tag>` mostrando que a imagem foi criada, ou o próprio conteúdo do log de build terminando em
`exporting to image` / `naming to ... done` sem bloco de erro no meio.

**Fix — use aspas simples no nível PowerShell** para o comando remoto inteiro (single-quoted
strings do PowerShell são 100% literais, sem interpolação de `$`, backtick nem nada):

```powershell
# ERRADO — "$?" some, vira True/False do PowerShell:
python vps_exec.py "bash -c 'docker build ...; echo RC=\$? >> log'"

# CERTO — string externa em aspas simples: nada é interpolado, "$?" chega intacto no bash remoto:
python vps_exec.py 'bash -c "docker build ...; echo RC=$? >> log"'
```

Se o comando remoto for grande ou tiver aspas aninhadas dos dois lados (bash `"..."` dentro de
PowerShell), é mais seguro escrever o script inteiro num arquivo local e fazer upload (`vps_put.py`)
em vez de tentar equilibrar camadas de aspas numa linha só — ver também
[[guarda-de-path-protegido-tokeniza-por-espaco-e-corta-o-alvo]], que documenta um bloqueio
diferente (mas do mesmo gênero: comando composto demais numa linha só) nesta mesma classe de
ferramenta.

**Ref:** Paid Media Automation, 2026-08-31 — deploy de `paid-media-web` via bundle→worktree→build
na VPS. `scripts/vps_exec.py`.
