---
tipo: comando-pronto-para-colar
fase-introducao: Fase 6
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, 05_FEATURE_TRACKING]
quando-usar: adotar feature-tracking cross-projeto num projeto Percus existente
leitura: 2 min (uso) · execução típica 5-15 min
ultima-atualizacao: 2026-05-15
---

# Comando — Setup do Feature Catalog num Projeto

> **Objetivo:** adicionar `catalog-info.yaml` + `docs/adrs/` a um projeto Percus existente, declarando suas features globais. Após este setup, o Painel de Gestão começa a rastrear a evolução de features cross-projeto.
>
> **Pré-requisitos:** plugin `percus-review` v6.0.0+ instalado.

---

## Cole no chat do Claude Code do projeto-alvo

```
Adotar feature-tracking cross-projeto seguindo `D:\Claud Automations\_Novo_Projeto\comandos\SETUP_CATALOG.md`. Comece pelo Passo 0 (diagnóstico) e mostre o resultado antes de prosseguir.
```

---

## Passos (Claude executa)

### Passo 0 — Diagnóstico

1. Ler `HANDOFF.md` e `docs/PLANO.md` do projeto.
2. Identificar features globais já implementadas (procurar por: `oauth`, `auth`, `tracking`, `lead`, `magic-link`, `affiliate`, `sso`, `rate-limit`, etc.).
3. Listar candidatos de features pro `catalog-info.yaml`.
4. Reportar ao operador:
   - Nome do projeto + slug recomendado.
   - Features candidatas detectadas (com versão inferida do PLANO/HANDOFF).
   - Dependências externas inferidas (auth-service, postgres-vps, etc.).
   - Confirmação: "ok seguir com lista acima?".

**Não avançar sem confirmação.**

### Passo 1 — Criar `catalog-info.yaml` na raiz

Copiar template:
```powershell
Copy-Item "D:\Claud Automations\_Novo_Projeto\templates\catalog-info.yaml.template" "catalog-info.yaml"
```

Preencher com base no Passo 0:
- `metadata.name`: slug do projeto (ex: `painel-gestao`, `plexco-tasks`).
- `metadata.description`: 1 linha.
- `spec.type`: `service` | `library` | `site` | `data`.
- `spec.lifecycle`: `experimental` | `production` | `deprecated`.
- `spec.owner`: `team-percus` (ou GitHub login).
- `spec.system`: agrupador lógico (`vendas`, `auth`, `conteudo`, etc.).
- `spec.features`: lista de features detectadas no Passo 0.
- `spec.dependsOn`: componentes externos (ex: `component:auth-service`, `resource:postgres-vps`).

### Passo 2 — Criar `docs/adrs/0001-percus-feature-tracking-adopted.md`

ADR inaugural registrando que o projeto agora rastreia features cross-projeto.

```powershell
New-Item -ItemType Directory -Path "docs\adrs" -Force | Out-Null
```

Copiar template + preencher:
```powershell
Copy-Item "D:\Claud Automations\_Novo_Projeto\templates\adr-0000-template.md" "docs\adrs\0001-percus-feature-tracking-adopted.md"
```

Conteúdo mínimo:
- Title: "ADR-0001: Adopt Percus feature tracking"
- Status: Accepted
- Date: 2026-05-15 (ou data atual)
- Applied-to: <slug-do-projeto>
- Feature-slug: catalog-info-adoption
- Context, Decision, Consequences: 2-3 linhas cada.

### Passo 3 — Atualizar `.gitignore` (se necessário)

`catalog-info.yaml` e `docs/adrs/` **NÃO** entram em `.gitignore` — fazem parte do repo. Apenas confirmar.

### Passo 4 — Smoke test de ingest no Painel

Rodar manualmente a skill `catalog-publish`:

```
/catalog-publish
```

Esperado:
- Skill detecta `catalog-info.yaml` novo.
- Manda POST pro Painel (`https://gestao.ads4pros.com/admin/catalog/ingest` com `X-Internal-Auth`).
- Painel responde 200 OK.

Verificação visual:
- Abrir `https://gestao.ads4pros.com/gestao/features.html`.
- Buscar pelo slug do projeto na coluna correspondente.
- Confirmar que as features declaradas aparecem.

### Passo 5 — Commit

```bash
git add catalog-info.yaml docs/adrs/0001-percus-feature-tracking-adopted.md
git commit -m "feat(catalog): adopt Percus feature tracking (ADR-0001)"
```

Hook `catalog-publish` (no `on-stop`) também sincroniza automaticamente em sessões futuras.

### Passo 6 — Atualizar HANDOFF

Adicionar em `HANDOFF.md`:

```markdown
## Feature Catalog

Adopted 2026-05-15 (ADR-0001). Features rastreadas no Painel via `catalog-info.yaml`. Atualizar manualmente quando aplicar feature global nova.
```

### Passo 7 — Reportar ao operador

```
[Catalog setup] CONCLUÍDO

Projeto: <slug>
Features declaradas: N
ADRs: 1 (inaugural)
Smoke test: 200 OK do Painel

Próximos passos:
- Quando aplicar feature global nova: atualizar catalog-info.yaml + ADR se decisão polêmica
- Skill catalog-publish empurra automaticamente no on-stop
- Drift detection: /council:drift-detect <feature-slug>
```

---

## Anti-padrões

- ❌ Adicionar feature genérica tipo "tem auth" — slug precisa ser canônico (`oauth-v3`, não `auth`).
- ❌ Pular ADR quando decisão é polêmica — perde rastro pro futuro.
- ❌ Bumpar versão em `catalog-info.yaml` sem mudança real — vira ruído no histórico.

---

## Referências

- Convenção completa: `05_FEATURE_TRACKING.md`
- Template yaml: `templates/catalog-info.yaml.template`
- Template ADR: `templates/adr-0000-template.md`
- Skill: `D:\Claud Automations\.claude-home\plugins\cache\percus-tools\percus-review\6.0.0\skills\catalog-publish\SKILL.md`
- Plano: `D:\Claud Automations\.claude-home\plans\criei-a-pasta-d-claud-warm-patterson.md` (Eixo A)
