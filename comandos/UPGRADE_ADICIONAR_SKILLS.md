---
tipo: comando-pronto-para-colar
quando-usar: adicionar estrutura skills/recipes/personas a um projeto Percus JÁ EXISTENTE
leitura: 2 min · execução típica: 20-40 min
ultima-atualizacao: 2026-06-20
fase-destino: 7+ (v6.18.0+)
---

# Upgrade — Adicionar Skills/Recipes/Personas a Projeto Existente

> Adiciona a camada de **skills locais** (padrão gmp-cli adaptado) a um projeto que já tem
> Fase 6/7 mas ainda não tem `skills/`. Não é um upgrade de fase — é uma adição ortogonal
> que pode ser aplicada em qualquer momento sobre Fase 6+.
>
> **Pré-requisitos:**
> - Projeto com `.percus-version >= 6.0.0` (Fase 6 mínima).
> - Plugin `percus-review` instalado na versão canônica atual.
> - Working tree limpa antes de começar.

---

## Cole no chat do Claude Code do projeto-alvo

```
Aplique upgrade de skills locais neste projeto seguindo:
${env:PERCUS_CANON_DIR}/comandos/UPGRADE_ADICIONAR_SKILLS.md

Comece pelo Passo 0 (diagnóstico) e mostre resultado antes de criar qualquer arquivo.
Aguarde minha confirmação antes de avançar.
```

---

## Passos (Claude executa)

### Passo 0 — Diagnóstico

1. Verificar se `skills/` já existe na raiz do projeto:
   - Se existir com conteúdo → listar o que já tem; verificar conformidade com os templates.
   - Se ausente → prosseguir.
2. Ler `HANDOFF.md` e `CLAUDE.md` do projeto pra mapear:
   - Domínios técnicos recorrentes (candidatos a skills de domínio)
   - Workflows compostos repetidos (candidatos a recipes)
   - Papéis de agente distintos usados nas sessões (candidatos a personas)
3. Reportar ao operador:
   - "Skills já existentes: {lista ou nenhuma}"
   - "Candidatos identificados: {lista}"
   - "Proponho criar: {lista de skills/recipes/personas}"
4. Aguardar confirmação do operador antes de criar arquivos.

---

### Passo 1 — Criar estrutura de diretórios

```powershell
New-Item -ItemType Directory -Force skills, skills\recipes, skills\personas
```

```bash
# Unix
mkdir -p skills/recipes skills/personas
```

---

### Passo 2 — Criar skills de domínio

Para cada domínio confirmado no Passo 0:

```powershell
Copy-Item "${env:PERCUS_CANON_DIR}\templates\project-skill.template.md" `
    "skills\{domain-name}\SKILL.md"
```

Preencher o template, especialmente a seção **"Contexto crítico do projeto"** — é o que
diferencia a skill de uma descrição genérica:

- Paths reais dos módulos deste projeto
- Convenções de naming locais (não inferíveis do canon)
- Gotchas descobertos em sessões passadas (checar HANDOFF.md para histórico)
- Estado de qualquer migração em curso

---

### Passo 3 — Criar recipes

Para cada workflow composto confirmado no Passo 0:

```powershell
New-Item -ItemType Directory -Force "skills\recipes\recipe-{workflow}"
Copy-Item "${env:PERCUS_CANON_DIR}\templates\project-recipe.template.md" `
    "skills\recipes\recipe-{workflow}\RECIPE.md"
```

Uma recipe só é válida se tiver os 3 elementos:
- **Critério de avanço** em cada etapa (quando ir pra próxima vs abortar)
- **Abort protocol** explícito
- **Saída esperada** definida (como saber que o recipe completo deu certo)

---

### Passo 4 — Criar personas

Para cada papel de agente confirmado no Passo 0:

```powershell
New-Item -ItemType Directory -Force "skills\personas\persona-{role}"
Copy-Item "${env:PERCUS_CANON_DIR}\templates\project-persona.template.md" `
    "skills\personas\persona-{role}\PERSONA.md"
```

Uma persona só é útil se tiver os 4 elementos:
- **Leitura obrigatória** (lista exata de arquivos, não genérica)
- **Decisões autorizadas** (específicas; nada vago como "decisões técnicas")
- **Escalada obrigatória** (o que vai ao operador — sempre incluir ações externas)
- **Restrições rígidas** (o que esta persona não toca, com `❌`)

---

### Passo 5 — Registrar no `CLAUDE.md` do projeto

Adicionar ao fim do `CLAUDE.md`:

```markdown
## Skills locais do projeto (skills/)

> Complementam o plugin percus-review com conhecimento específico deste projeto.
> Ref: _Novo_Projeto/comandos/SETUP_PROJECT_SKILLS.md

- `skills/{domain}/SKILL.md` — {descrição 1 linha}
- `skills/recipes/recipe-{workflow}/RECIPE.md` — {descrição}
- `skills/personas/persona-{role}/PERSONA.md` — {descrição}
```

---

### Passo 6 — Validação

```powershell
# Verificar estrutura criada
Get-ChildItem skills -Recurse -Filter "*.md" | Select-Object FullName

# Verificar que todos os frontmatters têm name, version, description, project
Select-String -Path skills/**/*.md -Pattern "^name:" | Format-Table -AutoSize
```

Checar manualmente:
- [ ] Cada SKILL.md tem seção "Contexto crítico do projeto" preenchida com dados reais
- [ ] Cada RECIPE.md tem critério de avanço em cada etapa e abort protocol
- [ ] Cada PERSONA.md tem leitura obrigatória com arquivos reais + escaladas definidas
- [ ] `CLAUDE.md` tem seção "Skills locais" atualizada

---

### Passo 7 — Review e commit

```powershell
# Auto-trigger review antes de commitar (R11)
pwsh -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"
```

```bash
git add skills/ CLAUDE.md
git commit -m "feat(skills): adicionar skills/recipes/personas locais (padrão gmp-cli)

- skills/{domain}/SKILL.md — {o que resolve}
- skills/recipes/recipe-{workflow}/RECIPE.md — {o que encadeia}
- skills/personas/persona-{role}/PERSONA.md — {role}

Ref: _Novo_Projeto/comandos/UPGRADE_ADICIONAR_SKILLS.md (v6.18.0)"
```

---

### Passo 8 — Atualizar `HANDOFF.md`

Adicionar entrada:

```markdown
## Skills locais inicializadas — {data}
- skills/{domain}/SKILL.md criada (domínio: {X})
- skills/recipes/recipe-{workflow}/RECIPE.md criada
- skills/personas/persona-{role}/PERSONA.md criada
- CLAUDE.md atualizado com seção "Skills locais"
Próximo: preencher seções de contexto à medida que o projeto evolui.
```

---

## Anti-padrões

- ❌ Criar skill sem a seção "Contexto crítico do projeto" preenchida — skill vazia não ajuda.
- ❌ Duplicar o que `percus-review:auth-consumer`, `security-audit`, `feature-flow` já cobrem.
- ❌ Recipe sem abort protocol — agente fica em estado parcial sem saber o que fazer.
- ❌ Persona sem lista de leitura obrigatória — agente age sem contexto do projeto.
- ❌ Criar skills de um projeto em outro — cada `skills/` pertence ao projeto onde mora.

## Referências

- Guia completo: `${env:PERCUS_CANON_DIR}/comandos/SETUP_PROJECT_SKILLS.md`
- Templates: `${env:PERCUS_CANON_DIR}/templates/project-skill.template.md`
- Templates: `${env:PERCUS_CANON_DIR}/templates/project-recipe.template.md`
- Templates: `${env:PERCUS_CANON_DIR}/templates/project-persona.template.md`
- Referenciado em: `${env:PERCUS_CANON_DIR}/comandos/UPGRADE_PARA_FASE7.md` §8
