## Ferramenta de medição queima a sessão de refresh, e o sintoma aparece na corrida seguinte {#ferramenta-de-medicao-queima-a-sessao-de-refresh}

`tags: playwright, storageState, refresh token, rotacao, reuse detection, sessao, e2e, OTP, write-back, medicao em producao, concorrencia, sequenciamento`

**Contexto:** scripts de medição (varredor de contraste, checador de cor computada,
`[5-T]` automatizado) que carregam o `storageState` do Playwright e navegam em produção.
Cada um parece inofensivo — "só leio a tela". O dano é **cumulativo e diferido**, então a
atribuição de causa vai para a coisa errada.

### O mecanismo

1. A ferramenta carrega `e2e/.auth/admin.json`.
2. O app **renova o access** durante a corrida (TTL curto; uma varredura de 28 rotas passa
   dele).
3. O auth-service **rotaciona** o refresh e invalida o antigo.
4. A ferramenta **não grava de volta**. A corrida **seguinte** manda o `rt` velho.
5. Servidor vê reuso → mata a **família inteira** → `401 invalid refresh`, e só um OTP
   interativo recupera.

🔑 O erro aparece **longe da causa**, numa corrida que não fez nada de errado. Duas
sessões perdidas numa noite foram atribuídas a "corrida longa demais" antes de o mecanismo
ficar claro.

### Duas causas distintas, e a segunda é pior

- **Passiva:** carregar e não devolver (acima).
- **ATIVA:** criar um **segundo contexto** a partir do mesmo arquivo *depois* que o
  primeiro já renovou. Isso não é "esquecer de gravar", é reuso deliberado do `rt` velho —
  e derruba a família imediatamente. Uma ferramenta escrita para *provar* uma feature
  matava a sessão sozinha.

### Conserto

**Um helper que cria e devolve**, e a proteção mora nele — não num `try/finally` por
ferramenta, porque são N ferramentas e a próxima nasce sem:

```js
export async function criarContextoMedicao(browser, opts = {}) {
  const { storageState: _ignorado, ...resto } = opts   // opts NÃO pode trocar o arquivo
  const ctx = await browser.newContext({ storageState: ESTADO, ...resto })
  const salvarEMorrer = async (e) => { await fecharComWriteBack(ctx); console.error(e); process.exit(1) }
  process.once('uncaughtException', salvarEMorrer)
  process.once('unhandledRejection', salvarEMorrer)
  return ctx
}
```

O **caminho de erro é justamente onde a rotação já aconteceu** — a corrida foi longa o
bastante para o access vencer, e *então* algo estourou. Write-back só no fim feliz mata a
família exatamente nas corridas que a pessoa repete em seguida.

Três invariantes no `fecharComWriteBack`:

- **Guard de identidade:** só regrava se for a MESMA conta. Uma ferramenta que logue com
  outro perfil sobrescreveria a sessão do operador, e a corrida seguinte inteira nasceria
  na conta errada sem nada acusar. Arquivo **ilegível** também recusa — token corrompido
  não autoriza trocar a conta em silêncio. Distinga `ENOENT` de erro de parse: "ilegível"
  quando o arquivo **não existe** manda diagnosticar corrupção onde o problema é ausência.
- **Escrita atômica** (tmp + rename): escrita interrompida deixa JSON truncado, que o
  Playwright recusa no boot seguinte — trocar "sessão velha" por "arquivo quebrado" é
  piorar.
- **Devolva o que fez** (`gravado` / `sem-sessao` / `recusado-*`) e logue. Write-back
  silencioso que não aconteceu é o modo de falha caro.

**Guard que sobrevive à próxima ferramenta:** conte `criarContextoMedicao(` contra
`fecharComWriteBack(` no arquivo e exija igualdade. Presença não vê multi-contexto.

### O write-back NÃO cobre dois casos — e confundi-los custa tempo

- **Revogação.** `POST /token/revoke` mata a família **no servidor**; nenhum write-back
  salva. Quem precisa disso é a suíte (interceptar a chamada), não a ferramenta.
- **Concorrência da suíte sobre um access já vencido.** A suíte roda N workers, cada um com
  um contexto do MESMO arquivo. Se o access já venceu quando ela começa, **todos** renovam
  com o mesmo `rt` → reuse. Isso é **sequenciamento**, não código: rode a suíte
  *imediatamente* depois de autenticar. Um intervalo de duas horas entre `auth` e `run`
  produz ~35 testes caindo na tela de login, o que **parece** regressão de código e não é.

### Diagnóstico: separe "sessão morta" de "tela quebrada"

Ferramenta que espera por um `h1` mede a **tela de login** quando a sessão cai — o login
tem `h1`, e a saída sai plausível. Procure o **shell** (um marcador que só a tela certa
possui), não marcadores do login: um campo de telefone existe legitimamente numa aba de
perfil, e o guard passa a abortar rota saudável. E `page.url()` sozinho não basta — logo
após o `h1` o redirect do guard de rota pode não ter commitado.

Ver também: [[playwright-baseurl-path-absoluto-apaga]], [[teste-string-nao-prova-gate-runtime]],
[[cors-derruba-login-e-a-tela-culpa-o-codigo]].
