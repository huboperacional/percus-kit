## Harness com um usuário só, sempre administrador, esconde todo estado "pendente" {#harness-com-um-usuario-admin-esconde-estado-pendente}

`tags: R1, harness de teste, seed de usuario unico, alcada, aprovacao, workflow pendente, self-approval, auto-aprovado, multi-usuario, fila de aprovacao, magic link, token em claro`

**Contexto:** um harness de R1 (Playwright + Postgres efêmero) autentica **uma única conta
sintética**, que é sempre a criadora/dona da empresa/organização de teste — logo, sempre tem a
alçada mais alta (administrador). Três specs diferentes, de features diferentes, bateram na
MESMA parede no mesmo dia: um painel de "responsáveis técnicos aguardando aprovação" nunca
mostrava nada; um "enviar para aprovação" não tinha ninguém pra notificar; um "fila de
aprovação por link" não tinha como emitir um token de verdade.

**Causa raiz (a mesma, três vezes):** qualquer fluxo cujo primeiro passo é *"algo nasce
pendente até um administrador aprovar"* tem, no desenho do produto, um **atalho legítimo**: se
quem CRIA já é administrador, o próprio ato de criar conta como aprovação (o admin não precisa
aprovar a si mesmo). Isso não é bug — é a decisão certa de produto (`carimbarSeAdministrador`,
"a decisão mora na borda, o caso de uso não conhece papel de quem chama"). Mas um harness com
UM usuário só, sempre esse admin, faz o "pendente" ser estruturalmente inalcançável: não existe
carga de trabalho onde reproduzir o estado que o teste quer provar.

**Segundo sintoma, mais caro:** filas de aprovação por *magic link* (nunca vira sessão, por
desenho — ver ADR de link de capacidade) devolvem o token bruto **só pelo canal de notificação**
(WhatsApp/e-mail), nunca por API. Com um usuário só, o endpoint de emissão também costuma
EXCLUIR o próprio remetente dos destinatários ("quem pediu não recebe o próprio pedido de
volta") — resultado: zero destinatários, zero link, nada pra testar, mesmo que o dispatch
"funcionasse".

**Como reconhecer que é isto, e não um bug de UI:**
1. Teste a API direto (sem o browser): crie o recurso com a MESMA conta que o harness usa, leia
   de volta. Se o campo de aprovação já vem `true`/preenchido sem nenhuma ação de aprovação,
   é o atalho de admin, não falha de fetch/timing.
2. Grep pelo texto da decisão no código-fonte (`carimbarSeAdministrador`, `exceto=remetente`,
   comentário citando o FR) — produto bem documentado costuma dizer isso em voz alta perto da
   borda (router/controller), não no caso de uso.
3. Confira se APENAS um usuário existe na massa de dados do harness. Se sim, e o fluxo depende
   de "alguém sem a alçada X propõe, alguém com a alçada X decide", ele é estruturalmente
   inalcançável até existir um segundo usuário com alçada menor.

**Fix, em ordem de custo:**
- **Não force o teste a existir.** Reescreva o spec pra provar o que É alcançável com um
  usuário só (o atalho de auto-aprovação, os caminhos de erro sem estado pendente — 404 de
  token inválido, 422 de ação sobre recurso já decidido) e documente a lacuna no cabeçalho.
- **Não invente workaround pro canal fechado.** Forjar o hash do token direto no banco pra
  simular "recebi a mensagem" contorna exatamente o mecanismo de segurança que a feature
  existe pra impor — não é o espírito do R1 (prova comportamento real, não prova bypass).
- **Real fix, mais caro:** bootstrap de um SEGUNDO usuário sintético sem a alçada alta (mesmo
  mecanismo de OTP/login do primeiro, papel diferente) — só compensa se o produto tiver
  vários fluxos de aprovação (aqui, três no mesmo dia já pagou o investimento).

**Ref:** Empresa Milionária, 01/09 — `PainelDeTecnicosPendentes` (FR-106), "Enviar para
aprovação" (FR-024, buraco 6), `TelaAprovacaoPorLink` (ADR-0012, grupo 6) — três specs,
mesma causa, achada independentemente por duas sessões no mesmo dia.
