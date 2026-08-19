## `globalTeardown` não enxerga o contexto do teste — write-back de sessão tem que ser por teste {#global-teardown-nao-enxerga-o-contexto-do-teste}

tags: playwright globalTeardown, storageState desatualizado, refresh token rotacionado, 401 em bloco,
reuse detection, write-back de sessao, fixture auto, suite inteira vermelha, e2e auth de novo

**Sintoma:** a suíte E2E roda inteira, e na corrida seguinte dezenas de testes quebram de uma vez com
redirect para `/login`. Parece regressão enorme no app; é sessão. O diagnóstico rápido: se
`POST /token/refresh` devolve 401 e `auth/me` também, é o **arquivo de sessão** uma geração atrás,
não código.

**Causa raiz:** cada teste cria seu contexto a partir do MESMO `storageState` em disco. Quando o
access expira no meio da corrida, o primeiro teste que renova **rotaciona** o refresh token — e todos
os seguintes continuam mandando o `rt` velho. Com *reuse detection* no auth, isso derruba a família
inteira.

**A correção óbvia não funciona.** `globalTeardown` roda em **Node, depois da corrida, sem contexto
de browser nenhum**: o par rotacionado mora no `localStorage` do ÚLTIMO contexto, que a essa altura
já foi destruído. Um teardown que abrisse um browser novo carregaria o estado **do próprio arquivo**
— ou seja, gravaria de volta exatamente a geração velha que se queria substituir. E não encostaria
no modo de falha real, que é **no meio** da corrida, não no fim.

**Solução:** regravar o `storageState` **após CADA teste**, via fixture `auto` que depende de
`context` (o teardown da fixture roda antes do contexto morrer). Assim o próximo contexto nasce da
geração corrente. Como os specs importam `test` de `@playwright/test`, isso exige um módulo de
fixture compartilhado + **guard** que impeça spec novo de importar do pacote direto e perder o
write-back em silêncio.

**DOIS guards são obrigatórios, senão o conserto vira um matador de suíte pior que o problema:**

1. **Sessão viva.** O spec de auth costuma terminar com um teste de **logout**, que por definição
   deixa o `localStorage` sem token. Write-back incondicional grava o estado **deslogado** por cima
   do arquivo e a próxima corrida inteira começa sem sessão.
2. **Identidade.** Só grave se o `sub` do JWT bater com o que já está no arquivo. Um spec que
   autentique com outro perfil trocaria a conta do arquivo sem nenhum teste vermelho apontando a
   causa. Três casos, não dois: arquivo **inexistente** é bootstrap legítimo (deixa gravar); arquivo
   **existente e ilegível** RECUSA (corrompido não autoriza trocar a conta); existente e legível só
   grava se a identidade for a mesma.

**Cuidado de concorrência:** isto pressupõe execução **serial** (`workers: 1`, `fullyParallel: false`).
Com workers concorrentes, dois contextos gravam intercalado e o último a escrever vence — podendo ser
o mais VELHO. Guarde essa premissa com teste sobre a config.

**Escrita atômica** (`tmp` + `rename`): o arquivo é a única coisa entre o operador e um login manual
com OTP no celular. Processo morto no meio de um `writeFileSync` direto deixa JSON truncado, que o
runner rejeita no boot da próxima corrida.

Ver também `#suite-verde-com-menos-arquivos` (o placar mentindo por outro motivo).
