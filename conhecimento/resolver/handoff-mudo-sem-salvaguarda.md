## Conversa escalada pra humano fica MUDA e ninguém percebe (54 msgs em 34 min) {#handoff-mudo-sem-salvaguarda}

tags: handoff, bot_paused, escalonamento, atendente, reaper, virada de dia, cliente orfao, alerta unico, anti-spam whatsapp

**Contexto:** bot escala pra atendente e **cala** naquela conversa (gate salva a mensagem e retorna). O reaper devolvia ao bot só na **virada do dia**. Medido em prod: **54 mensagens do cliente em 34 minutos**, zero resposta, zero sinal novo. O único aviso foi o do instante da pausa — se o operador não vê aquele, o cliente fica órfão por até ~24h. **Foi o operador que percebeu, olhando o WhatsApp**, não o sistema.

**Causa raiz:** "escalei" foi modelado como estado terminal esperando ação humana, sem nenhum caminho de volta dentro do dia e sem reincidência de aviso. Um único alerta é um **evento**, não um **lembrete**: some no meio das notificações.

**Solução (padrão reaproveitável):** três camadas, com estado por conversa e **por EPISÓDIO** de handoff:
1. **Cliente:** UMA resposta automática na 1ª mensagem durante a pausa ("já chamei um atendente"). Nunca mais que uma.
2. **Operador:** re-alertas em marcos de tempo (5 e 10 min), **só se o cliente continuar mandando**, com teto duro.
3. **TTL de retorno** ao bot (não só virada de dia), **só se nenhum humano respondeu** — senão o bot fala por cima do atendente.

⚠️ **Duas armadilhas:** (a) os contadores têm que zerar em **TODOS** os caminhos que despausam — não só no helper "oficial": no nosso caso 4 dos 5 eram `UPDATE` cru em rotas do painel, e sem o reset um **segundo** handoff da mesma conversa nasceria "já avisado" e ficaria mudo de novo; (b) devolver ao bot sem **saída** re-escala pelo mesmo motivo → ping-pong; guarde o MOTIVO do handoff e ofereça alternativa (ex.: fora-de-área → oferecer retirada).

**Ref:** tiatendo mig 104, `execution/engine/handoffNudge.py`, `execution/engine/handoffCleanup.py` (2026-07-25).
