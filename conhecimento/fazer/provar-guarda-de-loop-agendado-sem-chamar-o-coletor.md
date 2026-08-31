## Provar uma guarda dentro de um loop agendado: arme só a precondição, nunca o coletor {#provar-guarda-de-loop-agendado-sem-chamar-o-coletor}

`tags: [5-T], turno real, cron, loop agendado, guarda de tempo, discriminante, TDD, banco antes-depois, log, distinguir caminho, teste em prod`

**Quando:** você precisa provar `[5-T]` de uma guarda que só roda DENTRO de um loop agendado (cron,
scheduler, worker de fundo) — não no caminho comum de requisição/mensagem. O risco é medir o
caminho errado: chamar o coletor à mão, ou disparar um turno pelo fluxo comum, prova que "o
resultado sai certo", não que **a guarda em questão rodou**.

**A regra: arme só a PRECONDIÇÃO (o dado que o coletor vai LER), nunca o coletor nem a ação que ele
executa.** Se a guarda decide com base num timestamp vencido (TTL), um flag, ou um campo de estado —
escreva SÓ esse campo, pelo caminho mais direto que não seja a própria função sob teste, e espere o
tick natural do loop pegar. Nunca chame a função coletora manualmente, e nunca escreva à mão o
`UPDATE`/efeito que ELA produziria — isso provaria a query, não o agendamento.

**Passo a passo (caso real, N39, 2026-08-28 — guarda de horário dentro de um resgate de handoff por
TTL de 30 min, cron de 5 min):**

1. **Prefira precondição ORGÂNICA.** Antes de escrever qualquer campo à mão, veja se uma ação real
   no sistema já produz o estado que você precisa. Aqui, uma mensagem real via WhatsApp fez o bot
   escalar sozinho e gravar `bot_paused=true`/`handoff_reason='handoff_request'` — sem SQL nenhum.
   Só restou UM campo pra armar manualmente: `bot_paused_at`, porque o TTL exige 30 min vencidos e
   esperar 30 min de verdade é caro. Escreva só esse.
2. **Confirme a precondição-irmã que o loop também checa** (aqui, `isOpen(business_hours, now)` no
   processo VIVO) antes de armar — senão você descobre o motivo errado quando o tick não disparar.
3. **Não chame o coletor.** Não invoque `reapTtlHandoffs`/a função equivalente. Espere o tick.
   `while (não achou) { sleep(20s); grep log }` até o intervalo natural do agendador — não force com
   `sleep` único do tamanho do intervalo (pode perder por segundos e você não saberia se o loop
   morreu ou só atrasou).
4. **O log da guarda quase nunca menciona o ID do recurso** — a agregação (`"devolveu N
   conversa(s)... motivos={...}"`) pode ser tudo que sai por linha. Não filtre o grep pelo ID; filtre
   pelo NOME da função/módulo e leia a janela inteira sem filtro.
5. **O discriminante mora na AUSÊNCIA, não na presença.** A prova de que foi o loop agendado, e não
   o caminho comum de mensagem, é que a janela de log **não tem** a cadeia do caminho comum (aqui,
   zero `[Webhook]`/`[Intent]` antes do `[Dispatch]`). Presença de `[Dispatch]` sozinha prova que ALGO
   mandou mensagem — não prova QUEM.
6. **Banco antes × depois, campo a campo**, capturado ANTES de armar e de novo depois do tick —
   inclusive os campos que a guarda PRESERVA (aqui, `handoff_reason` sobrevivendo à devolução).
7. **Restaure só os campos que você tocou pela guarda** — não dá pra "desmandar" mensagens reais que
   saíram (WhatsApp, e-mail, webhook) nem apagar linhas de histórico que já são fato. Documente essa
   ressalva junto com a restauração, para a próxima pessoa não achar que "terreno restaurado" cobre o
   que é irreversível por natureza.

**Por que isso generaliza:** a mesma armadilha (medir o RESULTADO em vez do CAMINHO) já apareceu
neste projeto como *"meça o ALCANCE, não o veredito da sua função"* — uma tentativa anterior mandou
um turno pelo fluxo comum, o bot respondeu normal, e isso foi confundido com prova da guarda de
tempo (que o fluxo comum nunca chama). O antídoto é sempre o mesmo: **saber qual caminho de código
está sendo exercitado, não só se o resultado observável está certo.**

Ver também, em `conhecimento/resolver/`: **tracking-em-agendador-de-terceiro-dispara-mas-nao-conta**.
