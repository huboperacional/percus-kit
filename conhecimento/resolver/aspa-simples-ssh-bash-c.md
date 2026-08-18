## Args com aspa simples atravessando `ssh` + `bash -c` selecionam a coisa ERRADA, sem erro {#aspa-simples-ssh-bash-c}

tags: ssh, bash -c, aspas, quoting, pytest -k, selecao de testes, falso verde, paramiko, payload

**Sintoma:** `-k 'a or b'` (ou qualquer arg com aspa simples) enviado por SSH dentro de
`bash -c '...'` roda **sem erro** e reporta "1 passed" — mas selecionou testes que você não pediu, ou
nenhum dos que importavam. Você lê o verde e acha que provou algo.

**Causa raiz:** a aspa simples do arg **fecha o wrapper** `bash -c '...'`. O que sobra é reparseado
como argumentos soltos, e ferramentas como o pytest aceitam argumentos a mais sem reclamar.

**Solução:** escapar no padrão POSIX antes de montar o comando —
`args.replace("'", "'''")` — ou não passar payload por `bash -c` (subir um script por SFTP e
executá-lo). E ao ler o resultado de uma execução filtrada, **confira o número de testes
selecionados/deselecionados**, não só o "passed": foi a contagem que não fechava (2 selecionados
onde deviam ser 3) que revelou o problema.

**Ref:** Plexco Tasks s150 (2026-07-26), `vps-test.py::run_pytest`. Parente de
[#json-sed-aspas](json-sed-aspas.md).
