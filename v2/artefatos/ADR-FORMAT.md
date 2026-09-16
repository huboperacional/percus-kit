# Formato: `docs/adrs/NNNN-<slug>.md` — decisões

**Dono de:** o **porquê**. O que foi decidido, contra o quê, e o que isso custa.

## O formato já existe — use o do V1

**Template:** `${env:PERCUS_CANON_DIR}/templates/adr-0000-template.md` (MADR + extensão Percus).

⚠️ **O caminho `docs/adrs/` e os campos são contrato, não estilo.** O crawler do Painel lê `docs/adrs/*.md` via API do GitHub e popula `feature_adrs`. Mudar a pasta ou omitir os campos abaixo **quebra a integração**:

- `Status:` Proposed | Accepted | Deprecated | Superseded by [ADR-NNNN]
- `Applied-to:` — projetos onde vale (consumido pelo crawler)
- `Feature-slug:` — liga ao `catalog-info.yaml`
- Seções: **Context · Decision · Consequences · Alternatives considered**

## Quando abrir: o critério é do V1

**Quando** abrir ADR é obrigação e mora em `05_FEATURE_TRACKING.md` § "Quando criar ADR": quatro perguntas
verificáveis; basta um "sim". Este arquivo cuida só do **como** escrever.

O V2 tinha aqui um "gate de três" (difícil de reverter + surpreendente + trade-off real, os três juntos). Ele
nasceu para resolver um problema real — "significativa" era elástico e havia projeto sem nenhum ADR —, mas
contradizia o V1 e deixava sem registro o sunset que afeta vários projetos. Saiu em 2026-09-16; o critério
verificável do V1 resolve o mesmo problema sem a contradição.

## Teste rápido (ajuda a escrever o Context, não decide se abre)

*"Se me perguntarem isso de novo daqui a três meses, eu vou querer ter onde apontar?"* — a resposta vira o
primeiro parágrafo do Context.

## Regras

- **Numeração sequencial**, nunca reutilizada. Decisão revogada vira `Superseded by`, não é apagada.
- **Escreva no momento em que a decisão cristaliza** (durante o `grilling`), não no fim do projeto.
- **O descarte consciente também passa pelo critério.** "Vamos NÃO fazer X, por causa de Y" vira ADR quando responde "sim" a uma das 4 perguntas do V1 — tipicamente a 4 (fica a dívida, com dono). É o tipo que mais economiza rediscussão.
