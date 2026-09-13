## O system prompt do revisor tem uma CÓPIA do canon, e 7 das 19 regras têm o texto errado {#system-prompt-do-revisor-tem-copia-do-canon-com-texto-de-regra-errado}

`tags: review, R11, R25, cross-claude, system-prompt, canon, copia do canon, renumeracao, canon-version-check, warn permanente, single-source-of-truth, drift de canon, poda do canon, CONSERTADO 2026-09-13`

**Sintoma:** a perna Cross-Claude do conselho aponta violação de uma regra que **não é** aquela
regra, ou deixa passar violação óbvia de uma regra que ela acha que é outra coisa. O finding vem
bem formado, com número e nome — e o nome não bate com o canon.

**A causa, medida em 2026-09-12:** `plugin/percus-review/providers/system-prompt-review.md` e
`system-prompt-consult.md` não *apontam* para o canon — eles carregam uma **cópia inline das 19
primeiras regras**, escrita à mão numa numeração **anterior à renumeração do canon**. Sete das
dezenove trazem o texto errado **debaixo do número certo**:

| Nº | O canon diz hoje | O que a cópia inline diz |
|---|---|---|
| R1 | Critério único de "feito": ciclo CRUD com F5 | Linguagem e tom |
| R2 | Tracking de status — atualização imediata | Arquitetura por frentes |
| R4 | Setup de credenciais — pare em vez de contornar | Subagent-driven development |
| R6 | Banco de dados — sempre novo por projeto | Stack canônica |
| R8 | Sessão sem HANDOFF é débito técnico | Testes via TDD onde aplicável |
| R9 | Superpowers — não são opcionais | Pre-commit review obrigatório |
| R12 | Toda regra precisa de verificação verificável | Checklist de code review |

As outras doze batem. Medir você mesmo, sem confiar nesta tabela:

```bash
grep -nE "^## R[0-9]+\." 01_REGRAS_INEGOCIAVEIS.md
grep -nE "^\*\*R[0-9]+ —" plugin/percus-review/providers/system-prompt-review.md
```

**Por que é PIOR que a faixa velha** de
[[revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida]]: a faixa curta tornava as
regras acima do teto **invisíveis** — o revisor simplesmente não as avaliava. Aqui ele avalia, com
convicção, contra uma **definição que não existe mais**. Invisível você descobre pela ausência;
errado chega como finding fundamentado.

**Por que sobreviveu — e esta é a parte generalizável.** Existe um hook que deveria pegar:
`plugin/percus-review/hooks/canon-version-check.ps1`. Ele compara o `canon_version` do frontmatter
dos `system-prompt-*.md` com o `CANON_VERSION.md`. Só que um está em **data** (`2026-05-17`) e o
outro em **semver** (`6.50.0`), e o próprio comentário do hook declara isso como intencional:

> *"Comparacao string vai SEMPRE divergir — isso e intencional: warn permanente lembra operador de
> revisar apos cada bump."*

**Aviso que dispara sempre é aviso desligado.** Ele avisou em todo commit desde maio e não produziu
nenhuma revisão da cópia; virou ruído que se aprende a rolar para baixo. Um sinal que nunca fica
verde não distingue nada — é a mesma família de guarda morta respondendo verde, com o defeito
invertido: guarda viva gritando sempre.

**Isto é violação de R25 (single-source-of-truth) pelo próprio ferramental que cobra R25.**

**Como aplicar:**

1. Antes de confiar num finding da perna Cross-Claude que cite regra por **nome**, confira o nome
   contra `01_REGRAS_INEGOCIAVEIS.md`. Se o nome não bate, o finding é sobre outra coisa.
2. **Não conserte reescrevendo a cópia à mão.** Seria a terceira geração do mesmo defeito: uma
   cópia manual do canon que envelhece calada. O conserto é injetar os títulos das regras **lidos do
   canon em tempo de execução**, como já se faz com a faixa (`_faixa-regras.{ps1,sh}` +
   `{{FAIXA_REGRAS}}` substituído no load do `.md` por `cross-claude.{ps1,sh}`). Foi isso que se
   fez: o mecanismo existia para o teto e foi estendido para os títulos (`{{REGRAS_DO_CANON}}`).
3. **Ao desenhar warn permanente, pergunte se ele pode ficar verde.** Se a resposta é não por
   construção, ele não é aviso: é decoração ruidosa, e cai na R12 pelo mesmo critério das regras sem
   gate. Prefira comparar coisas comparáveis (mesma unidade) ou não avisar.
4. **Isto bloqueava a poda do canon** (item 9 do plano de enforcement): decidir que uma regra
   "morreu porque ninguém a cobra" era inválido enquanto o revisor cobrasse a regra ERRADA sob
   aquele número. Com o conserto, a poda destravou — ver o estado no fim.

**Estado:** ✅ **CONSERTADO em 2026-09-13 (6.51.0).** O bloco inline virou o placeholder
`{{REGRAS_DO_CANON}}`, substituído no load por `cross-claude.{ps1,sh}` com os títulos lidos do
canon — mesmo mecanismo já usado para a faixa. Ficou **menor** que a cópia (1 690 chars contra
~2 850) além de sempre correto.

Duas coisas que o conserto ensinou, e que valem mais que o conserto:

1. **A guarda burra quase apagou conteúdo bom.** A primeira varredura casou `^\*\*R<N> —` no
   arquivo inteiro e comeu 85 linhas — levando junto a seção *"Antipadrões invioláveis"*, que usa
   o mesmo formato mas são exemplos concretos de violação com código, conferidos e **corretos**.
   O limite certo é o bloco entre o cabeçalho `## Regras inegociáveis` e o próximo `##`.
   Guarda que mira formato em vez de posição destrói vizinho inocente.
2. **O teste ponta a ponta quase deu falso negativo por causa de JSON.** O corpo trafega como
   JSON, então as aspas do título da R1 (*Critério único de "feito"*) chegam escapadas (`\"`) e
   a comparação literal falhava — o que **pareceria** "o título não chegou", exatamente o oposto
   do que estava acontecendo. Desescape antes de comparar, ou você conserta o que já funciona.

Guarda: `plugin/percus-review/tests/regras-do-canon-injetadas.tests.ps1` — reprova lista de
regras escrita à mão sob aquele cabeçalho, e prova por socket local que o corpo enviado ao modelo
leva o título do canon de agora e nenhum placeholder cru.