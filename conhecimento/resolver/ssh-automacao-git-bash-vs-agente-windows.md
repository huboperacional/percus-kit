## "SSH quebrou" depois de rotacionar chaves no Windows — mas a chave está OK, é o `ssh` errado {#ssh-automacao-git-bash-vs-agente-windows}

tags: ssh, rotacao de chaves, permission denied, publickey, ssh-agent, windows, git bash, msys2, named pipe, batchmode, automacao, deploy, ssh_runner, passphrase, subprocess

**Contexto:** rotação de chaves SSH (novas com passphrase, antigas revogadas). A automação (`ssh_runner`, deploy scripts) passa a dar `Permission denied (publickey)` mesmo depois de subir o `ssh-agent` e carregar a chave. O `ssh` cru pelo PowerShell conecta; o MESMO script pelo Git Bash falha — sintoma idêntico ao de chave não-autorizada, o que joga o diagnóstico pra "a rotação quebrou a chave".

**Causa raiz:** duas coisas distintas confundidas numa só. (1) A chave precisa do **ssh-agent do Windows como serviço** com a chave carregada (`ssh-add -l`), senão `BatchMode=yes` não tem como provar posse da privada com passphrase. (2) Mesmo com o agente OK, automação lançada pelo **Git Bash** resolve `ssh` pro **MSYS2 `/usr/bin/ssh`** (vem antes no PATH — cheque `which -a ssh`), que **NÃO fala com o agente do Windows** (o agente expõe um named pipe; o MSYS2 espera um socket unix) → cai só na chave em disco, que tem passphrase, e com BatchMode falha silenciosamente.

**Solução:** (a) agente do OpenSSH do Windows como serviço + `ssh-add` uma vez (persiste entre reboots, chave segue cifrada em disco); (b) no código de automação **pine o binário**: no Windows use `C:\Windows\System32\OpenSSH\ssh.exe` (agente-aware) em vez de `ssh` puro, independente do shell que lançou — `subprocess` resolve pelo PATH herdado, que muda entre Git Bash e PowerShell. Verifique do **shell em que a automação REALMENTE roda**, não do PowerShell interativo. Bônus: `subprocess` não expande `~` — passe `os.path.expanduser` no caminho da chave (o default do `os.getenv` já vem expandido, o valor do env NÃO).

**Ref:** Família Milionária 2026-07-24; `execution/ssh_runner.py` (`_sshBin()`), `deploy_v2.py`, `deploy_frontend_v2.py`; memória `project_snapshot_2026_07_23_ssh_rotacao_quebrou_automacao`.
