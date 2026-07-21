# Loop: checkpoint — fechar sessão sem perder contexto

**Quando:** fim de milestone, contexto ficando grande, ou antes de `/clear`.

**Por quê:** a sessão seguinte não herda sua memória — ela herda **os arquivos**.

## O loop

**1. Atualize os 4 artefatos.** Cada um recebe só o que é dele:

| Arquivo | Recebe | NÃO recebe |
|---|---|---|
| `HANDOFF.md` | estado atual, próximo passo, bloqueios | histórico do que já foi feito |
| `docs/PLANO.md` | features e estado real (`[0]`→`[5-T]`) | narrativa de sessão |
| `CONTEXT.md` | termo de domínio novo ou afiado | implementação |
| `docs/adrs/` | decisão que passou no triple-gate | ideia descartada em 5 minutos |

> **Reconcilie contra o `PLANO`, não recopie o `HANDOFF`.** Ao reescrever, confira cada item de "Em obra" no `PLANO`: se o `PLANO` marca `[5-T]` (com evidência de teste/smoke) e o `HANDOFF` ainda diz "em obra", o **`PLANO` vence** — a anotação velha não vira fato. Compactar relendo só o `HANDOFF` **propaga** o erro: foi assim que um `[4-C]` fantasma sobreviveu 7 semanas e foi promovido de um doc de 660 linhas a fato num de 34 (sessão fria Paid Midia, 2026-07-21).

**2. Empurre o passado para fora.** O que virou histórico sai do `HANDOFF` para `docs/historico/`. **O HANDOFF descreve o presente — ele não é log.**

**3. Cheque o teto** (150 linhas). Estourou → o excedente é histórico. **Mova, não comprima.**

**4. Registre conhecimento novo.** Problema resolvido nesta sessão vira verbete com linha `tags:` **e** entrada no índice. Sem `tags:`, o verbete fica invisível à busca — trabalho feito, valor zero.

**5. Review + commit** dos artefatos.

## O que NÃO fazer

**Não gere "texto pra colar".** Bloco de retomada é foto: envelhece no instante em que é tirada e obriga o operador a carregar estado na mão. Os arquivos são a fonte viva — a sessão nova lê `HANDOFF` → `PLANO` → `CONTEXT` → ADRs recentes.

## Armadilha que já custou caro

Um hook que pergunta "o HANDOFF mudou?" premia **acrescentar linha no fim** — a forma mais barata de satisfazê-lo. Foi assim que um HANDOFF real chegou a **6.185 linhas** e passou a custar ~90k tokens por boot, com o agente lendo estado truncado.

**Meça tamanho, não delta.**
