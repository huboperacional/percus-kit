## `vps_exec.py "psql ..." < arquivo.sql` fica parado até o timeout: o wrapper não repassa stdin {#vps-exec-sem-stdin-psql-espera-para-sempre}

`tags: vps_exec, paramiko, stdin, psql, docker exec -i, redirecionamento, hang, timeout, base64, git bash, msys`

**Sintoma:** `python scripts/vps_exec.py "docker exec -i <pg> psql ..." < consulta.sql` não imprime nada e
estoura o timeout da ferramenta. Parece banco lento ou lock.

**Causa:** o `vps_exec.py` (paramiko `exec_command`) não encaminha o stdin local para o canal remoto. O
`psql -i` fica esperando entrada que nunca chega.

**O que fazer:** mande o SQL DENTRO do comando, em base64, e decodifique no remoto:
`B=$(base64 -w0 consulta.sql); python scripts/vps_exec.py "echo $B | base64 -d | docker exec -i -e PGPASSWORD='...' <pg> psql -h 127.0.0.1 -U <user> -d <db>"`.
Use `-h 127.0.0.1` com senha por `PGPASSWORD` (sem ela a autenticação local por socket pode recusar o
usuário da aplicação). Para enviar ARQUIVO, escreva pelo stdin do canal num script paramiko próprio
(`exec_command("cat > /destino")` + `stdin.write` + `shutdown_write`) — rodando pelo PowerShell ou com
caminho Windows, porque o Git Bash com `MSYS_NO_PATHCONV=1` deixa de converter `/c/...` locais e sem ele
converte `/tmp/...` remotos.

Relacionado: [[docker-exec-stdin]].
