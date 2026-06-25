---
tipo: comando-pronto-para-colar
quando-usar: sincronizar um projeto Percus existente com a versão canônica ATUAL e adotar as diretivas vigentes
leitura: 2 min · execução típica: 15-30 min
ultima-atualizacao: 2026-06-25
version-agnostic: true (sempre sincroniza pra versão corrente em CANON_VERSION.md)
---

# Upgrade — Sincronizar Projeto com o Canon Atual + Adotar Diretivas Vigentes

> **Este é o arquivo que o operador envia/cola pra cada projeto** quando o canon ganha diretivas novas.
> É **version-agnostic**: sempre alinha o projeto com o que está em `CANON_VERSION.md` na hora, em vez
> de fixar uma versão. Mecanismo cross-repo: o operador **cola o bloco abaixo** no chat do projeto
> (o canon nunca escreve em outro repo).

---

## Pré-requisitos na máquina (fazer 1x, serve pra todos os projetos da máquina)

1. **Atualizar o clone do canon** (os projetos leem os docs ao vivo via `${env:PERCUS_CANON_DIR}`):
   ```bash
   cd "$env:PERCUS_CANON_DIR"; git pull
   ```
   Um pull aqui já entrega R23/R24, gate `[S]`, política de deploy e base de conhecimento a **todos**
   os projetos da máquina (eles referenciam o canon, não copiam).

2. **Atualizar o plugin `percus-review`** (pra receber o tooling novo: `spec-analyze`, skills
   `consult-knowledge`/`checkpoint`, hook `PreCompact`):
   UI "Manage plugins" → Update `percus-tools` → Reinstall `percus-review` → Reload Window.
   > ⚠️ Se o marketplace ainda não publicou a versão do `plugin.json` atual, o tooling novo não aparece
   > até a republicação. Os **docs/diretivas** (passo 1) independem disso.

---

## Cole isto no chat do Claude Code do projeto-alvo

```
Sincronize este projeto com a versão canônica ATUAL do Percus e adote as diretivas vigentes.

PASSO 0 — Diagnóstico (mostre antes de mudar nada):
1. Leia `.percus-version` na raiz (versão adotada hoje).
2. Leia as 5 primeiras linhas de `${env:PERCUS_CANON_DIR}/CANON_VERSION.md` (versão corrente).
3. Declare o delta: "Projeto em X.Y.Z; canon atual em A.B.C. Diretivas a adotar: <lista>."
4. Aguarde minha confirmação antes de executar os passos.

PASSO 1 — Adotar as diretivas vigentes (ler a fonte e aplicar ao projeto):
Leia `${env:PERCUS_CANON_DIR}/CANON_VERSION.md` (changelog) e, para cada item abaixo que o projeto
ainda não segue, aplique:

- **Gate [S] — spec antes de implementar feature não-trivial:** feature que toca schema+endpoint+UI
  (ou pasta sensível) passa por `spec.md` (template do canon) + `/clarify` (≤5 perguntas) +
  `/percus-review:spec-analyze` ANTES de virar `[0]`. Feature trivial usa mini-spec. Ver canon
  `06_CONSELHO_PERCUS.md` Modo 5 + `plugin/.../skills/feature-flow`.
- **R23 — base de conhecimento:** antes de debugar problema que parece conhecido, consultar
  `${env:PERCUS_CANON_DIR}/conhecimento/COMO_RESOLVER.md` (skill `percus-review:consult-knowledge`);
  registrar solução nova após resolver. Idem `COMO_FAZER.md` pra procedimentos.
- **R24 — cadência de deploy:** deploy ao fim de milestone / fim do dia / sob demanda, NÃO a cada
  feature. Playbook `${env:PERCUS_CANON_DIR}/comandos/DEPLOY.md` (smoke + rollback obrigatórios).
- **Checkpoint de contexto:** rodar a skill `percus-review:checkpoint` ao fim de cada milestone
  (sincroniza PLANO+HANDOFF+mock-audit, emite prompt de retomada). Hook PreCompact é backstop.
- **Skills/recipes/personas locais (se ainda não tem):** rodar
  `${env:PERCUS_CANON_DIR}/comandos/UPGRADE_ADICIONAR_SKILLS.md`.
- **Auth — sessão durável (#rt=):** se o projeto consome o auth-service, auditar via
  `percus-review:auth-consumer` que o bridge lê `#rt=` e chama `/otp/refresh` (não só `#at=`).
- **(Opcional) Frentes paralelas:** se houver 2-4 frentes independentes, ver
  `${env:PERCUS_CANON_DIR}/comandos/COMANDO_FRENTES_PARALELAS.md`.

PASSO 2 — Bump da versão adotada:
Atualize `.percus-version` na raiz com a versão corrente do canon (mesma do `CANON_VERSION.md`).

PASSO 3 — Verificação:
- `/percus-review:review` num diff de teste retorna findings (plugin atualizado).
- Se o projeto consome auth: rodar `percus-review:auth-consumer` (checklist + C1-C8).
- Reportar o que foi adotado e o que ficou pendente (com motivo).

Não toque em código de negócio neste turno além do necessário pra adotar as diretivas. Confirme comigo
antes de qualquer commit (R5).
```

---

## Por que não há "um arquivo de diretivas" para copiar pro projeto

As diretivas **moram no canon** (`01_REGRAS`, `02_INFRA`, `06_CONSELHO`, `comandos/`, `conhecimento/`)
e os projetos as leem ao vivo via `${env:PERCUS_CANON_DIR}`. Copiar conteúdo pra dentro do projeto criaria
drift (o cross-repo write protocol proíbe isso). O que se "envia" é **este comando** — ele faz o projeto
ler a fonte e se alinhar. Para detalhes de uma diretiva específica, o projeto abre o doc canônico citado.

## Referências

- Changelog corrente: `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`
- Skills locais: `comandos/UPGRADE_ADICIONAR_SKILLS.md`
- Roteamento: `00_LEIA_PRIMEIRO.md`
- Protocolo cross-repo: `conhecimento/COMO_RESOLVER.md#cross-repo-write`
