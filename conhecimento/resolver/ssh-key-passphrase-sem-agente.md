## SSH: "Server accepts key" e logo "Permission denied" {#ssh-key-passphrase-sem-agente}

`tags: ssh, permission denied, publickey, passphrase, ssh-agent, batchmode, rotacao de chave, deploy travado, automacao, chave revogada`

**Contexto:** depois de uma rotação de chaves, toda automação que fala com a VPS (ssh_runner,
deploy_v2, watchdogs locais) passa a falhar com `Permission denied (publickey,password)`.
Tentar a chave nova falha igual — o que induz a culpar a rotação no servidor.

**Causa raiz:** rode `ssh -v`. Se aparecer `Server accepts key: ... ED25519` **antes** do
`Permission denied`, a pública ESTÁ autorizada no servidor — o que falha é o cliente **provar
posse** da privada. Causa quase sempre: a chave nova foi gerada **com passphrase** e não há
ssh-agent carregado. Como toda automação usa `BatchMode=yes`, o ssh não pode pedir a senha e
falha calado. Confirme: `ssh-keygen -y -f <chave> -P ""` (erro = tem passphrase) e `ssh-add -l`
(`Could not open a connection...` = sem agente). Dica extra: chave ed25519 cifrada tem ~464
bytes; sem passphrase, ~411.

**Solução:** carregue no agente (`eval $(ssh-agent) && ssh-add <chave>`) ou, melhor, use o
agente do OpenSSH do Windows como **serviço** — persiste entre reboots e mantém a chave cifrada
em disco. Remover a passphrase (`ssh-keygen -p`) funciona mas desfaz metade do ganho da rotação.
E **não esqueça** de atualizar o `SSH_KEY_PATH` (ou `IdentityFile`) que a automação usa: apontar
pra chave revogada dá exatamente o mesmo erro por outro motivo.

**Ref:** Família Milionária, rotação de 2026-07-23 (travou deploy e acesso a prod).
