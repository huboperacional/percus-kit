## Upload de arquivo pra VPS via Bash falha com erro de bash confuso ("C:/Program: No such file", "X: No such file or directory") mesmo pra arquivo pequeno {#vps-upload-msys-path-mangling}

`tags: paramiko exec_command falha, sftp falha, upload VPS, git bash MSYS path translation, argv reescrito, ConnectionResetError SSH, git bundle grande, scp alternativa, ssh exec_command chunk`

**Sintoma:** um script Python (paramiko) que faz upload de arquivo pra VPS via
`client.exec_command(f"cat > {remote_path}")` + `stdin.write(data)` falha com um erro de BASH sem
sentido (`bash: line 1: C:/Program: No such file or directory` ou
`bash: line 1: C:/Users/.../algum-arquivo: No such file or directory`), mesmo passando um
`remote_path` Unix válido tipo `/tmp/foo.txt` e mesmo pra um arquivo de poucos KB. O erro muda de
forma entre tentativas (às vezes aponta pra um caminho totalmente disparatado). Tentar `SFTP` puro
(`paramiko.SFTPClient.put`) no lugar falha diferente: `FileNotFoundError: [Errno 2] No such file`
mesmo com o diretório remoto existindo — sinal de que o subsistema SFTP do `sshd` está desabilitado
nessa VPS especificamente (não é erro de path).

**Causa raiz (a do exec_command+stdin):** rodando de Git-Bash/MSYS no Windows, QUALQUER argumento de
linha de comando com cara de path Unix (`/tmp/...`) passado pra um programa (mesmo `python script.py
"/tmp/foo"`) é reescrito pelo MSYS pra um path Windows ANTES do programa receber o argv — e se
`/tmp` não for um mount real nessa máquina, a reescrita produz um path bizarro tipo
`C:/Users/.../AppData/Local/Temp/foo`. O script recebe esse path MANGLED como `remote_path`, monta
`cat > C:/Users/.../foo` como comando remoto, e o bash do LADO REMOTO (Linux) tenta interpretar esse
texto — dependendo de como a string chega (quebra de linha, aspas), o resultado é um dos dois erros
confusos acima. O bug não depende do tamanho do arquivo — só de o `remote_path` ter chegado como
argumento de linha de comando (`sys.argv`) em vez de estar hardcoded dentro do `.py`.

**Solução:**
1. **Nunca passe path remoto Unix-style como argumento de bash pra um script Python** — hardcode o
   `remote_path` como constante DENTRO do arquivo `.py` (escrito via Write/Edit tool, não via
   `sys.argv`). Uma string literal lida do próprio código-fonte do script nunca passa pelo
   parser de argv do MSYS.
2. Pra arquivo GRANDE (testado com bundle git de 8,8MB): SFTP indisponível e um `exec_command` só
   com todo o base64 embutido (~11,7MB de texto) trava a conexão
   (`ConnectionResetError: [WinError 10054]`) em chunks acima de ~800KB pré-base64. **Funciona**:
   quebrar em chunks de **50KB** (pré-base64), cada um em `exec_command(f"echo '{b64chunk}' |
   base64 -d >> {remote_path}")` sequencial, com `rm -f {remote_path}` antes do primeiro chunk. 177
   chamadas de exec_command pra 8,8MB rodou sem erro nenhum; 800KB por chunk (11 chamadas) derrubava
   a conexão de forma consistente e reproduzível — o limite parece ser do lado do servidor (rate
   limit de canal SSH ou tamanho de comando), não do cliente.
3. Verificar sempre com `stat -c %s {remote}` no fim e comparar com o tamanho local — silêncio não
   prova integridade.

**Trade-off:** chunking em 50KB é ~3-4x mais chamadas de rede que o "chunk ótimo" ingênuo (800KB),
mas cada chamada é rápida (<1s) e o custo total pra 8,8MB foi menos de 2 minutos — preferível a
descobrir o limite exato do servidor por tentativa e erro repetida.

**Ref:** Paid Media Automation, cont.151, sessão 2026-08-05 (deploy da frente Google Ads multi-conta,
`scripts/vps_exec.py`/`scripts/vps_upload_stream.py`).

**Addendum (cont.153, 2026-08-06) — um SEGUNDO bug distinto na mesma área, sintoma diferente:**

Rodando `python scripts/vps_exec.py "<comando com um chunk base64 embutido>"` a partir do Bash tool
(Git-Bash), a partir de ~37.000 caracteres no comando o processo TRAVA ANTES de sair da máquina, com
`/c/Python314/python: Argument list too long` — isso **não é** o path-mangling do MSYS descrito acima
(o `remote_path` aqui já estava hardcoded no script, não vinha de argv) e **não é** limite de SSH nem
do servidor: é o teto do próprio Windows/MSYS pra tamanho total de linha de comando ao invocar
`python.exe` via `execve()`. Testado por bisseção: 20.000 e 24.000 caracteres OK, 37.000 falha —
o teto real fica em algum ponto entre esses dois valores.

**Fix que NÃO funciona:** passar o payload grande via arquivo lido por `sys.argv` (ex.: `python
script.py caminho_do_arquivo.txt`) e o script ler o conteúdo internamente — isso evita o problema
do lado do CLIENTE, mas o `paramiko.exec_command()` ainda manda a string inteira como comando remoto
via protocolo SSH, e o **próprio canal SSH tem um teto bem menor que o esperado**: testado com um
payload de ~1,3MB (bem abaixo do ARG_MAX típico do Linux) e a conexão caiu com
`paramiko.ssh_exception.SSHException: Timeout opening channel` / `EOFError` ao tentar abrir a sessão
— o servidor (ou algo no caminho, ex. firewall/fail2ban) rejeita o `SSH_MSG_CHANNEL_REQUEST` de exec
acima de um tamanho bem mais modesto que 1MB. **`scripts/vps_upload_stream.py` (stdin streaming via
`cat > file` + `stdin.write()`) foi testado de novo nesta sessão e CONFIRMADO quebrado** — falha com
`OSError: Socket is closed` mesmo pra um arquivo de poucos MB. Não gastar tempo tentando de novo sem
investigar por que o canal cai (suspeita: mesmo limite de tamanho de payload, não é bug do método).

**Fix que funciona (rápido) — uma conexão paramiko reaproveitada, chunk de ~20-24KB:**
1. Escreva o comando remoto (`echo -n '<chunk>' >> {remote_path}`) já com o chunk embutido, mas
   NUNCA deixe o Bash tool montar isso como um argv de 30KB+ pro `python.exe` — ou grave o chunk num
   arquivo `.py` temporário (constante hardcoded) e rode sem argumento, ou (mais simples) faça um loop
   em bash que escreve cada chunk em ARQUIVO e invoca o script uma vez por chunk com esse arquivo como
   único argumento pequeno (caminho, não o conteúdo).
2. **Reaproveite UMA conexão `paramiko.SSHClient` pra todos os chunks** em vez de reconectar a cada
   `vps_exec.py` (cada `connect()` novo é o gargalo dominante, não o tamanho do comando) — isso reduz
   um upload de ~8MB base64 (335 chunks de 24.000 chars) de dezenas de minutos pra ~4 minutos.
3. **Mas a mesma conexão aceita só ~80-120 `exec_command` sequenciais antes do sshd recusar** com
   `Timeout opening channel` — feche e reabra a conexão a cada ~80 chunks (não precisa retomar do
   zero: cheque `wc -c {remote_path}` pra saber de onde continuar).
4. Verifique sempre `wc -c {remote}` no fim comparado ao tamanho local esperado.

**Técnica nova pra evitar mandar histórico de git inteiro:** quando o deploy precisa só do SNAPSHOT
atual (não do histórico), um bundle completo (`git bundle create x.bundle HEAD`) de um repo com
milhares de commits pode passar de 8MB — e um bundle incremental (`git bundle create x.bundle
base..HEAD`) exige que o destino já tenha o commit `base`, o que falha se o checkout de produção
estiver numa linhagem de branch diferente da local (`error: Repository lacks these prerequisite
commits`). Solução: criar um commit SEM PAI que é só uma foto do working tree atual —
`TREE=$(git write-tree) && COMMIT=$(git commit-tree "$TREE" -m msg) && git update-ref
refs/heads/tmp-squash "$COMMIT" && git bundle create out.bundle tmp-squash && git update-ref -d
refs/heads/tmp-squash` — o bundle resultante não tem NENHUM pré-requisito (é uma raiz nova), então
`git clone out.bundle repo && cd repo && git checkout tmp-squash` funciona em qualquer máquina, do
zero, e o bundle fica muito menor (só os blobs do estado atual, sem deltas históricos). `git bundle
create` recusa "empty bundle" se você passar um SHA de commit direto sem ref — sempre crie um ref
temporário primeiro.

**Ref:** Paid Media Automation, cont.153, sessão 2026-08-06 (deploy de 6 correções + feature
HubSpot D4U, tag `d4u-369d2dbe`).
