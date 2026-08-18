## `storageState` cacheado de sessão OTP fica inválido entre rodadas separadas: refresh reativo dentro do browser nunca é gravado de volta em disco {#storagestate-refresh-reativo-nao-persiste}

tags: playwright storageState cache, refresh token rotation single-use, auth.setup cache valido,
otp login cache 30 dias, invalid refresh 401, sessao expira entre invocacoes separadas, e2e
automated login token rotation lost

**Sintoma:** um `auth.setup.ts` (ou script equivalente) faz login real (OTP, magic-link, etc.),
salva `access_token`+`refresh_token` num `storageState` em disco, e um sidecar de metadados marca
"válido por ~30 dias" (TTL do refresh). Lógica simples: "se o cache ainda está dentro da janela,
pula o login". **Funciona na primeira invocação, quebra silenciosamente em invocações
posteriores** — uma spec/teste que roda depois volta pra tela de login, com erro
`{"detail":"invalid refresh"}` ao tentar renovar, mesmo dentro da janela de 30 dias.

**Causa raiz:** o access token dura pouco (ex. 15min). Assim que expira, o PRÓPRIO app/frontend
(interceptor de 401, refresh reativo automático) troca o par de tokens sozinho pra manter a UX —
isso é o comportamento CORRETO e desejado em produção. Mas o refresh é **single-use com rotação**:
a resposta de `/token/refresh` vem com um `refresh_token` NOVO que invalida o antigo. Esse refresh
automático acontece DENTRO do browser context daquele teste específico — só existe no `localStorage`
daquela sessão efêmera, nunca é regravado no arquivo de `storageState` em disco (só quem escreve
esse arquivo é o script de setup, que só roda 1x por invocação). A PRÓXIMA invocação (novo processo,
novo browser context) carrega o arquivo ANTIGO, com o `refresh_token` que JÁ FOI consumido/rotacionado
pela rodada anterior → `POST /refresh` rejeita com 401 `invalid refresh` → sessão morre.

**Como confirmar que é isso:** pegue o `refresh_token` gravado no `storageState` em disco e teste
direto contra o endpoint de refresh (`curl -X POST .../token/refresh -d '{"refresh_token":"..."}'`)
— se vier `invalid refresh`/401, o token já foi consumido em algum momento depois da última vez que
o arquivo foi escrito.

**Solução:** não trate "cache válido" como "pula tudo". Trate como "renova PROATIVAMENTE via
`/token/refresh` (rota SEM rate limit, diferente do endpoint de login/OTP que costuma ter) e
regrava o `storageState`+metadados a cada invocação" — só cai pro login completo (OTP/magic-link)
se essa renovação em si falhar (aí sim o refresh morreu de verdade, não só rotacionou). Isso garante
que o arquivo em disco nunca fica desatualizado em relação ao último refresh que aconteceu, seja
ele proativo (nosso) ou reativo (do próprio app numa rodada anterior). Ressalva: isso NÃO cobre
rotação que acontece NO MEIO de uma mesma rodada longa com múltiplas specs sequenciais (>15min de
ponta a ponta) — cada spec nessa mesma invocação ainda carrega o storageState ORIGINAL da memória/
disco do início da rodada; se uma spec do meio disparar o refresh reativo, specs seguintes DA MESMA
rodada podem herdar o token já rotacionado. Mitigação parcial: manter a rodada mais curta que a
validade do access token, ou (não implementado ainda) regravar o storageState após cada spec.

**Ref:** Família Milionária, sessão 2026-08-07 — conta E2E sintética
(`docs/superpowers/plans/2026-08-07-e2e-synthetic-account.md`, Task 7). Confirmado testando o `rt`
do disco direto contra `/token/refresh` (`invalid refresh`). Fix em
`familia-frontend/tests/e2e/auth.setup.ts` (commit `8105db1`): cache válido agora sempre renova
antes de reusar, em vez de só pular.
