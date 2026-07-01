---
tipo: comando-pronto-para-colar
quando-usar: PONTO DE ENTRADA para atualizar/organizar um projeto Percus existente pro canon ATUAL — tracking files + diretivas vigentes + versão
nao-toca-codigo: true
leitura: 4 min · execução típica: 15-40 min
ultima-atualizacao: 2026-06-26
version-agnostic: true (sempre alinha pra versão corrente em CANON_VERSION.md)
---

# Reorganizar / Atualizar Projeto Existente (umbrella)

> **Este é o ÚNICO ponto de entrada** para trazer um projeto Percus existente ao estado canônico atual.
> Ele diagnostica o que falta e **roteia** para os docs focados — não duplica `SETUP_*`/`MIGRAR_AUTH`/skills.
> É **version-agnostic**: alinha sempre pra versão que estiver em `CANON_VERSION.md` na hora.
>
> **Mecanismo cross-repo:** o operador **cola o bloco abaixo** no chat do projeto. O canon nunca escreve
> em outro repo; as diretivas moram no canon e o projeto as referencia via `${env:PERCUS_CANON_DIR}`.

---

## Pré-requisitos na máquina (1x, vale pra todos os projetos da máquina)

1. **Atualizar o clone do canon** (os projetos leem os docs ao vivo): `cd "$env:PERCUS_CANON_DIR"; git pull`.
   Isso já entrega as diretivas-doc (regras, políticas, base de conhecimento) a todos os projetos.
2. **Atualizar o plugin `percus-review`** (pra receber o tooling: `spec-analyze`, `consult-knowledge`,
   `checkpoint`, hook `PreCompact`): UI "Manage plugins" → Update `percus-tools` → Reinstall → Reload.
   > Se o marketplace ainda não publicou a versão do `plugin.json` atual, o tooling novo só aparece após
   > a republicação. Os docs/diretivas (passo 1) independem disso.

---

## Cole isto no chat do Claude Code do projeto-alvo

```
Atualize/organize este projeto pro canon Percus ATUAL seguindo o umbrella REORGANIZAR_PROJETO.
Não toque em código de negócio. Confirme comigo (R5) antes de qualquer commit.

PASSO 0 — Diagnóstico (mostre antes de mudar nada; aguarde confirmação):
1. Leia `.percus-version` na raiz (versão adotada hoje; ausente = pré-Fase-6).
2. Leia as 5 primeiras linhas de ${env:PERCUS_CANON_DIR}/CANON_VERSION.md (versão corrente).
3. Cheque o que existe: CLAUDE.md, AGENTS.md (GEMINI.md se espelho-3), HANDOFF.md, docs/PLANO.md,
   docs/mock-audit.md, .percus-version, plugin @percus/review instalado, DEEPSEEK_API_KEY no .env,
   skills/ local, catalog-info.yaml.
4. Declare a matriz "tem / falta" + o delta de versão + o plano. Aguarde minha confirmação.

PASSO 1 — Tracking files no padrão atual (criar/atualizar, NUNCA sobrescrever — mesclar):
Use os templates do canon como referência (não inline, não invente):
- CLAUDE.md  ← ${env:PERCUS_CANON_DIR}/templates/CLAUDE.template.md
- AGENTS.md  ← ${env:PERCUS_CANON_DIR}/templates/AGENTS.template.md  (+ GEMINI.md se Test-Path GEMINI.md)
- HANDOFF.md ← ${env:PERCUS_CANON_DIR}/templates/HANDOFF.template.md
- docs/PLANO.md ← ${env:PERCUS_CANON_DIR}/templates/PLANO.template.md  (classifique cada feature [0]→[5-T] pelo estado REAL; não arredonde pra cima)
- docs/mock-audit.md ← ${env:PERCUS_CANON_DIR}/templates/mock-audit.template.md (grep mocks antes de preencher)
- .gitignore ← garantir .deepseek/ (base em templates/.gitignore.example)

PASSO 2 — Adotar as diretivas vigentes (ler a fonte no canon e aplicar o que faltar):
- R10/R11/R13 (baseline Fase 4): design v0/shadcn; review cross-provider antes de commit E no marco;
  routing Claude/DeepSeek/revisores. Ver 01_REGRAS + 04_MODEL_ROUTING.
- Gate [S]: feature não-trivial → spec.md (template) + /clarify (≤5) + /percus-review:spec-analyze ANTES de [0]. (06_CONSELHO Modo 5)
- R23: consultar ${env:PERCUS_CANON_DIR}/conhecimento/COMO_RESOLVER.md antes de debugar; registrar após (skill consult-knowledge).
- R24: deploy ao milestone/fim-do-dia/sob-demanda, NÃO per-feature (comandos/DEPLOY.md, smoke+rollback).
- Checkpoint: rodar skill percus-review:checkpoint ao fim de milestone (PreCompact é backstop).
- Auth (se consome auth-service): auditar via percus-review:auth-consumer (bridge lê #rt=, não só #at=).

PASSO 3 — Rotear pros setups focados SÓ no que faltar (não duplicar aqui):
- Plugin/review ausente → comandos/UPGRADE_PROJETO_FASE2.md (baseline Fase 4 completa)
  OU comandos/SETUP_REVIEW_ROUTING.md (só o reviewer).
- DeepSeek implementador ausente → comandos/SETUP_DEEPSEEK.md.
- .claude/settings.json fora do padrão → comandos/SETUP_CLAUDE_SETTINGS.md.
- Sem skills/recipes/personas locais → comandos/UPGRADE_ADICIONAR_SKILLS.md.
- Sem catalog-info.yaml → comandos/SETUP_CATALOG.md.
- Auth legado (Supabase/GoTrue/NextAuth/senha) → comandos/MIGRAR_AUTH.md.

PASSO 4 — Bump da versão adotada:
Atualize .percus-version na raiz com a versão corrente do canon (mesma do CANON_VERSION.md).

PASSO 5 — Verificação + report:
- /percus-review:review num diff de teste retorna findings (plugin ok).
- Se consome auth: rodar percus-review:auth-consumer (checklist + C1-C8).
- Reporte: matriz do que foi adotado, o que ficou pendente (com motivo), e o próximo passo.
```

---

## Rota por estado (o umbrella decide; estes são sub-passos específicos)

| Estado do projeto | Sub-rota |
|---|---|
| Sem tracking files (CLAUDE/HANDOFF/PLANO) | Passo 1 acima |
| Legado sem plugin/review | `comandos/UPGRADE_PROJETO_FASE2.md` (baseline Fase 4) |
| Já Fase 4/5, falta conselho 3-membros + catalog | `comandos/UPGRADE_PARA_FASE6.md` |
| Fase 6, falta auth canonizado v6.8 | `comandos/UPGRADE_PARA_FASE7.md` |
| Tem o básico, falta só adotar diretivas novas | Passo 2 acima |
| Auditar se a Fase 4 está mesmo em uso | `comandos/HEALTHCHECK_FASE2.md` |

> Os `UPGRADE_PARA_FASE*` são **rotas históricas específicas por fase**. Para "trazer ao canon atual"
> de forma geral, este umbrella (Passos 0-5) é o caminho — ele cobre qualquer ponto de partida.

---

## Anti-padrões

- ❌ Sobrescrever CLAUDE.md/AGENTS.md em vez de mesclar — perde contexto específico do projeto.
- ❌ Marcar `[5-T]` no PLANO sem ter testado o ciclo CRUD nesta sessão.
- ❌ Copiar diretivas pra dentro do projeto — elas moram no canon, o projeto referencia (cross-repo).
- ❌ Pular o Passo 0 (diagnóstico) — duplica trabalho ou quebra o que já funciona.
- ❌ Espelho-3 ativo (GEMINI.md presente) e mesclar só em CLAUDE.md/AGENTS.md — quebra invariante do projeto.

## Referências

- Templates: `${env:PERCUS_CANON_DIR}/templates/` (CLAUDE/AGENTS/HANDOFF/PLANO/mock-audit/spec).
- Diretivas: `01_REGRAS_INEGOCIAVEIS.md`, `06_CONSELHO_PERCUS.md` (modos), `comandos/DEPLOY.md` (R24).
- Setups focados: `SETUP_REVIEW_ROUTING`, `SETUP_DEEPSEEK`, `SETUP_CLAUDE_SETTINGS`, `UPGRADE_ADICIONAR_SKILLS`, `SETUP_CATALOG`, `MIGRAR_AUTH`.
- Roteamento mestre: `00_LEIA_PRIMEIRO.md`.
