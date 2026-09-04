## `process.exit()` com um `fetch` em voo derruba o Node no Windows com assertion do libuv — e o operador vê crash onde era falha tratada {#process-exit-durante-fetch-derruba-node-no-windows}

`tags: node, windows, libuv, fetch, undici, script de verificacao, exit code, R23`

**Sintoma:** um script CLI que faz `fetch` e chama `process.exit(1)` num caminho de erro termina
com

```
Assertion failed: !(handle->flags & UV_HANDLE_CLOSING), file src\win\async.c, line 76
```

e **exit code 127**, logo depois de já ter impresso a mensagem de erro tratada. No Linux o mesmo
script sai limpo com 1.

**Causa:** `process.exit()` é abrupto — não espera o event loop drenar. Se a conexão HTTP do
`undici` (o `fetch` nativo) ainda está em fase de fechamento, o handle é destruído no meio do
caminho e o libuv aborta o processo. O `127` não vem do seu código: é o processo morrendo, não
saindo.

**Por que importa mais do que parece:** o script já tinha diagnosticado corretamente ("chave
inválida") e impresso a mensagem. O crash vem DEPOIS, e apaga a impressão de que houve
diagnóstico — quem roda conclui "o script quebrou" e vai investigar o script em vez da credencial.
Um caminho de erro bem escrito vira ruído por causa da forma de sair.

**Correção:** não matar o processo. Sinalizar e deixar o Node encerrar sozinho.

```js
// em vez de process.exit(1) no meio do fluxo:
class VerificationError extends Error {}
const fatal = (label, detail) => { log('fail', label, detail); throw new VerificationError(label); };

main()
  .catch((err) => { if (!(err instanceof VerificationError)) log('fail', 'Erro inesperado', err.message); })
  .finally(() => { process.exitCode = checks.some((c) => c.status === 'fail') ? 1 : 0; });
```

`process.exitCode` define o código e deixa o loop drenar; o `finally` ainda roda a limpeza
(remover recurso temporário criado no meio do teste), o que `process.exit()` também atropelaria.

**Como pegar isto antes do operador:** rodar o caminho de FALHA do script, não só o de sucesso, e
**conferir o exit code** (`echo $?`). Um `127` onde você esperava `1` é a assinatura. Testar só o
happy path esconde esta classe inteira, porque no sucesso normalmente não há `process.exit()`
antecipado.
