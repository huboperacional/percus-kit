## Capturar stdin em `cmd.exe` trunca acima de ~80 KB **saindo 0** — e payload cortado vira JSON inválido que todo hook engole {#captura-de-stdin-em-cmd-trunca-acima-de-80kb-e-sai-zero}

`tags: cmd.exe, stdin, more, findstr, truncagem, payload, hook, JSON invalido, falha silenciosa, dispatcher, fail-loud`

**Sintoma:** a cadeia de hooks funciona o dia inteiro e **some no comando grande** — sem erro, sem
aviso, sem nada no stderr. Comandos pequenos seguem sendo verificados.

**Causa.** `cmd.exe` não tem como bufferizar stdin sem perder. Os dois idiomas usados na prática
falham, e falham **devolvendo sucesso**. Medido em 2026-09-12, mesmo payload JSON de uma linha:

| payload | `more > arq` | `findstr "^" > arq` |
|---|---|---|
| 3 KB, acentos UTF-8 | exato | exato |
| **80 KB** | **corrompe** (80 055 ≠ 80 053) | exato |
| 200 KB | — | **trunca para 73 781** |
| 1 MB | — | **trunca para 53** |

Nos dois casos o exit code é **0**. Não há sinal nenhum de que o dado foi cortado.

**Por que isso apaga enforcement em vez de degradá-lo.** Payload cortado no meio não é um JSON menor
— é um JSON **inválido**. Cada hook faz `ConvertFrom-Json` dentro de um `try`, o `catch` sai 0
("não consegui ler, não bloqueio"), e a cadeia inteira passa. O resultado é que **os comandos
maiores são os menos verificados** — exatamente ao contrário do que se quer, porque comando grande
é o mais provável de estar fazendo algo sério.

**Duas decisões que saem disso:**

1. **A captura é `findstr "^"`, nunca `more`.** O `more` já corrompe onde o findstr ainda é exato.
2. **Quem consome o payload DEVE validar que ele parseia, e falhar ALTO se não parsear.** Não há
   recuperação possível: stdin só pode ser lido uma vez e já foi consumido. A escolha real não é
   entre "barrar" e "funcionar" — é entre **barrar avisando** e **passar calado**.

```
[percus:dispatch-pre] BLOCK: payload nao parseia como JSON (204,9 KB).
  Causa provavel: a captura de stdin em cmd.exe trunca acima de ~80 KB.
  Nenhum check pode rodar -- e passar em silencio esconderia isso.
```

**O limite é da CAPTURA, não da busca.** Vale separar, porque um levantamento apontou um limite de
128 KiB por linha no `findstr` que devolveria `rc=1` silencioso — e isso **não se confirmou**: na
forma `findstr /L /I /G:padroes.txt arquivo.json`, uma linha de **2 MB** devolve `rc=0` normalmente,
e `rc=1` corretamente quando o padrão falta. Buscar é seguro; **gravar** é que perde.

**Discriminante:** seu `.cmd` redireciona stdin para arquivo? Então existe um tamanho a partir do
qual ele mente, e o consumidor tem de detectar. Teste com payload de 200 KB, não só com o do dia a
dia — o caminho comum nunca exercita o defeito, que é por que ele sobrevive.

Mesma família de [[conte-os-vermelhos-guarda-que-passa-vazia]]: o mecanismo devolve "tudo certo"
para uma entrada que ele não conseguiu processar.
