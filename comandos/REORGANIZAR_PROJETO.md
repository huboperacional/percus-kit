---
tipo: comando-pronto-para-colar
quando-usar: PONTO DE ENTRADA para atualizar/organizar um projeto Percus existente pro canon ATUAL — tracking files + diretivas vigentes + versão
nao-toca-codigo: true
leitura: 4 min · execução típica: 15-40 min (adoção incremental de diretivas: ~5 min, ver seção Delta)
ultima-atualizacao: 2026-07-10
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
- Checkpoint: rodar a skill `checkpoint` (linguagem natural, não slash) ao fim de milestone (PreCompact é backstop).
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

## Atualização incremental de diretivas (delta) {#delta-diretivas}

> Para projeto **já no canon** que só precisa **adotar as diretivas-doc que mudaram** desde a última
> atualização — **sem** rerodar o diagnóstico completo (Passos 0-5). É a caixa **leve** (~5 min).
>
> **Só diretiva/doc, nunca plugin.** O republish do tooling foi descartado: os projetos seguem lendo o
> plugin instalado. Esta caixa entrega **DIRETIVAS/docs** (que moram no canon e o projeto **referencia**
> via `${env:PERCUS_CANON_DIR}`), jamais tooling executável novo. Diretiva nova = **opt-in por definição**:
> o projeto avalia e adota se fizer sentido; não é obrigatória.

**Pré-requisito (1x na máquina):** `cd "$env:PERCUS_CANON_DIR"; git pull` — entrega os docs ao vivo a todos os projetos.

### Cole isto no chat do Claude Code do projeto-alvo

```
Adote as diretivas-doc que mudaram no canon Percus desde a minha última atualização.
Não toque em código de negócio. É opt-in: só DIRETIVA/doc, sem plugin novo. Confirme comigo (R5) antes de qualquer commit.

PASSO A — Delta de versão (mostre antes de mudar nada):
1. Leia `.percus-version` na raiz (versão adotada hoje; ausente = pré-Fase-6).
2. Leia as 5 primeiras linhas de ${env:PERCUS_CANON_DIR}/CANON_VERSION.md (versão corrente).
3. Reporte o delta. Se estiver muito atrás (sem plugin/tracking files), PARE e use o umbrella completo
   (Passos 0-5) — esta caixa é só pra adotar o delta de diretivas, não pra reorganizar do zero.

PASSO B — Diretiva project-facing nova: deploy opt-in (build Docker frio/lento em Next.js):
- Aplica SE este projeto é Next.js deployado como imagem Docker cujo `next build` refaz do zero a cada deploy.
- Se aplica: leia ${env:PERCUS_CANON_DIR}/conhecimento/COMO_FAZER.md#deploy-build-cache e avalie adotar —
  fontes self-hosted (`next/font/google` → `next/font/local`, mesmos `variable`/`display`) + cache
  incremental BuildKit no Dockerfile. É ADITIVO, não muda a base/convenção. **Pilote antes de canonizar:**
  rode o passo 4 de validação (typecheck + build local passam, fontes renderizam iguais) NESTE projeto
  antes de tratar como padrão. Não altere lógica de página — só fontes + Dockerfile.
- Se NÃO aplica (não é Next.js, ou não é Docker, ou o build já é rápido): registre "N/A — motivo" e siga.

PASSO B2 — Diretivas de AUTONOMIA (v6.29.0) — aplica a TODO projeto:
- O canon agora manda o agente RESOLVER O MÁXIMO SEM PERGUNTAR (menos confirmação boba): review/conselho/
  testes/build rodam sozinhos; conselho automático ao finalizar spec/plano; paralelismo é o default;
  lixo AUTO-CRIADO limpa sem perguntar; deploy/mutação-de-prod é autônomo (autorização durável); confirmar
  só destruição irreversível de dados, e como pergunta BINÁRIA (nunca menu a/b/c).
- Adotar: copie a seção "## Autonomia" de ${env:PERCUS_CANON_DIR}/templates/CLAUDE.template.md pro CLAUDE.md
  DESTE projeto (MESCLE, não sobrescreva). As regras-fonte vivem em 01_REGRAS (R5/R9/R11) + 06_CONSELHO — o
  projeto já as referencia via ${env:PERCUS_CANON_DIR}; esta adoção só reflete a diretiva no CLAUDE.md local.

PASSO B3 — Canon V2: roteador de loops + gate mecânico (v6.30.0) — aplica a TODO projeto:
- O canon ganhou o núcleo V2 em ${env:PERCUS_CANON_DIR}/v2/ (Constituição + 8 loops + gates).
  Procedimento sai do CLAUDE.md e passa a ser roteado por situação (tabela "Roteador de loops").
- Adotar (2 passos):
  a) copie a seção "## Roteador de loops" de ${env:PERCUS_CANON_DIR}/templates/CLAUDE.template.md
     pro CLAUDE.md DESTE projeto (MESCLE, não sobrescreva);
  b) instale o gate: defina PERCUS_CANON_V2_DIR=${env:PERCUS_CANON_DIR}/v2 (setx, durável) e rode
     `sh "$PERCUS_CANON_V2_DIR/gates/instalar-gates.sh"` na raiz do projeto (híbrido: preserva
     hook existente; escape: PERCUS_GATE_OVERSIZE="motivo").
- HANDOFF acima do teto (150) na primeira rodada é ESPERADO em projeto antigo: compacte no
  formato ${env:PERCUS_CANON_DIR}/v2/artefatos/HANDOFF-FORMAT.md (histórico → docs/historico/,
  consulta → docs/referencia-operacional.md). Referência de execução: tiatendo `70c9347`.

PASSO C — Higiene interna do canon (informativo — NADA a adotar no projeto):
- cascata aposentada, R-count vira ponteiro (R25), soaks fechados, parity .sh como gap aceito: são mudanças
  INTERNAS do canon/tooling, não diretivas que o projeto "adota". Só fique ciente; nenhuma ação no projeto.

PASSO D — Bump da versão adotada:
- Se adotou/pilotou a diretiva do Passo B: atualize `.percus-version` pra versão corrente do CANON_VERSION.md.
- Se tudo ficou N/A (nada aplicável a este projeto): NÃO bumpe — registre no HANDOFF "diretivas revisadas
  {data}, delta N/A pra este projeto".

PASSO E — Report: o que foi adotado, o que ficou N/A (com motivo), próximo passo. Sem commit sem meu OK explícito.
```

> **Quando usar esta caixa vs. o umbrella completo:** projeto já no canon e você só quer propagar o que
> mudou → esta caixa (Delta). Projeto sem tracking files / sem plugin / muitas versões atrás → Passos 0-5.

---

## Rota por estado (o umbrella decide; estes são sub-passos específicos)

| Estado do projeto | Sub-rota |
|---|---|
| Sem tracking files (CLAUDE/HANDOFF/PLANO) | Passo 1 acima |
| Legado sem plugin/review | `comandos/UPGRADE_PROJETO_FASE2.md` (baseline Fase 4) |
| Já Fase 4/5, falta conselho 3-membros + catalog | `comandos/UPGRADE_PARA_FASE6.md` |
| Fase 6, falta auth canonizado v6.8 | `comandos/UPGRADE_PARA_FASE7.md` |
| Tem o básico, falta só adotar diretivas novas | Seção **Delta** (`#delta-diretivas`) — caixa leve incremental |
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
