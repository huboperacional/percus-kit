---
tipo: checklist-imperativo
quando-usar: SEMPRE ao encerrar qualquer sessão (mesmo curta, mesmo parcial)
leitura: 1 min
ultima-atualizacao: 2026-04-25
---

# CHECKLIST — Encerrar Sessão

> **Sessão sem este checklist é débito técnico de contexto.**
> Atualizar `HANDOFF.md` é tão importante quanto o código que você acabou de escrever.

---

## Passo 1 — Sincronizar `docs/PLANO.md`

Para cada feature que você tocou nesta sessão:
- ✅ Status reflete realidade verificável (R2 do `01_REGRAS_INEGOCIAVEIS.md`)
- ❌ Se você "ia atualizar depois" — atualize agora.

**Não arredonde para cima.** Se está em `[3-H]` mas não testou ciclo, deixa em `[3-H]`.

## Passo 2 — Atualizar `HANDOFF.md`

Use `templates/HANDOFF.template.md` como base se não existir.

Campos obrigatórios:
- **O que está funcionando end-to-end** (lista das `[5-T]` confirmadas nesta sessão)
- **O que é só UI / mock** (lista das `[4-C]` ou abaixo com componente)
- **O que está quebrado** (qualquer regressão detectada)
- **Último passo concluído** — descrição exata
- **Próximo passo imediato** — sem ambiguidade ("rodar `alembic upgrade head` no DB X" e não "continuar feature Y")
- **Tabela de status** — espelho do PLANO

## Passo 3 — Atualizar `docs/mock-audit.md` (se projeto tem frontend)

Para cada tela tocada:
- Tela virou ✅ real? Mova de ⚠️/❌ para ✅
- Tela continua mock mas você adicionou banner MODO DEMO? Anote.
- Tela nova foi criada como ❌ só UI? Adicione com esforço estimado.

## Passo 4 — Mensagem de gate para si mesmo

Pergunte literalmente:

> "Se eu fechar tudo agora e voltar amanhã sem memória nenhuma desta conversa, consigo retomar o trabalho lendo só HANDOFF.md, PLANO.md e mock-audit.md?"

Se a resposta é "talvez" ou "depende": handoff incompleto. Volte e adicione o que falta.

## Passo 5 — Commit (se houver mudanças de código)

Antes de `git commit`:
- ✅ Cobertura de R1 (`[5-T]`) confirmada para o que mudou
- ✅ HANDOFF e PLANO atualizados (passos 1-2 acima)
- ✅ **`/percus-review:review` rodado nos últimos 5 minutos** (R11 — OBRIGATÓRIO em commits de código)
  - Findings de bugs ou violações de regras Percus tratados
  - Findings de preferência de estilo declarados em voz alta se ignorados
- ✅ Code review extra do Claude Code se diff > 500 linhas ou mexeu em auth/segurança
- ✅ `mock-audit.md` atualizado (se frontend)

Mensagem de commit deve referenciar o status atualizado. Ex:
```
feat(produtos): cadastro persiste no banco — produtos: [4-C] → [5-T]
```

## Passo 6 — Reportar ao usuário

Mensagem final de uma sessão deve ter este formato:

```
SESSÃO ENCERRADA — {projeto}

Feito nesta sessão:
- {lista curta do que avançou de status}

Status atualizado:
- [5-T] {features confirmadas}
- [4-C] {features componente pronto, ciclo pendente}
- {outros relevantes}

Próximo passo (já no HANDOFF):
- {descrição literal}

Bloqueios / itens que precisam de você:
- {lista, ou "nenhum"}
```

---

## Anti-padrões

- ❌ Encerrar com "vou atualizar handoff amanhã antes de começar". Não. Agora.
- ❌ Marcar `[5-T]` no PLANO porque "deu certo no postman".
- ❌ Esquecer de atualizar mock-audit em sessão de frontend.
- ❌ Mensagem final de "ok, terminei" sem o bloco estruturado acima.
- ❌ Commit com mensagem genérica ("update files") quando mudou status de feature.
- ❌ Commitar sem `/percus-review:review` rodado antes (R11).
