## Perna do conselho emite veredito sobre a spec que ela NÃO leu inteira — o orquestrador trunca e o log não registra quanto cada uma viu {#perna-do-conselho-reprova-spec-que-nao-leu-inteira}

`tags: conselho, spec-analyze, council-orchestrator, truncagem, veredito, groq-llama, cross-claude, teto de tokens, falso positivo, R25, review`

**Sintoma:** o `spec-analyze` devolve findings pedindo coisas que **já estão escritas na spec** — às
vezes no parágrafo seguinte ao que o finding cita. Pior: uma perna devolve `BLOQUEADA` e as outras
devolvem `AJUSTAR` sobre o mesmo documento, e a divergência parece desacordo de julgamento quando é
diferença de **quanto cada uma leu**.

**O caso medido (2026-09-12).** Segunda rodada de analyze de uma spec de enforcement. O orquestrador
avisou no stderr, e o aviso passou despercebido porque parece rotina:

```
[council-orchestrator] AVISO: prompt truncado de 9329 -> ~8000 tokens.
[council-orchestrator] perna 'groq-llama' tem teto proprio de 5000 tokens:
                       prompt truncado de 7804 -> ~4794 (o das outras pernas fica inteiro).
```

A perna Llama viu **~4794 de 9329 tokens — 51% do documento** — e emitiu `VEREDITO: BLOQUEADA (1
CRITICAL)`. O CRITICAL dizia que a spec duplicava tabelas de outros verbetes (violação de R25). Três
dos outros findings dela pediam explicitamente requisitos que existiam na metade cortada.

**Como o CRITICAL foi refutado — por medição, não por argumento.** A própria spec propunha um
detector de bloco duplicado; rodá-lo contra o repositório responde a acusação com um número:

| Escopo varrido | Blocos ≥200 chars duplicados em 2+ docs | Envolvendo a spec acusada |
|---|---|---|
| 1397 docs (exclusão só por *prefixo*) | 736 | 0 |
| 1051 docs (`node_modules/` excluído em **qualquer** profundidade) | 9 | 0 |

Zero. E de quebra a medição revelou um segundo defeito que nenhuma perna viu: a exclusão por prefixo
deixava passar `templates/*/node_modules/` espelhados, que sozinhos respondiam por **727 dos 736**.

**Por que isto é pior que um finding errado.** Um finding errado se descarta lendo. Um **veredito**
errado governa fluxo: `BLOQUEADA` é o estado que impede a spec de virar `[0]`. E o log
(`.deepseek/council-log/<ts>-analyze.jsonl`) grava `responses[].content` e `responses[].status` —
mas **não grava quantos tokens cada perna recebeu**. Quem lê o log depois vê três vereditos
aparentemente comparáveis. Não são: um deles foi emitido sobre metade do documento.

**O incentivo fica invertido.** Quanto mais completa a spec (mais requisitos, mais edge cases
cobertos, mais disposição de findings anteriores registrada), mais ela estoura o teto e **menos
confiável** fica o analyze dela. A spec que mais precisa de revisão é a que menos a recebe.

**Mitigação imediata (usada aqui):** a perna Cross-Claude roda como subagente e tem ferramentas de
leitura — dê a ela o **caminho do arquivo**, não o texto. Ela lê do disco, sem truncagem, e ainda
verifica as afirmações da spec contra o repositório. Foi a única das três a produzir findings de
fato novos nesta rodada, incluindo um HIGH de ordem de execução que as outras duas não tinham como
ver.

**Conserto de verdade (pendente, no kit):** uma das duas —
1. o orquestrador passa **arquivo** em vez de texto quando o alvo é um arquivo e a perna sabe ler; ou
2. o log grava, por perna, **quanto ela viu** (`tokens_enviados` / `truncado: true|false`), e o
   resumo marca veredito de perna truncada como não-comparável.

Sem (1) ou (2), a única defesa é ler o stderr do orquestrador em toda rodada.

**Discriminante:** o finding pede algo que você acha que já escreveu? Antes de discutir mérito,
**meça o que a perna recebeu**. Se a ferramenta trunca e não registra a truncagem, todo veredito dela
é uma afirmação sobre um documento que você não sabe qual é.

Prima direta de [[auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe]]: nos dois
casos o artefato que deveria **medir** estava medindo um **rótulo** — lá, o número de regra que o
hook cita sobre si mesmo; aqui, o veredito que a perna cita sobre um texto que ela não recebeu
inteiro. Ver também [[perna-conselho-nao-e-perna-morta]], que trata do caso irmão: perna que volta
vazia ou 429 e é contada como opinião.
