# Handoff Consumidores — R11 sem ponto único de falha (v6.56.1)

> **Para:** a sessão Claude de qualquer projeto Percus que commita com review R11.
> **De:** canon Percus `percus-kit` v6.56.1 (`CANON_VERSION.md`, changelogs 6.56.0 e 6.56.1).
> **Data:** 2026-09-15.

---

## 1. O que mudou (1 minuto)

Antes, se a API do DeepSeek travasse, o R11 parava: não havia jeito suportado de registrar a review
feita por um subagente Sonnet. Cada sessão gravava um `.jsonl` à mão em `.deepseek/reviews/`, e o
hook aceitava qualquer arquivo com o nome certo, até `{}`.

Agora:

| Peça | Comportamento novo |
|---|---|
| `deepseek-review` | timeout de 180 s e **1 retry automático**; provedor fora → **exit 4**, sem marcador, corpo (chave mascarada) em `.deepseek/reviews/ultimo-erro.txt` |
| `percus-review-auto` (wrapper) | grava placeholder e emite `__PERCUS_NEEDS_CROSS_CLAUDE__` **com a linha pronta** do `registrar-review` |
| `registrar-review` (novo) | grava a review Cross-Claude em `d-<hash>.jsonl` + `latest.jsonl`, com o mesmo hash que o hook calcula |
| Hooks de commit (PreToolUse e git nativo) | **leem o marcador**: só `findings` não vazio libera; placeholder libera só 5 min, com aviso e linha em `deferidos.log`; `{}`, vazio ou lixo **bloqueiam** |

As regras (`01_REGRAS_INEGOCIAVEIS.md` R11) e as skills do plugin já descrevem o fluxo novo. Nada a
fazer no código do projeto.

## 2. O que a sessão faz quando aparece `__PERCUS_NEEDS_CROSS_CLAUDE__`

1. Dispare o subagente Sonnet com o prompt R11 cross-claude-review, como antes.
2. Grave os findings dele num arquivo **FORA do repo** — `$env:TEMP\r11-findings.txt` (PowerShell)
   ou `$(mktemp)` (Bash). Dentro do repo, um `git add` muda o `git diff HEAD` e o hash registrado
   deixa de bater.
3. Rode a linha que veio no marcador. Forma geral:
   - Ferramenta PowerShell: `& '<caminho>\registrar-review.ps1' -Arquivo '<arquivo>' -Canal cross-claude -Modelo '<modelo>'`
   - Ferramenta Bash: `pwsh -NoProfile -File '<caminho>\registrar-review.ps1' -Arquivo '<arquivo>' -Canal cross-claude -Modelo '<modelo>'`
     (ou `bash '<caminho>/registrar-review.sh' --arquivo ... --canal cross-claude --modelo ...`)
4. Saída esperada: `hash=<12 hex> latest=<caminho> d=<caminho>`. Commite **sem mexer em arquivo**
   depois do registro (qualquer mudança troca o hash).

**Nunca** calcule hash nem escreva `.jsonl` à mão.

## 3. Mensagens novas do hook e o que significam

| Mensagem | Significado | O que fazer |
|---|---|---|
| `AVISO: commit SEM review real -- liberado por placeholder deferido` | passou só pelo placeholder (≤5 min) | registre a review Cross-Claude; declare em voz alta |
| `BLOCK: marcador latest.jsonl invalido: <motivo>` | o arquivo não é review nem placeholder | rode o review de novo; não "conserte" o `.jsonl` |
| `d-<hash>.jsonl recusado: <motivo>` | havia marcador do diff, mas sem conteúdo de review | idem |
| `[deepseek-review] PROVEDOR INDISPONIVEL apos retry ... (exit 4)` | DeepSeek fora | siga o item 2 |

## 4. Checagem por projeto (30 segundos)

Rode na raiz do projeto (ferramenta Bash):

```bash
grep -c percus-classifica-marcador .git/hooks/pre-commit 2>/dev/null   # 2 = hook git novo; 0 ou erro = antigo/ausente
grep -n "cross-claude.jsonl" CLAUDE.md AGENTS.md 2>/dev/null           # nada = texto em dia
```

Situação medida em 2026-09-15 nesta máquina:

- **Hook git reinstalado (6.56.1)**, com backup `.git/hooks/pre-commit.bak-2026-09-15`: CL_LiliCalc,
  Melhoria na VPS, Micro Investors (bloqueio de `session_replication_role='replica'` preservado),
  Padrao Comportamento Humano, Paid Midia Automation, Plexco Coach, Plexco Tasks, Plexco Tickets,
  Robo de Poker V1, Scraper-prospeccao, Social-Midia-IA, auth-service, tiatendo. Nos que tinham
  gate V2 depois do bloco Percus, o gate foi mantido e roda também quando o R11 libera pelo hash.
- **Sem hook git do R11** (só gate V2 ou nenhum): nada a reinstalar; a proteção dentro do Claude
  Code vem do hook PreToolUse do kit.
- **`CLAUDE.md` com a instrução antiga, já corrigido SEM commit** (commitar na sessão do projeto,
  com R11): Empresa-Milionaria (branch `fase-0-fundacao`), Plexco Tickets (também trocava o caminho
  morto `_Novo_Projeto` por `${env:PERCUS_CANON_DIR}`), huboperacional-site, tiatendo.

Projeto em outra máquina ou criado depois: se `grep` do hook der 0 e existir hook R11, reinstale
copiando o template **sem CR** — veja o item "Hook" do changelog 6.56.0 em `CANON_VERSION.md`.
Hook híbrido (lógica própria depois de `# === PERCUS-MERGED-HOOK END ===`): troque só o bloco entre
os marcadores e mantenha o resto.

## 5. Bloco para colar na sessão do projeto

```
Canon Percus 6.56.1: o R11 mudou (retry + registrar-review; hook lê o conteúdo do marcador).
Leia ${env:PERCUS_CANON_DIR}\docs\handoffs\HANDOFF_CONSUMIDORES_v6.56.md e:
1. rode as duas checagens do item 4 e me diga o resultado;
2. se o CLAUDE.md deste projeto aparece no item 4 como "corrigido SEM commit", revise o diff
   (git diff -- CLAUDE.md) e commite com R11;
3. a partir de agora, quando aparecer __PERCUS_NEEDS_CROSS_CLAUDE__, siga o item 2.
```

## 6. Reverter

- Hook git de um projeto: `mv .git/hooks/pre-commit.bak-2026-09-15 .git/hooks/pre-commit`.
- Lógica do kit (vale para todos os projetos desta máquina): `git revert` dos commits da 6.56.x na
  `main` do `percus-kit`. Enquanto reverte, escape declarado: `PERCUS_HOOKS_DISABLED=1`.
