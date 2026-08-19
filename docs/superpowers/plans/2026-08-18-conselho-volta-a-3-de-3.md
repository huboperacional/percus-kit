# Conselho volta a 3/3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o conselho Percus volta a responder com 3 vozes em TODOS os projetos, e passa a ter teste que impede a mesma classe de quebra de voltar em silêncio.

**Architecture:** são DUAS causas independentes, de naturezas opostas. A causa 1 já está **corrigida no repo do kit e apenas não foi publicada** — é trabalho de *deploy*, zero código novo. A causa 2 é bug real, presente tanto na fonte quanto no cache ativo, e exige decisão de design antes do código. Tratar as duas como "o conselho está quebrado" foi o que manteve o problema vivo.

**Tech Stack:** PowerShell 5.1/7 + bash (paridade obrigatória), Pester (`tests/*.tests.ps1`), plugin Claude Code distribuído por marketplace git.

**Spec:** não há spec; a fonte do diagnóstico é o verbete `conhecimento/resolver/conselho-agent-marker-chamado-por-http.md` (commit `47ff288`) mais as medições do Passo 0 abaixo.

## Global Constraints

- **O kit é exceção a R11** (`01_REGRAS_INEGOCIAVEIS.md`): mudanças aqui não exigem `/percus-review:review`, mas exigem (a) plano explícito — este documento, (b) revisão do operador antes de virar canon, (c) verificação de consistência cruzada.
- **Paridade `.ps1` ↔ `.sh` é obrigatória.** Todo comportamento novo entra nos dois; um só é drift.
- **Fonte 100% ASCII** nos `.ps1` (PS 5.1 lê `.ps1` sem BOM como cp1252) — restrição já registrada em `council-tiebreaker.ps1:24`.
- **R25:** mudança de canon exige entrada no `CANON_VERSION.md`.
- **Nunca remendar o cache do plugin** (`.claude-home/plugins/cache/...`): some no próximo update. O conserto é no repo do kit.

---

## Passo 0 — Re-medir antes de mexer (o plano não confia no próprio diagnóstico)

Já medido em 2026-08-18 nesta máquina, e repetido aqui porque quem executar pode estar em outra.

- [ ] **Step 1: confirmar as duas causas na cópia ATIVA**

Descobrir o `installPath` ativo em `D:\Claud Automations\.claude-home\plugins\installed_plugins.json` (chave `percus-review@percus-tools`) e listar os providers do `_registry.json` de lá: `id`, `type`, `model`, `wrapper_ps1`.

Esperado hoje: `groq-llama / http / llama-3.3-70b-versatile` (modelo morto) e `cross-claude / agent-marker / None / None`.

- [ ] **Step 2: confirmar que NENHUM script lê o registry**

```
grep -rln "_registry" plugin/percus-review/scripts/ plugin/percus-review/providers/
grep -n  "_registry" plugin/percus-review/scripts/council-tiebreaker.ps1
```

Esperado: só `council-tiebreaker.ps1`, e nele apenas **em comentário** (linha 22). Se algum script passar a LER o registry, a Task 3 muda de forma — pare e replaneje.

---

## Task 1: Publicar a causa 1 (não há código a escrever)

O modelo do Groq já foi trocado na fonte (`b89575e`, canon 6.39.0): `llama-3.3-70b-versatile` → `openai/gpt-oss-120b`, mais barato que o que substituiu. O repo do kit está **3 commits à frente do `origin/main`**, e o plugin instalado é o `6.38.0`, construído do `origin/main`. Ou seja: a máquina roda código velho porque o conserto nunca foi publicado.

**Files:**
- Nenhum arquivo editado. Esta task é publicação + atualização do plugin.

- [ ] **Step 1: revisar o que vai subir**

```
cd "D:/Claud Automations/percus-kit" && git log --oneline origin/main..HEAD && git status --short
```

⚠️ Há modificações **não commitadas** em `conhecimento/*/INDICE.md`. Podem ser de sessão paralela. NÃO use `git stash` (ver memória `feedback_git_mecanica_sessao_paralela`): decida com o operador se entram ou ficam, e particione com `git commit -- <paths>`.

- [ ] **Step 2: publicar o branch `main` do kit para o `origin`**

Ação externa: exige aprovação explícita do operador (R20).

- [ ] **Step 3: atualizar o plugin nesta máquina**

O operador roda `/plugin update percus-review` numa sessão interativa — não é comando que o agente dispare.

- [ ] **Step 4: provar que a perna Groq voltou — pela via real, não pelo arquivo**

No NOVO `installPath`, `grep -rn "llama-3.3-70b-versatile"` tem que dar **0**. Depois, uma consulta real de conselho, lendo `respostas_usaveis` em `.deepseek/council-log/<ts>-consult.jsonl`: tem que subir de 1.

Ler o arquivo não basta — foi exatamente a confusão que manteve isto vivo: a fonte estava certa e a máquina, errada.

- [ ] **Step 5: confirmar que o `fact-check-triage` veio junto**

Não é detalhe. O `fact-check-triage` é pré-requisito para escalar finding crítico e roda no MESMO modelo. Enquanto o plugin estiver em 6.38.0, a trava anti-"conselho ratifica premissa não verificada" está apoiada no modelo morto — ou seja, **metade do problema não é o conselho**.

Conferir `MODEL` / `$Model =` em `scripts/fact-check-triage.ps1` e `.sh`: esperado `openai/gpt-oss-120b` nos dois.

---

## Task 2: `effort` deixa de ser incondicional — DECISÃO DE DESIGN NECESSÁRIA

**O bug, medido:** `providers/cross-claude.ps1:137` monta `output_config = @{ effort = $Effort }` **sempre**, e `cross-claude.sh:117` faz o mesmo. O `ValidateSet` do parâmetro (`low|medium|high|xhigh|max`) **não tem valor para desligar**. O roteador de modelo por modo (`council-orchestrator.ps1:303-310`) manda `claude-haiku-4-5` no modo `consult` — e foi aí que apareceu o `400 This model does not support the effort parameter`.

**Previsão testável que sai daqui:** `pre-mortem` usa `claude-opus-5` e `review` usa `claude-sonnet-5`. Se o diagnóstico estiver certo, **só o `consult` quebra**. Confirmar isso ANTES de codar muda o tamanho do conserto — e é de graça, porque o próximo `council-pre-mortem` já responde a pergunta.

- [x] **Step 1: medir quais modelos aceitam `effort`, em vez de deduzir** — feito 2026-08-19, 11 chamadas. Achou um defeito A MAIS que o relatado: `claude-sonnet-4-6` recusa `xhigh`.

Uma chamada mínima por modelo (`claude-haiku-4-5`, `claude-sonnet-5`, `claude-opus-5`) contra `POST /v1/messages`, duas vezes cada: uma com `output_config: {effort: "low"}` e uma sem, registrando só o status HTTP. `max_tokens: 16`, prompt de uma palavra.

Anotar a matriz resultante no verbete. **Custo: centavos.** É a diferença entre consertar a classe e remendar o sintoma.

- [x] **Step 2: tornar `effort` opcional nos dois wrappers** — feito. `"none"` no ValidateSet + tabela de dados `_effort-capabilities.json` lida pelos DOIS (uma cópia só).

`cross-claude.ps1`: acrescentar `"none"` ao `ValidateSet` e montar o corpo condicional —

```powershell
$body = @{ model = $Model; max_tokens = $MaxTokens; system = $sys; messages = $msgs }
if ($Effort -ne "none") { $body.output_config = @{ effort = $Effort } }
```

`cross-claude.sh`: mesmo comportamento, montando o JSON sem a chave quando `EFFORT=none`. Atenção: hoje o env `PERCUS_CROSS_CLAUDE_EFFORT` só troca o VALOR — `""` mandaria `effort: ""`, que é outro 400.

- [x] **Step 3 — RESOLVIDO DE OUTRA FORMA, de propósito.** O plano queria adjacência modelo/effort no `switch` do orquestrador. Não foi feito assim: o wrapper tem OUTROS chamadores (`smoke-cache-f1.ps1`, invocação manual), e conhecimento que vive só no orquestrador não protege nenhum deles — o 400 voltaria por fora. Pior: seria uma SEGUNDA cópia da regra, que é o defeito que o Step 2 acabou de matar. A tabela + o teste de paridade dão a mesma propriedade ("trocar modelo obriga a revisitar o parâmetro") cobrindo todos os chamadores.

Ao lado do `switch ($Mode)` que define `$CrossClaudeModel`, definir `$CrossClaudeEffort` pela MESMA tabela, no MESMO bloco — para que trocar de modelo obrigue a revisitar o parâmetro que anda junto. Essa adjacência é o conserto de verdade: a causa raiz não é o `effort`, é o modelo e o parâmetro morarem longe um do outro. Mesmo bloco em `council-orchestrator.sh`.

- [x] **Step 4: teste negativo** — 10 casos em `provider-limites.tests.ps1`. Visto VERMELHO (3 falhas) com o `effort` incondicional reintroduzido, antes de aceito.

Em `tests/provider-limites.tests.ps1` — o arquivo cuja razão de existir é justamente "trocou o modelo e não reavaliou o parâmetro ao lado", e que hoje tem **zero** ocorrência de `effort`:

```powershell
It "nao manda output_config quando o modelo nao aceita effort" {
    $body = Build-CrossClaudeBody -Model "claude-haiku-4-5" -Effort "none" -MaxTokens 16
    $body.ContainsKey("output_config") | Should -Be $false
}

It "manda output_config quando o modelo aceita" {
    $body = Build-CrossClaudeBody -Model "claude-opus-5" -Effort "low" -MaxTokens 16
    $body.output_config.effort | Should -Be "low"
}
```

Exige extrair a montagem do corpo para uma função `Build-CrossClaudeBody` — hoje ela é inline e por isso intestável. **Rodar o teste com o fix revertido e ver REPROVAR** antes de aceitar: guard que nunca foi visto vermelho não é guard.

---

## Task 3: o `_registry.json` deixa de mentir

**O achado que importa mais que o bug:** `type: agent-marker` não é desrespeitado por engano — **nenhum script lê o `_registry.json`**. Ele é documentação com aparência de configuração. Quem decide HTTP-vs-marcador é `council-orchestrator.ps1:316-327`, por `Test-Path` do wrapper + presença de `ANTHROPIC_API_KEY`. Enquanto o arquivo descrever um comportamento que o código não tem, todo diagnóstico futuro parte de premissa falsa — foi exatamente o que aconteceu aqui, inclusive no verbete que abriu esta investigação.

**Duas saídas. Recomendo a B.**

**(A) Honrar o registry:** o orchestrator passa a lê-lo e, com `type: agent-marker`, emite o marcador em vez de chamar HTTP.
*Contra:* joga fora o caminho direto, que segundo o comentário do próprio código existe para habilitar `cache_control` (prompt caching). Perder isso custa dinheiro em toda rodada.

**(B) O registry passa a descrever a realidade:** `cross-claude` vira `type: http-or-marker`, com `wrapper_ps1`/`wrapper_sh` reais preenchidos e um `_nota_type` explicando que o caminho direto é preferido quando há chave, com o marcador como fallback.
*A favor:* o comportamento atual é deliberado e melhor; o defeito está na documentação, não no código.
*Contra:* mantém o registry como prosa — o que o Step 2 endereça.

- [x] **Step 1: decisão (B)**, levada ao conselho a pedido do operador: 3/3 rejeitaram (A); 2/3 em "B + teste de sincronia". Divergência: DeepSeek queria apagar o arquivo.

- [x] **Step 2: `provider-registry-sync.tests.ps1`** (6 casos), visto vermelho ao restaurar a mentira. Era a condição que o conselho pôs em cima de (B):

```powershell
It "todo provider type=http tem wrapper que existe no disco" { ... }
It "provider declarado agent-marker nao tem caminho HTTP no orchestrator" { ... }
```

Sem isso, o registry volta a divergir na próxima troca de modelo, e o próximo diagnóstico volta a partir de premissa falsa.

---

## Task 4: fechar o rastro

- [x] **Step 1:** bump 6.42.0 via `scripts/bump-canon.ps1` (7 pontos).
- [x] **Step 2:** changelog 6.42.0 escrito.
- [x] **Step 3:** verbete marcado RESOLVIDO, com a matriz medida e a correção da premissa falsa. Verbete novo: `#direcao-da-enumeracao-por-qual-lado-falha-alto`. Marcar `conhecimento/resolver/conselho-agent-marker-chamado-por-http.md` como **RESOLVIDO**, com a matriz de modelos medida na Task 2 Step 1 — que é o dado reutilizável desta sessão. Corrigir também a afirmação do verbete de que o `cross-claude` "não deveria ser chamado por HTTP": ela parte do registry, e o registry é que está errado.
- [x] **Step 4 (metade):** 3/3 PROVADO pelo kit — `.deepseek/council-log/20260819-144208-consult.jsonl`, `respostas_usaveis: 3`, `respostas_degradadas: 0`. ⏳ **Falta publicar**: push (R20, exige aprovação) + `/plugin update` do operador. Até lá o cache em 6.41.0 segue com o wrapper quebrado.

---

## O que este plano NÃO faz

Não mexe no cache do plugin. Não renomeia o id `groq-llama` (é chave histórica, decisão já registrada no `_nota_id`). Não toca no roteador de review (R11). Não muda `default_set`.

## Nota de honestidade sobre este plano

O diagnóstico nasceu de uma investigação delegada. Antes de escrever, re-medi por conta própria os cinco fatos que o plano carrega: a declaração do `cross-claude` no cache ativo, a ausência de leitura do registry (incluindo confirmar que a única menção é comentário), o `effort` incondicional nos dois wrappers, o mapa modo→modelo, e os 3 commits à frente do `origin/main`. O Passo 0 existe para que quem executar não precise confiar nem em mim.
