## `execFile` com `ssh` NÃO protege o argv — o remoto reconcatena e o shell de lá re-divide {#execfile-com-ssh-nao-protege-argv-o-remoto-re-divide}

tags: ssh, execFile, execFileSync, argv, quoting, shell remoto, psql, node, playwright, R23

**Sintoma.** Você troca `exec`/string por `execFileSync(cmd, [args])` **justamente** para não
depender de quoting de shell — e o comando falha mesmo assim, com erro de sintaxe do `bash` do
outro lado:

```
bash: -c: line 1: syntax error near unexpected token `('
bash: -c: line 1: `docker exec -i c psql -d db -tAc SELECT count(*) FROM t WHERE id = 'x''
```

**Causa raiz.** `execFile` protege o argv **local**: o `ssh` recebe cada elemento separado, sem o
shell da sua máquina tocar em nada. Só que o `ssh` **não transmite um vetor** — ele junta todos os
argumentos restantes com espaço numa **string única** e entrega isso ao shell de login do host
remoto, que então re-divide por espaço e interpreta metacaracteres. Ou seja: a proteção que você
comprou vale até a porta de saída, e o outro lado desfaz. `(`, `)`, `*`, `;`, `|`, `<`, `>` e aspas
voltam a ser sintaxe.

É particularmente enganoso porque a mesma chamada funciona sem `ssh` no meio: `execFile('docker',
[...])` local passa o argv de verdade.

**Solução — mande o payload por STDIN, não por argumento.** Tira o shell remoto do caminho por
inteiro, em vez de tentar escapar para ele:

```js
// ❌ o SQL vira argumento -> string -> shell remoto -> sintaxe
execFileSync('ssh', ['host', 'docker','exec','-i','c','psql','-d','db','-tAc', sql])

// ✅ o SQL vai por stdin; nenhum shell o enxerga
execFileSync('ssh', ['host', 'docker','exec','-i','c','psql','-d','db','-tA'],
             { input: sql, encoding: 'utf8' })
```

Vale igual para `psql` (`-tA` lendo stdin em vez de `-tAc <sql>`), `python -` , `jq -f -`,
`sh -s`, `bash -s`, `kubectl exec -i`. Sempre que a ferramenta remota aceitar stdin, prefira-a a
qualquer nível de escape.

🔑 **O sinal de que é ISTO e não outra coisa:** a mensagem de erro é do **`bash` remoto**, não da
ferramenta que você queria rodar, e ela mostra o comando **inteiro em uma linha só** — inclusive o
payload que deveria ser um argumento. Se o erro fosse de quoting local, o comando nem sairia.

⚠️ **Não confunda com [`aspa-simples-ssh-bash-c`](aspa-simples-ssh-bash-c.md).** Lá o defeito é
aspa do payload fechando um wrapper `bash -c '...'` que VOCÊ montou, e a saída é escapar. Aqui não
há wrapper nenhum e o payload nem tem aspas: quem monta a string é o próprio `ssh`, e a saída é
não passar payload por argumento.

**Caso real** (Empresa Milionária, 2026-09-13). Um helper de teste R1 ganhou um irmão de leitura
(`consultarSqlNoContainer`) copiado do irmão de escrita, mas com o SQL movido de `input:` para
`-tAc <sql>`. Toda consulta com `count(*)` morria no `bash` remoto. O irmão de escrita nunca
tinha esse problema — e o motivo não era sorte nem estilo: ele sempre passou o SQL por `input`.
Quando um par de funções quase idênticas se comporta diferente, a diferença que importa costuma
ser essa, não a lógica.
