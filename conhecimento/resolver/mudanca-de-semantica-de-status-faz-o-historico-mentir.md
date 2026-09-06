## Mudar o SIGNIFICADO de um status faz o histórico mentir sobre datas — a transição que você vê é o deploy, não o fato {#mudanca-de-semantica-de-status-faz-o-historico-mentir}

`tags: status, enum, log historico, semantica que muda, deploy retroativo, reescrita de linhas antigas, finished_at, diagnostico datado, correlacao falsa, PARTIAL, R23`

**Origem:** Paid Media Automation, 2026-09-06 — investigando por que um cliente entrou num vigia de
conta inativa.

**O caso.** Uma conta de anúncio mostrava, no log de coleta, `SUCCESS` todo dia até 31/08 e
`PARTIAL` de 01/09 em diante. A leitura natural — e errada — é *"alguma coisa quebrou nessa conta
em 01/09"*. A data parece um diagnóstico pronto.

**O que realmente aconteceu:** três dias antes, um deploy trocou a regra de
`status = "SUCCESS"` (qualquer caminho sem exceção) para
`status = "SUCCESS" if total > 0 else "PARTIAL"`. As linhas de 01/09 em diante tinham `finished_at`
de **04-05/09** — foram (re)escritas por uma cascata de recoleta **já com o código novo**. As linhas
antigas nunca foram reescritas, então ficaram com o valor da regra velha. **O status mudou porque o
CÓDIGO mudou; a conta não fez nada naquele dia.**

🔑 **A armadilha é específica e traiçoeira:** um enum cuja regra muda **não invalida o histórico de
forma visível** — ele cria uma fronteira temporal que *se parece exatamente* com um evento real, e
que cai perto da data do deploy. Pior: se houver recoleta/backfill, a fronteira **não** coincide com
a data do deploy, e sim com o alcance da recoleta — o que remove até a pista óbvia ("ah, foi no dia
que subimos").

**Como aplicar.**

1. **Antes de datar uma mudança de comportamento por mudança de status, olhe o carimbo de ESCRITA
   da linha** (`finished_at`, `updated_at`, o que houver), não só a chave de data. Se as linhas do
   "antes" e do "depois" foram escritas por versões diferentes do código, a fronteira é sua, não do
   mundo.
2. **Confirme por uma fonte que não passe pelo enum.** No caso medido, `metrics_daily` (existe linha
   de métrica naquele dia, sim ou não?) sustentou a conclusão sozinho, sem depender do status. Uma
   afirmação sobre o mundo não pode ter como única testemunha um campo que a gente acabou de
   redefinir.
3. **Ao trocar a semântica de um status, registre a data de corte junto do enum** — no comentário da
   migration, no docstring, onde o próximo leitor vai passar. Quem lê o histórico seis meses depois
   não tem como adivinhar que `PARTIAL` só existe a partir de tal dia.

⚠️ **Corolário que motivou o achado:** um status assim **não serve de guarda para decisão
automática**. Aqui, `PARTIAL` passou a significar "zero linhas escritas SEM exceção" — e isso cobre
igualmente "o anunciante parou de verdade" (legítimo) e "nossa coleta cegou sem levantar erro"
(defeito nosso). Dois reviewers independentes recomendaram cruzar um watchdog destrutivo com esse
log; a medição mostrou que o cruzamento **não distingue os dois casos** e só daria falsa sensação de
proteção. Só o status de exceção (`FAILED`) é inequívoco — e é o caso fácil e raro.

Relacionado: [[watchdog-de-ausencia-le-depois-do-produtor]].
