# Formato: `docs/adrs/NNNN-<slug>.md` — decisões

**Dono de:** o **porquê**. O que foi decidido, contra o quê, e o que isso custa.

## O formato já existe — use o do V1

**Template:** `${env:PERCUS_CANON_DIR}/templates/adr-0000-template.md` (MADR + extensão Percus).

⚠️ **O caminho `docs/adrs/` e os campos são contrato, não estilo.** O crawler do Painel lê `docs/adrs/*.md` via API do GitHub e popula `feature_adrs`. Mudar a pasta ou omitir os campos abaixo **quebra a integração**:

- `Status:` Proposed | Accepted | Deprecated | Superseded by [ADR-NNNN]
- `Applied-to:` — projetos onde vale (consumido pelo crawler)
- `Feature-slug:` — liga ao `catalog-info.yaml`
- Seções: **Context · Decision · Consequences · Alternatives considered**

## O que o V2 acrescenta: o gate de três

O V1 já manda registrar decisão significativa, mas "significativa" é elástico — e o resultado observado foi **projeto sem nenhum ADR**. O gate: **abra ADR só quando os TRÊS forem verdade.**

1. **Difícil de reverter** — mudar de ideia depois custa caro.
2. **Surpreendente sem contexto** — um leitor futuro vai perguntar "por que fizeram assim?".
3. **Resultado de trade-off real** — havia alternativa concreta e você escolheu uma por motivos específicos.

**Faltando um dos três, não faça ADR.** Sem esse corte, ou ninguém escreve (o caso de hoje) ou todo mundo escreve e ninguém lê.

## Teste rápido

*"Se me perguntarem isso de novo daqui a três meses, eu vou querer ter onde apontar?"* — se sim, os três critérios provavelmente estão presentes.

## Regras

- **Numeração sequencial**, nunca reutilizada. Decisão revogada vira `Superseded by`, não é apagada.
- **Escreva no momento em que a decisão cristaliza** (durante o `grilling`), não no fim do projeto.
- **Registre também o descarte consciente.** "Vamos NÃO fazer X, por causa de Y" é ADR — é o tipo que mais economiza rediscussão.
