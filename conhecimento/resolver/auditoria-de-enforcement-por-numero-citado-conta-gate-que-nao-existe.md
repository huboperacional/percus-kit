## Auditar enforcement pelo NÚMERO DE REGRA que o hook cita conta gate que não existe — o canon renumera, o comentário não {#auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe}

`tags: canon, enforcement, hook, auditoria de regras, R5, R6, R12, R25, detector por nome, renumeracao, types-check, migration-check, conselho, cross-claude, CRITICAL`

**Sintoma:** uma auditoria diz *"esta regra já tem enforcement mecânico"* e o hook citado enforce
outra coisa completamente. A regra segue sem gate, e a auditoria — o documento que existe para achar
regras sem gate — **esconde** a lacuna em vez de revelá-la.

**O caso medido (2026-09-12).** A auditoria das 25 regras do canon foi construída com um varredor por
número:

```bash
for n in $(seq 1 25); do grep -rl "R$n\b" hooks/*.ps1; done
```

Resultado: 11 regras "com enforcement mecânico", entre elas **R5** e **R6**. Verificando o conteúdo:

| Regra | O que a regra diz HOJE | O que o hook que a cita faz |
|---|---|---|
| **R5** | confirmação antes de operação que custa dinheiro ou é irreversível | `types-check-pre-commit` roda `mypy --strict` / `tsc --noEmit` |
| **R6** | banco de dados novo por projeto (naming, role dedicada, prefixo Redis) | `migration-check-pre-commit` cobra migration junto com model change |

Nenhuma relação. Os hooks se autodeclaram `(R5)` e `(R6)` na **linha 2 do próprio arquivo** — o canon
foi renumerado em algum momento e o comentário dos hooks ficou para trás. "Tipos explícitos" e
"migration junto com o model" eram R5 e R6 num canon anterior.

**Contagem corrigida: 9 com enforcement, não 11.** R5 e R6 vão para o balde das descobertas.

**Por que o detector por número é pior que o detector por nome comum.** O varredor casa um
identificador (`R5`) que **não é propriedade do hook** — é uma afirmação que o hook faz *sobre si
mesmo*, em prosa, sem ninguém verificando. É a mesma família de
[[detector-que-casa-identificador-por-texto]], com um agravante: ali o
identificador pelo menos descrevia o código; aqui ele descreve um **documento externo que mudou**. Um
comentário não é um vínculo — é uma cópia, e cópia diverge (R25).

**Como auditar de verdade:** cruze **conteúdo com conteúdo**, nunca número com número. Para cada
hook, leia o que ele bloqueia e case com o corpo da regra; para cada regra, pergunte *"que observável
prova isso?"*. O número citado no comentário é ponto de partida para a pergunta, nunca a resposta.

**Quem pegou:** a perna **Cross-Claude** do conselho, num `spec-analyze`, com veredito `BLOQUEADA` —
e pegou porque foi ler `01_REGRAS_INEGOCIAVEIS.md` e os hooks em vez de aceitar a tabela da spec. As
outras duas pernas (DeepSeek, Llama) devolveram `AJUSTAR`/`PRONTA` sem tocar na premissa: elas
revisaram a **forma** dos requisitos (termo vago, N indefinido, vazamento WHAT→HOW) e não a
**verdade** deles. Conselho que só olha forma ratifica premissa falsa bem formatada — é o motivo de a
perna que lê o repositório valer o custo.

**Discriminante:** a auditoria afirma que algo **existe** (um gate, um hook, uma cobertura)? Então ela
é uma medição, e medição se faz contra o artefato, não contra o rótulo do artefato. Se o único
vínculo entre a regra e o gate é uma string escrita à mão num comentário, você não mediu enforcement
— mediu boa vontade de quem comentou.

**Fecha o círculo com a R12:** a regra diz *"se você não consegue verificar objetivamente que
cumpriu, é decoração"*. Uma auditoria de decoração feita por casamento de rótulo é decoração de
segunda ordem — e foi exatamente o que quase virou commit, documentando gate falso em R5 e R6 sob a
justificativa de "dívida só documental".

Ver [[regra-declarada-automatica-sem-hook-e-decoracao]] — é o verbete DONO da tabela de auditoria, e
foi ele que esta correção consertou (11/7/7 → 9/7/9).
