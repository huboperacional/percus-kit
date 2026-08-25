## "Atualizei a credencial e continua falhando": env var herdada vence o .env, em silêncio {#env-var-vence-dotenv}

`tags: credencial, .env, variavel de ambiente, DEEPSEEK_API_KEY, api key invalida, precedencia, dotenv, User scope, Windows, atribuicao errada, rotacao de token`

**Origem:** Micro Investors, 2026-07-31 — revisor DeepSeek fora do ar por horas, com a causa
diagnosticada errada duas vezes antes de alguém comparar as fontes.

O revisor falhava com `Authentication Fails, Your api key: ****6032 is invalid`. O operador
rotacionou a chave e atualizou o `.env` do projeto. **Nada mudou.** O carregador faz
`if (-not $env:CHAVE) { <carrega .env> }` — ou seja, **o arquivo só é lido quando a variável não
existe**. A sessão tinha herdado a chave velha da variável de ambiente **do usuário no Windows**, que
vencia o arquivo sem dizer nada. Como a variável é a mesma em toda a casa, o revisor estava quebrado
em **todos** os projetos, não só naquele.

- **A regra:** "env var tem precedência sobre `.env`" é o padrão quase universal (dotenv,
  pydantic-settings, docker compose) e é o que se quer em produção — mas inverte a intuição de quem
  debuga: você edita o arquivo, vê o valor certo lá, e o processo segue usando outro.
- **Como diagnosticar em 30s, sem imprimir segredo** — compare os últimos 4 caracteres e o
  comprimento das **três** fontes:
  ```powershell
  $env:X.Substring($env:X.Length-4)                                   # o que o processo usa
  ((Select-String .env -Pattern '^X=').Line -split '=',2)[1].Trim()   # o que o arquivo diz
  foreach ($s in 'Process','User','Machine') { [Environment]::GetEnvironmentVariable('X',$s) }
  ```
- **Conserto:** na **origem** (`SetEnvironmentVariable(...,'User')`), não só no arquivo — senão
  volta na próxima sessão. O processo em execução mantém o valor antigo no escopo `Process`, então
  dentro da sessão corrente ainda é preciso sobrepor inline a cada chamada.
- **A armadilha de atribuição:** o plugin tinha se auto-atualizado no mesmo intervalo, e a versão
  nova virou "a causa" por pura coincidência de horário. **Antes de culpar o que mudou junto,
  compare as fontes da credencial** — é mais barato e mata a hipótese errada na hora.

**Relacionado:** [#hook-que-sai-zero-nao-avisa] — mesma família: o que está configurado não é o que
está rodando.

**Recorrência confirmada:** Família Milionária, 2026-08-25 — mesmíssimo sintoma, mesmíssima variável
(`DEEPSEEK_API_KEY`), rotacionada DUAS vezes pelo operador no `.env` do projeto e continuou
autenticando com o valor velho (`****d818`) até o script errar de novo. Confirma o "Conserto" acima:
a rotação de 31/07 (Micro Investors) só sobrepôs o `.env`, nunca a fonte `User` do Windows — por
isso "resolvido" reabriu num projeto totalmente diferente. Workaround pontual usado (não é o
conserto definitivo): `$env:CHAVE = $null` antes de chamar o script, forçando o fallback pro `.env`
só naquele processo filho.
