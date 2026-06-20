---
# Template — Skill de domínio de projeto
# Copiar para: skills/{domain-name}/SKILL.md
# Baseado em: github.com/lucianfialho/gmp-cli (skills/ pattern)
# Ref completo: _Novo_Projeto/comandos/SETUP_PROJECT_SKILLS.md

name: {skill-name}          # kebab-case, único dentro deste projeto
version: 1.0.0
description: "{Uma linha: quando invocar — o que resolve}"
project: {project-slug}     # mesmo slug da audience auth
domain: {auth|ui|api|data|infra|business}
---

# {Nome do Projeto} — {Nome da Skill}

Skill **{domínio}**: {descrição — problema que resolve e quando o agente deve usar
esta skill em vez de improvisar ou usar uma skill genérica do plugin percus-review}.

## Quando usar

- {Situação concreta 1 — o que dispara esta skill}
- {Situação concreta 2}
- Antes de qualquer {operação sensível neste domínio}

## NÃO usar

- Pra {caso fora do escopo desta skill} → use {alternativa: skill X ou percus-review:Y}.
- Se {condição impeditiva — ex: projeto está em modo somente-leitura}.

---

## Contexto crítico do projeto

> Esta seção é o coração da skill: o que o agente PRECISA saber que é
> ESPECÍFICO deste projeto — não inferível do canon nem do código sozinho.

- **Paths chave:** `{caminho/do/módulo/crítico}` — {o que faz}
- **Convenção local:** {ex: "endpoints sempre em `src/api/v2/`, nunca em `v1/`"}
- **Integração externa:** {nome + base URL + método de authn se houver}
- **Gotcha:** {comportamento inesperado que quebraria um agente não avisado}
- **Estado atual:** {o que está em transição / legado / pendente de migração}

---

## Procedimento

### 1. {Primeiro passo}

{O que fazer e como verificar que deu certo.}

```bash
{exemplo de comando — remover bloco se não aplicável}
```

### 2. {Segundo passo}

{Descrição.}

### Verificação

- [ ] {Check 1 — evidência concreta de que funcionou}
- [ ] {Check 2}

---

## Anti-padrões (específicos deste projeto)

- ❌ **{Anti-padrão 1}** — {consequência concreta neste projeto}.
  Fix: {correção}.
- ❌ **{Anti-padrão 2}** — {por que falha aqui mesmo que pareça certo globalmente}.

## Referências

- Canon relevante: `${env:PERCUS_CANON_DIR}/{arquivo}` (seção X)
- Doc local: `docs/{arquivo relevante do projeto}`
- Skill irmã (plugin): `percus-review:{skill-relacionada}`
- Originada de: `HANDOFF.md` entrada de {data} (contexto adicional)
