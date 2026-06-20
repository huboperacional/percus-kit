---
tipo: comando-e-referência
quando-usar: inicializar estrutura de skills/recipes/personas num projeto Percus (novo OU existente)
leitura: 3 min · execução típica: 20-40 min
ultima-atualizacao: 2026-06-20
fase-destino: 7+ (v6.18.0+)
inspirado-em: github.com/lucianfialho/gmp-cli (skills/ + recipe-* + persona-* pattern)
---

# Setup Project Skills (padrão gmp-cli adaptado)

> **O que é:** adiciona ao projeto uma camada de **skills**, **recipes** e **personas**
> específicas do domínio local. Complementa o plugin `percus-review` (skills *cross-projeto*)
> com conhecimento *deste projeto*: paths reais, convenções locais, anti-padrões descobertos,
> workflows compostos e papéis de agente especializados.
>
> **Por que**: o plugin `percus-review` cobre authn, segurança, tracking, feature-flow — tudo
> genérico. Cada projeto acumula conhecimento local (naming, módulos críticos, integrações
> externas, fluxos compostos) que hoje fica espalhado em HANDOFF.md ou na cabeça do operador.
> Skills locais tornam esse conhecimento invocável pelo agente, reduzindo AskUserQuestion e
> aumentando autonomia segura.
>
> **Inspiração:** [gmp-cli](https://github.com/lucianfialho/gmp-cli) organiza seu conhecimento
> de domínio (Google Marketing APIs) em skills individuais, personas especializadas e recipes
> compostas — o mesmo padrão funciona para qualquer produto Percus.

---

## Estrutura alvo

```
{projeto}/
└── skills/
    ├── {domain-name}/
    │   └── SKILL.md         ← capacidade específica deste domínio
    ├── recipes/
    │   └── recipe-{workflow}/
    │       └── RECIPE.md    ← workflow composto (encadeia N skills)
    └── personas/
        └── persona-{role}/
            └── PERSONA.md   ← agente especializado nesta role
```

Skills locais **nunca duplicam** o que `percus-review` já cobre. São complementares.

---

## Cole isto no chat do Claude Code do projeto-alvo

```
Vou inicializar a estrutura de skills/recipes/personas deste projeto (padrão gmp-cli adaptado,
ref: ${env:PERCUS_CANON_DIR}/comandos/SETUP_PROJECT_SKILLS.md).

OBJETIVO: criar `skills/` com ao menos 1 skill de domínio, 1 recipe e 1 persona que
reflitam o conhecimento LOCAL deste projeto — não o que o plugin percus-review já cobre.

PASSO 0 — Diagnóstico (antes de criar qualquer arquivo):
1. Leia HANDOFF.md e CLAUDE.md pra entender domínio e estado atual.
2. Liste os workflows que se repetem mais neste projeto (pergunte ao operador se não estiver
   claro no HANDOFF.md).
3. Liste os domínios técnicos com conhecimento local não-trivial (integrações externas,
   convenções de naming, módulos críticos).
4. Reporte diagnóstico antes de criar qualquer arquivo. Aguarde confirmação.

PASSO 1 — Estrutura de diretórios:
   mkdir skills
   mkdir skills\recipes
   mkdir skills\personas

PASSO 2 — Skills de domínio (1 por domínio identificado no Passo 0):
   Template: ${env:PERCUS_CANON_DIR}/templates/project-skill.template.md
   Destino:  skills/{domain-name}/SKILL.md

   A seção "Contexto crítico do projeto" é OBRIGATÓRIA e é o que diferencia uma skill local
   de uma descrição genérica. Inclua: paths reais, convenções locais, gotchas descobertos
   na prática, estado de qualquer migração em curso.

   NÃO criar skill para o que percus-review já cobre (auth-consumer, security-audit,
   feature-flow, tracking-audit, cookie-audit, port-allocate, pages-scan).

PASSO 3 — Recipes (1 por workflow composto identificado no Passo 0):
   Template: ${env:PERCUS_CANON_DIR}/templates/project-recipe.template.md
   Destino:  skills/recipes/recipe-{workflow}/RECIPE.md

   Uma recipe precisa ter: ordem obrigatória entre etapas + critério de avanço em cada
   uma + abort protocol. Sem esses 3 elementos não é recipe — é só um checklist.

PASSO 4 — Personas (1 por papel de agente identificado):
   Template: ${env:PERCUS_CANON_DIR}/templates/project-persona.template.md
   Destino:  skills/personas/persona-{role}/PERSONA.md

   Uma persona precisa ter: leitura obrigatória + decisões autorizadas + escaladas
   obrigatórias + restrições rígidas. Sem esses 4 elementos a persona é ambígua.

PASSO 5 — Registrar no CLAUDE.md do projeto:
   Adicionar seção:

   ## Skills locais do projeto (skills/)
   > Complementam o plugin percus-review com conhecimento específico deste projeto.
   > Ref: _Novo_Projeto/comandos/SETUP_PROJECT_SKILLS.md
   - `skills/{domain}/SKILL.md` — {descrição 1 linha}
   - `skills/recipes/recipe-{workflow}/RECIPE.md` — {descrição}
   - `skills/personas/persona-{role}/PERSONA.md` — {descrição}

PASSO 6 — Validação e commit:
   - Rodar /percus-review:review no diff.
   - Commitar: git add skills/ CLAUDE.md; commit com msg
     "feat(skills): inicializar skills/recipes/personas do projeto (padrão gmp-cli)"

REGRAS DE QUALIDADE:
- Mínimo viável: 1 skill + 1 recipe + 1 persona. Esqueleto preenchido com dados reais
  é melhor que arquivo perfeito vazio.
- Skills obsoletas → mover pra skills/_archive/ (não deletar; manter history no git).
- Se uma skill local crescer e se tornar útil cross-projeto: propor absorção pro
  plugin percus-review via caixa de texto pro operador colar no canal de canon.
```

---

## Referência detalhada por tipo

### Skills de domínio (`skills/{domain}/SKILL.md`)

Cobrem **capacidades específicas** que o agente precisa exercer repetidamente neste projeto.

**Bons candidatos:**
- Integração com API externa específica do produto (ex: `erp-connector`, `payment-gateway`)
- Auth flows além do padrão (ex: `step-up-totp`, `invite-flow-custom`)
- Domínio de negócio complexo (ex: `pricing-rules`, `multi-tenant-resolution`)
- Convenção de scaffold do projeto (ex: `new-endpoint-pattern`, `new-migration-pattern`)

**NÃO criar skill para:**
- O que `auth-consumer`, `security-audit`, `feature-flow`, `tracking-audit` já cobrem.
- Instruções genéricas que cabem melhor no `CLAUDE.md` do projeto.
- Procedimentos one-shot (escreva no HANDOFF.md; skill é para repetição).

**Template:** `D:\Claud Automations\_Novo_Projeto\templates\project-skill.template.md`

---

### Recipes (`skills/recipes/recipe-{workflow}/RECIPE.md`)

Encadeiam N skills/operações em sequência determinística com critérios explícitos de avanço.
A diferença entre recipe e checklist: recipe tem **ordem obrigatória** + **abort protocol**.

**Bons candidatos para projetos Percus:**

| Recipe | Encadeia |
|---|---|
| `recipe-nova-feature` | scope-council → scaffold → implement → tracking-audit → review → PR |
| `recipe-auth-compliance` | auth-consumer checklist → security-audit → report ao operador |
| `recipe-onboarding-usuario` | provisionar identidade → criar org → welcome OTP |
| `recipe-deploy-staging` | build → tests → tracking-audit → pages-scan → push → smoke E2E |
| `recipe-milestone-close` | close-milestone → HANDOFF update → catalog-publish |

**Template:** `D:\Claud Automations\_Novo_Projeto\templates\project-recipe.template.md`

---

### Personas (`skills/personas/persona-{role}/PERSONA.md`)

Definem **papéis especializados** que o agente pode assumir — resolve o problema de "o agente
não sabe onde termina sua responsabilidade e começa a do operador ou de outra persona".

**Personas típicas de um projeto Percus:**

| Persona | Foco | NÃO toca |
|---|---|---|
| `persona-feature-implementor` | CRUD, feature-flow, tracking, testes | Segurança, infra, deploy |
| `persona-security-auditor` | auth-consumer, security-audit, cookie-audit | Código de negócio |
| `persona-integration-specialist` | APIs externas, contratos B.x, webhooks | UI, infra |
| `persona-infra-operator` | VPS, Traefik, deploys, env vars | Código de negócio |

Uma boa persona tem 4 elementos obrigatórios: **leitura obrigatória** (o que ler antes de agir) +
**decisões autorizadas** (o que pode decidir sozinho) + **escalada obrigatória** (o que vai ao
operador) + **restrições rígidas** (o que não toca).

**Template:** `D:\Claud Automations\_Novo_Projeto\templates\project-persona.template.md`

---

## Exemplo mínimo real (projeto SaaS B2B)

```
skills/
├── erp-connector/
│   └── SKILL.md           ← API legada do ERP: authn, rate limits, retry, mapeamento de campos
├── recipes/
│   └── recipe-nova-feature/
│       └── RECIPE.md      ← scope-council → scaffold → implement → review → PR
└── personas/
    └── persona-feature-implementor/
        └── PERSONA.md     ← foco em feature-flow + tracking; escala segurança pro auditor
```

## Versionamento

- `version:` no frontmatter segue SemVer simples. Bump patch a cada correção; minor a cada
  nova seção; major quando o domínio da skill muda fundamentalmente.
- Usar `git log -- skills/{skill}/SKILL.md` para rastrear evolução.

## Integração com o plugin percus-review

Skills locais e skills do plugin são complementares:

| Plugin percus-review (cross-projeto) | Skills locais (deste projeto) |
|---|---|
| `auth-consumer` — auditoria de integração auth | `auth-{product-name}` — convenções locais de auth |
| `security-audit` — R14-R19 | `{product}-security` — gotchas específicos do produto |
| `feature-flow` — [0]→[5-T] genérico | `recipe-nova-feature` — fluxo com scaffold específico |
| `tracking-audit` — 15 campos UTM | (raramente precisa de skill local) |

## Referências

- Inspiração: https://github.com/lucianfialho/gmp-cli (skills/ com recipe-*, persona-* pattern)
- Templates: `D:\Claud Automations\_Novo_Projeto\templates\project-skill.template.md`
- Templates: `D:\Claud Automations\_Novo_Projeto\templates\project-recipe.template.md`
- Templates: `D:\Claud Automations\_Novo_Projeto\templates\project-persona.template.md`
- Projeto novo: `D:\Claud Automations\_Novo_Projeto\comandos\COMANDO_PROJETO_NOVO.md` (passo 2.7)
- Upgrade existentes: `D:\Claud Automations\_Novo_Projeto\comandos\UPGRADE_ADICIONAR_SKILLS.md`
- Plugin skills: `D:\Claud Automations\_Novo_Projeto\plugin\percus-review\skills\`
