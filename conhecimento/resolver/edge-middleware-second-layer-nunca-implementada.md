## Middleware edge-safe (só shape do cookie) sem 2ª camada real nos route handlers = bypass de auth {#edge-middleware-second-layer-nunca-implementada}

`tags: auth, middleware, edge runtime, cookie, session, defense in depth, bypass, review por-task, subagent-driven-development, holistic review`

**Contexto:** painel de admin AutoWorx (`ads4agencies-site`), 19 tasks via `subagent-driven-development`,
cada task revisada em 2-3 camadas (implementador + spec-review + code-quality). Todas as 19 tasks
passaram limpo. Só um review HOLÍSTICO final (depois de todas as tasks prontas, traçando o fluxo
ponta-a-ponta manualmente) achou que **toda rota `/api/admin/*` protegida aceitava um cookie forjado**
(`autoworx_admin_session=x.y`, nunca assinado de verdade) — upload de foto e troca de vídeo no site AO
VIVO, sem login nenhum. Confirmado com `next dev` + curl antes e depois do fix.

**Causa raiz:** o middleware roda em Next.js Edge Runtime, que não bunda `node:crypto` — então ele só
fazia checagem ESTRUTURAL do cookie (`.split('.')` tem 2 partes não-vazias). O comentário do próprio
código dizia "a verificação criptográfica real acontece de novo em cada route handler protegido
(defense in depth)" — mas essa 2ª camada nunca foi escrita em NENHUM dos 3 handlers protegidos. A
função de verificação real (`verifySessionCookie`, com HMAC) existia, tinha teste unitário próprio, e
tinha **zero call-sites em produção** (grep confirma).

**Por que passou por 3 tasks de middleware/rotas + 2-3 rounds de review cada uma:** cada task testa
o próprio arquivo isolado — o teste do middleware chama `middleware()` direto (nunca invoca um route
handler), e o teste de cada rota chama `POST()`/`GET()` direto (nunca passa pelo middleware). As duas
metades do sistema de auth nunca foram exercitadas JUNTAS por nenhum teste automatizado — um gap de
INTEGRAÇÃO entre tasks, invisível pra qualquer review escopado a uma task só.

**Solução:** função `isAuthenticatedRequest(req)` lendo o header `Cookie` bruto (não `next/headers`'
`cookies()`, que lança fora de request real do Next — quebraria todo teste existente) + reusando
`verifySessionCookie()` já existente. Adicionada no início de cada rota protegida, ANTES de qualquer
outra lógica. Testes novos cobrindo os 3 casos que faltavam: sem cookie / cookie forjado (shape válido,
assinatura inválida) / cookie real assinado — exatamente o eixo que nenhum teste cobria antes.

**Lição pro processo, não só pro código:** revisão por-task (por mais rigorosa) não pega gap de
integração entre tasks. Antes de declarar um plano multi-task sensível a auth como "pronto", sempre
fazer UM review holístico final que traça o fluxo inteiro ponta-a-ponta lendo o código real (não
confiando nos reports das tasks) — e, se o plano envolve auth, tentar o exploit ao vivo de verdade
(cookie forjado, request sem credencial) contra um servidor rodando, não só confiar nos testes
unitários (que testam cada metade isolada e por isso não veem o buraco entre elas).

**Ref:** `ads4agencies-site` branch `feat/autoworx-admin-panel`, commit `de68300` (fix) — achado durante
a review holística final da skill `subagent-driven-development` (Scraper-prospeccao, sessão 2026-08-06).
Memória `reference_edge_middleware_structural_check_needs_second_layer`.
