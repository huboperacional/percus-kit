## Nota de bloqueio sem data de RECONFERÊNCIA sobrevive à própria correção {#nota-de-bloqueio-vencida}

`tags: handoff, plano, tracking, bloqueio, documentacao vencida, metadado que mente, R2, reconferencia`

**Contexto:** `PLANO.md`/`HANDOFF.md` com uma nota de "🚨 BLOQUEIO" que trava uma fase inteira.

**Sintoma:** dias depois, a nota continua lá e alguém (humano ou agente) planeja trabalho em cima
dela — no caso real, um runbook inteiro pedindo ação do operador num sistema que **já funcionava**.

**Causa raiz:** a nota tinha data de CRIAÇÃO e nenhuma de reconferência. Ela foi escrita quando era
verdade, o problema foi corrigido no mesmo dia por outro caminho, e ninguém voltou pra fechá-la.
Metadado que mente é pior que metadado ausente, porque é lido como verdade.

**Solução:**
1. Antes de agir sobre qualquer bloqueio com mais de um dia, **confirme no dado** que ele existe.
2. Toda nota de bloqueio nasce com o **comando que a refuta** ao lado ("se isto devolver X, o
   bloqueio acabou"). O bloco "Reproduza você mesmo" do PLANO desse projeto é o modelo.
3. Sinal de que a nota está vencida: ela descreve consequência que o banco não confirma. Exemplo
   real — a nota dizia "os itens ficam presos em `triggered` pra sempre", e a tabela tinha **zero**
   itens em `triggered` e 12 fechados com `variant` preenchido, que só a tag produz.

**Ref:** `D:\Claud Automations\Kommo-Disparo-WhatsApp\docs\PLANO.md` (frente Fase 5),
`docs/runbooks/RUNBOOK_TAG_DE_RESULTADO_SALESBOT.md`. 2026-08-14.
