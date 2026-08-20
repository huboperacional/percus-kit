## Suíte E2E com teste de logout mata a própria sessão (revogação, não rotação) {#suite-e2e-com-teste-de-logout-mata-a-propria-sessao}

`tags: e2e, playwright, refresh token, revoke, token/revoke, invalidate_family, storageState, write-back, rotacao, reuse-detection, 401 invalid refresh, auth-service, OTP, sessao compartilhada, diagnostico, write-back de token`

**Contexto:** uma suíte E2E roda contra **produção** reusando **uma sessão compartilhada**
(`storageState` do Playwright com `access` + `refresh`). Toda corrida completa terminava com a sessão
morta: o `refresh` seguinte devolvia `401 invalid refresh` e só um OTP novo no WhatsApp do operador
recuperava. Custo: uma interrupção humana **por corrida**.

**Causa atribuída (errada, por meses):** *rotação*. `/token/refresh` rotaciona e invalida o token
anterior; se o par novo não voltar para o arquivo, a corrida seguinte apresenta um `rt` já usado e
cai em *reuse-detection*. A hipótese é plausível, o sintoma é idêntico, e ela gerou trabalho real:
um write-back completo (fixture regravando o `storageState` **após cada teste**, guard de "sessão
viva" para não gravar estado deslogado, `finally` no teste de cold start). Tudo correto. Nada
resolveu.

**Causa raiz:** **revogação**. O `signOut()` do app chama `POST /token/revoke`, e o endpoint invalida
a **FAMÍLIA INTEIRA** do token apresentado (`revoke_family` → `invalidate_family`), não só aquele
token. A suíte tem um teste de logout. Determinístico, toda corrida.

**Por que nenhum write-back podia salvar:** o problema não é o valor gravado no arquivo — é o
servidor ter matado a família. Um arquivo com o token "certo" e uma família revogada são
**indistinguíveis** até alguém tentar usar. O guard de "só grave se houver sessão viva", que existe
para não sobrescrever o arquivo com o estado deslogado do teste de logout, está certo e **garante**
que o arquivo preserve um token morto.

**O que separou as duas hipóteses em dois minutos:** rodar **UM** spec e olhar o `mtime` do arquivo
de `storageState`. Mudou → o write-back funciona → a causa é outra. Barato, e evita reconstruir pela
segunda vez algo que já funciona.

**Agravante de diagnóstico:** o comentário no `signOut` dizia *"logout é client-side only… não
notifica servidor"*. Era verdade quando foi escrito e ficou falso quando o refresh token de 30 dias
entrou. Comentário que afirma comportamento é afirmação testável — e essa custou tempo.

**Conserto:** interceptar no fixture, para toda a suíte:

```ts
await context.route('**/token/revoke', route =>
  route.fulfill({ status: 204, contentType: 'application/json', body: '' }))
```

O teste de logout continua verificável: o app limpa o storage local **antes** de revogar e nem
espera a resposta, então o redirect e a limpeza acontecem igual.

**Não torne opt-in.** O primeiro teste novo que exercitar logout volta a queimar a sessão. Em vez
disso, torne a proteção **visível** em todo teste — `testInfo.annotations.push(...)` — e logue só
quando ela realmente interceptar. (Achado de review: proteção automática que só aparece quando
dispara é invisível para quem escreve um teste novo, e alguém poderia afirmar "a revogação NÃO
aconteceu" com o mock mascarando a chamada real.)

**Para afirmar algo sobre a revogação**, instale um `page.route` no próprio teste — **rota de página
tem precedência sobre rota de contexto** — e conte as tentativas.

**A prova de que consertou não é a suíte verde** (verde ela já estava): é rodar a suíte inteira e o
`refresh` funcionar **depois** dela.

Ver também: [[teste-string-nao-prova-gate-runtime]], [[comentario-afirma-garantia-que-o-codigo-nao-entrega]].
