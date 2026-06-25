---
tipo: comando-e-design
quando-usar: rodar 2-4 frentes de desenvolvimento em paralelo no MESMO projeto, com uma aba-diretora orquestrando
leitura: 6 min · setup típico: 15-20 min
ultima-atualizacao: 2026-06-25
fase-destino: 7+ (v6.20.0)
status: design canônico — pilotar antes de adotar como padrão
---

# Frentes Paralelas + Orquestrador (aba-diretora)

> **O problema:** o desenvolvimento serial gargala em passos humanos sequenciais. Quando há 2-4
> blocos de trabalho **genuinamente independentes**, dá pra rodá-los em paralelo em abas separadas do
> mesmo VS Code, cada uma numa **git worktree** própria, com uma **aba-diretora** que lê o estado de
> todas e diz ao operador o que colar em cada uma.
>
> **A âncora (spec-kit):** isto só funciona depois de uma **fase fundacional** concluída (schema/auth/
> contratos/tipos compartilhados) — exatamente o "Foundational phase before any user story" do spec-kit.
> As frentes são as tarefas marcadas `[P]` (paralelizáveis) que sobram **depois** da fundação pronta.

---

## Quando usar / NÃO usar

| Cenário | |
|---|---|
| 2-4 blocos independentes (ex.: frente backend-API, frente UI, frente integração externa) que **não compartilham state mid-flight** | ✅ candidato |
| Fundação (schema, auth, contratos, tipos) **já pronta e merged** | ✅ pré-requisito |
| Tarefas que tocam os **mesmos arquivos** ou dependem do output uma da outra | ❌ serial (ou re-decompor) |
| Fundação ainda não existe / em construção | ❌ faça a fundação primeiro (serial) |
| Trabalho de 1 pessoa que cabe numa aba só | ❌ overhead não compensa |
| Projeto < ~20 arquivos ou feature única | ❌ use o fluxo normal (`feature-flow`) |

> Regra de ouro: **paralelismo é otimização, não default.** A maioria do trabalho é serial. Só quebre em
> frentes quando a independência for real e a fundação estiver firme.

---

## Pré-requisito inviolável — fundação primeiro (foundational-first)

Antes de abrir qualquer frente paralela, a **fundação compartilhada** tem que estar `[5-T]` e **merged
no branch base**:

- Schema/migrations das tabelas que as frentes vão usar.
- Auth/identidade (não pode estar mudando enquanto frentes consomem).
- **Contratos** entre frentes (tipos, shapes de API, nomes de endpoint) — congelados e escritos
  (ex.: `docs/contracts/` ou os `contracts/` de uma spec).
- Tipos/utils compartilhados.

Se duas frentes vão precisar mexer na fundação, **a fundação não está pronta** — termine-a serial primeiro.
Mudança de fundação **durante** o paralelo = conflito garantido e re-trabalho.

---

## Topologia — worktrees + aba-diretora

Uma **git worktree por frente** (dirs irmãos, `.git` compartilhado, cada uma no seu branch) + uma
worktree/aba **diretora**. Skill base: `superpowers:using-git-worktrees`.

```
projeto/                      # worktree base (branch principal — fundação merged)
projeto-frente-1/             # worktree, branch frente/1-backend
projeto-frente-2/             # worktree, branch frente/2-ui
projeto-frente-3/             # worktree, branch frente/3-integracao
projeto/orquestrador/         # NÃO é worktree — é só onde a aba-diretora lê os status + mantém o BOARD
```

```bash
# A partir da worktree base, com a fundação já merged:
git worktree add ../projeto-frente-1 -b frente/1-backend
git worktree add ../projeto-frente-2 -b frente/2-ui
git worktree add ../projeto-frente-3 -b frente/3-integracao
```

No VS Code: **multi-root workspace** (Add Folder to Workspace) unifica as 3 worktrees + a base numa
janela só. Cada pasta = uma aba de Claude Code.

---

## Decomposition gate — validar independência ANTES de abrir frentes

Não confie no "parece independente". Antes de fan-out, valide a decomposição:

1. Liste, por frente, os **arquivos/módulos que ela vai tocar**.
2. Se duas frentes tocam o **mesmo** arquivo mutável → **não** são independentes; re-decomponha ou serialize.
3. Rode `/council:consult` (ou `/percus-review:spec-analyze` se há spec) com a pergunta: "estas N frentes
   tocam conjuntos disjuntos de arquivos e não dependem do output uma da outra?" — o conselho aponta
   acoplamento escondido (ex.: ambas precisam de um campo novo na fundação → volta pra fundação).

---

## Writer-unique protocol — zero corrida de escrita

A regra que torna o paralelo seguro: **cada arquivo tem um único escritor.**

- Cada frente escreve **somente** o seu `orquestrador/status/frente-N.md` (mais o código do seu branch).
- A **aba-diretora** é a **única** escritora de `orquestrador/BOARD.md`.
- **Nenhuma** frente escreve no código de outra frente nem no status de outra.
- Cada frente commita no **seu** branch — sem working tree compartilhada, sem corrida de commit.

### Template `orquestrador/status/frente-N.md` (cada frente atualiza o seu)

```markdown
# Frente N — {nome}
_Atualizado: {YYYY-MM-DD HH:MM} · branch: frente/N-xxx_

- ESTADO: {1 linha — o que está funcionando / em que passo [0]→[5-T]}
- ÚLTIMO PASSO: {literal}
- PRÓXIMO PASSO: {literal}
- BLOQUEIO: {depende de outra frente / fundação / operador — ou "nenhum"}
- PRONTA PRA MERGE? {sim/não}
```

---

## Papel da aba-diretora (Aba 0)

A diretora **não escreve código de negócio**. Ela orquestra (espelha o protocolo cross-repo: ela é a
"caixa de texto" — o operador é o mensageiro entre abas).

Loop da diretora:
1. **Lê** os `orquestrador/status/frente-*.md` de todas as frentes.
2. **Atualiza** `orquestrador/BOARD.md` (visão consolidada: estado de cada frente, bloqueios, ordem de merge).
3. **Detecta** acoplamento/divergência (duas frentes assumindo coisas diferentes do contrato; uma
   bloqueada esperando outra).
4. **Emite um bloco de instrução por frente** — texto que o **operador cola** na aba daquela frente
   ("Frente 2: a fundação adicionou o campo X; ajuste o componente Y e atualize seu status").
5. Quando uma frente diz "PRONTA PRA MERGE", a diretora decide a **ordem de merge** (passo abaixo).

> A diretora **não** edita os arquivos das frentes nem os status delas — só lê e produz os blocos. O
> operador é quem cola. Isso mantém o writer-unique protocol intacto.

---

## Disciplina de merge / reconvergência

Merge é **serial e ordenado pela diretora** (nunca duas frentes mergeando juntas):

1. Diretora escolhe a ordem (geralmente: a que mexe em mais superfície compartilhada primeiro, ou a
   menos arriscada primeiro — declare o critério no BOARD).
2. Frente A → `/percus-review:review` no seu branch → merge no base.
3. **Re-sincronizar as outras frentes** com o base atualizado (`git rebase base` ou `merge base` em cada
   worktree) **antes** da próxima merge — pega conflito cedo, uma frente por vez.
4. Repete pra B, C...
5. Conflito que toca a **fundação** → para tudo: a mudança pertence à fundação (serial), não a uma frente.

Cada merge passa pelo R11 (review). Marco completo → `/percus-review:milestone-review`. Deploy só nos
gatilhos do **R24** (não a cada merge de frente).

---

## Limpeza

```bash
git worktree remove ../projeto-frente-1   # após merge + branch integrado
git worktree prune
```

---

## Anti-padrões

- ❌ Abrir frentes antes da fundação estar `[5-T]` e merged — conflito garantido.
- ❌ Duas frentes tocando o mesmo arquivo mutável — não é paralelo, é corrida.
- ❌ Diretora editando código/status das frentes — quebra o writer-unique protocol.
- ❌ Duas frentes mergeando "ao mesmo tempo" sem re-sincronizar entre merges.
- ❌ Mudar contrato/fundação dentro de uma frente — volta pra fundação (serial).
- ❌ Paralelizar trabalho que cabia numa aba — overhead de worktree + orquestração não compensa.
- ❌ "Vou usar worktree depois" — depois é nunca (`superpowers:using-git-worktrees`).

---

## Piloto recomendado (antes de virar padrão)

Status deste doc: **design canônico, a pilotar.** Sugestão de 1º piloto:
- Um projeto com fundação já pronta e **exatamente 2 frentes** claramente disjuntas (ex.: backend-API
  vs UI consumindo mock do contrato).
- Rode 1 ciclo completo (decomposition gate → 2 worktrees → diretora → merge ordenado).
- Registre o que funcionou/atritou em `conhecimento/COMO_RESOLVER.md` (ou `COMO_FAZER.md`) e só então
  escale pra 3-4 frentes.

## Referências

- Skills: `superpowers:using-git-worktrees`, `superpowers:dispatching-parallel-agents`,
  `superpowers:subagent-driven-development`.
- Decomposição/independência: `06_CONSELHO_PERCUS.md` (consult/analyze).
- Fundação + `[P]`: mapeamento spec-kit↔Percus em `06_CONSELHO_PERCUS.md`.
- Cadência de deploy pós-merge: `comandos/DEPLOY.md` + R24.
- Tracking por frente: `templates/PLANO.template.md` (frentes já são um conceito do PLANO).
