# Auditoria pos-entrega Eixo F — 2026-05-17

Validacoes operacionais rodadas apos push da v6.3.0. Complementa
`_AUDIT_2026-05-17_eixo-f.md` (auditoria F-4 das frentes pequenas).

---

## 1. F.2 router — Validacao A/B real (Pendencia #1)

**Status:** ✅ APROVADO. Haiku 4.5 como default em `consult` mantem qualidade.

**Prompt teste:** decisao sobre renomear `users.name` → `users.full_name` em schema com 5 consumidores (cenario realista de `consult` mode — pergunta tecnica, decisao reversivel, risco operacional).

**Comparacao Sonnet 4.6 (baseline) vs Haiku 4.5 (novo default):**

| Metrica | Sonnet 4.6 | Haiku 4.5 | Delta |
|---|---|---|---|
| Decisao | "Nao renomeie, faca alias primeiro" | "NAO renomeie agora" | **mesma** |
| Risco principal identificado | Breakage silencioso em runtime | Quebra em cascata nos 5 servicos | **mesmo conceito** |
| Alternativa proposta | Alias + deprecate paralelo | Coluna nova + alias 2-3 sprints | **equivalentes** |
| Insight extra | "Divida tecnica subestimada" | (sem insight extra, mais estruturado em bullets) | empate |
| Tokens in | 113 | 112 | -1% |
| Tokens out | 220 | 198 | -10% |
| Latencia | 6479 ms | 3662 ms | **-44%** |
| Custo estimado | $0.00363 | $0.00110 | **-70%** |

**Veredito:** Haiku entrega qualidade equivalente com 70% menos custo e 44% menos latencia.
Default mantido: `consult` → Haiku 4.5.

**Caveat:** 1 prompt validado. Pra reforco estatistico, rodar mais 2-3 prompts representativos
de `consult` em sessoes futuras e confirmar. Se algum cair de qualidade, override pra Sonnet:
`-CrossClaudeModel claude-sonnet-4-6`.

---

## 2. F.1 prompt cache — Finding tecnico (Pendencia #2)

**Status:** ❌ CACHE NAO DISPARA NA CONFIG ATUAL. Codigo do wrapper funciona, mas Anthropic
prompt cache tem **minimo de 1024 tokens** pro bloco cacheado (Haiku/Sonnet) ou **2048**
(Opus). Nosso SystemPrompt por mode tem ~30-60 tokens:

- `consult`: "Voce e consultor cross-provider Percus. Responda em <=150 palavras: 1) sua escolha/posicao, 2) razao principal, 3) maior risco da alternativa. Sem floreio." (~40 tokens)
- `pre-mortem`: ~50 tokens
- `review`: ~60 tokens

**Smoke real (com ANTHROPIC_API_KEY no .env):**

```
Call 1 (cache miss esperado):
  cache_creation_input_tokens: 0  ← NAO criou cache (system prompt < 1024 tokens)
  cache_read_input_tokens: 0
  prompt_tokens: 57

Call 2 (em <5min, cache hit esperado):
  cache_creation_input_tokens: 0
  cache_read_input_tokens: 0  ← sem hit
  prompt_tokens: 57
```

**Conclusao:** wrapper esta correto, mas F.1 nao economiza nada na pratica enquanto SystemPrompt
for tao curto.

**3 caminhos pra ativar F.1:**

| Opcao | Como | Trade-off |
|---|---|---|
| **A. Engordar SystemPrompt** com contexto fixo Percus (regras R1-R19 resumidas, glosario, exemplos) pra passar de 1024 tokens | Editar `$SystemPrompt` switch no orchestrator | Sobe qualidade do conselho (mais contexto) + ativa cache. Custo: SystemPrompt grande gasta tokens em todas chamadas iniciais. |
| **B. Cachear user_prompt em vez de system** | Mudar wrapper pra colocar `cache_control:ephemeral` no primeiro bloco do user message | Faz sentido se user_prompt repete entre consultas (mesmo plano sendo discutido). Nao bate com nosso padrao de uso (prompts ad-hoc). |
| **C. Aceitar F.1 nao vale** e focar em F.2 router (ja entregue, 70% economia validada) + F.5 truncation (entregue) | Sem mudanca | F.2 ja resolveu 70% do gasto do dominante. F.1 vira backlog Fase 7 quando tiver contexto fixo grande. |

**Recomendacao:** Opcao C agora. Re-avaliar A quando criarmos um "SystemPrompt Percus enriquecido"
(provavelmente quando F-4 do plano mestre Fase 7 — feature catalog enriched context — aparecer).

---

## 3. marketplace.json — Investigacao (Pendencia #4)

**Status:** ✅ Resolvido. `plugin.json` e o **source of truth pra versao**.

**Evidencia historica:** `marketplace.json` (root + duplicata em `plugin/.claude-plugin/`)
manteve `version: "1.0.0"` desde Fase 2/3 (commits `4e22cb3` e `aa11065`). O plugin passou por:
- v5.0.x, v5.1.x (Fase 5)
- v6.0.0, v6.1.0, v6.1.1, v6.1.2, v6.2.0 (Fase 6)

todas funcionais com `marketplace.json: 1.0.0` — prova que Claude Code le `plugin.json`.

**Mudanca aplicada:** ambos `marketplace.json` bumpados pra `6.3.0` + descricao atualizada
(citando Fase 6 v6.3.0 e os 3 providers do conselho). Cosmetico, mas evita pergunta no futuro.

---

## 4. Pendencias remanescentes

| # | Item | Decisao apos esta auditoria |
|---|---|---|
| 1 | Validacao A/B router | ✅ Aprovado (1 prompt). Rodar +2-3 em sessoes futuras pra robustez. |
| 2 | Cache Anthropic | ❌ Codigo OK, mas SystemPrompt curto demais. Backlog Fase 7. |
| 3 | Push v6.3.0 | ✅ Feito 2026-05-17. |
| 4 | marketplace.json | ✅ Bumpado v6.3.0 (cosmetico, plugin.json e autoritative). |
| 5 | Medir cache hit rate apos 1 semana | Sem efeito enquanto F.1 nao for ativado (ver finding #2). Adiar. |
| 6 | Nitpicks (sh /3 vs /3.5, path hardcoded) | Backlog quando alguem mexer no script equivalente. |

**Resumo:** Eixo F entregue gera **economia real de 70% no provider dominante** via F.2 router
(validado A/B). F.5 truncation operacional como rede de seguranca. F.1 cache fica como
oportunidade Fase 7 condicionada a SystemPrompt enriquecido.
