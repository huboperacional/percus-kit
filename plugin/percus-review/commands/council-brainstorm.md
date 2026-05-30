---
name: council:brainstorm
description: Enriquece sessao superpowers:brainstorming com 3 perspectivas (DeepSeek + Llama + Cross-Claude opcional). Conselho responde COMO SE FOSSE CONSULTOR INDEPENDENTE revisando a opcao que Claude trouxe. Operador ainda decide.
---

# /council:brainstorm

Use **dentro de sessao `superpowers:brainstorming`**, opcional. Cada vez que Claude formula uma `AskUserQuestion`, conselho roda em paralelo e injeta 3 perspectivas como **contexto adicional** antes do operador responder.

Diferenca pra `/council:consult`:
- `/council:consult` reduz perguntas (consenso 3/3 → executa sem perguntar).
- `/council:brainstorm` enriquece perguntas (sempre pergunta, mas com 3 perspectivas anexadas).

## Quando ativar

- Operador autoriza no INICIO da sessao brainstorming, com gatilho explicito:
  ```
  Quero brainstormar com conselho ativo. Use /council:brainstorm em cada decisao.
  ```
- Brainstorm de decisao de produto / stack / arquitetura grande (justifica latencia +2s por pergunta).
- Quando operador quer evitar vies do Claude sozinho.

## NAO ativar

- Brainstorm de decisao trivial / mecanica → so atrasa.
- Brainstorm de decisao com prazo curto (deploy hoje) → +2s por pergunta vira atrito.

## Fluxo (passo a passo do agente)

### 1. Verificar autorizacao

Antes de QUALQUER `AskUserQuestion` na sessao brainstorming, checar se operador autorizou. Se nao:

```
[council:brainstorm] Conselho ativo? (sim/nao/uma-vez)
```

- `sim` → rodar conselho antes de cada pergunta dali pra frente.
- `nao` → comportamento normal (so AskUserQuestion direto).
- `uma-vez` → rodar so nesta pergunta, perguntar de novo na proxima.

### 2. Antes de cada AskUserQuestion

Quando voce ia formular pergunta com N opcoes:

a. Monte o prompt (⚠️ **NUNCA num nome de arquivo fixo** tipo `/tmp/council-brainstorm.txt` — no Windows vira `d:\tmp\...` e fica stale entre runs; bug 2026-05-30. Temp unico no passo b):
   ```
   CONTEXTO BRAINSTORM: <2-3 linhas do contexto da sessao ate aqui>
   
   DECISAO EM ABERTO: <a pergunta que ia fazer ao operador>
   
   OPCOES QUE EU CONSIDEREI:
   - A: <opcao A com 1 linha de descricao>
   - B: <opcao B>
   - C: <opcao C, se houver>
   
   PERGUNTA AO CONSELHO: 
   1) Voce escolheria qual opcao se fosse operador, e por que (1 frase)?
   2) Existe opcao D-F que eu (Claude) deixei de considerar? Liste no maximo 1.
   3) Qual risco invisivel da opcao A?
   ```

b. Rode orchestrator em mode consult — arquivo temp **unico** por invocacao (nunca nome fixo):
   ```powershell
   $Q = Join-Path $env:TEMP "council-brainstorm-$([guid]::NewGuid().ToString('N')).txt"
   @'
   <conteudo do passo a>
   '@ | Set-Content -LiteralPath $Q -Encoding utf8
   pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" -PromptFile $Q -Mode consult -Providers "deepseek,groq-llama"
   Remove-Item -LiteralPath $Q -Force -ErrorAction SilentlyContinue
   ```

   (Cross-claude opcional aqui — latencia +30s por pergunta vira atrito. So adicionar se decisao grande.)

c. Leia ultimo `.deepseek/council-log/<ts>-consult.jsonl`. Extraia resposta por provider.

### 3. Anexar perspectivas a pergunta

Construa `AskUserQuestion` com perspectivas no final do texto:

```
question: <sua pergunta original>

PERSPECTIVAS DO CONSELHO:

DeepSeek (latencia Xms): <escolha> | <razao em 1 linha>
Llama (latencia Xms): <escolha> | <razao em 1 linha>

OPCAO ADICIONAL SUGERIDA (se algum provider sugeriu D-F): <opcao + qual provider>
RISCO INVISIVEL DESTACADO: <maior risco apontado por consenso, se houver>
```

Operador responde com contexto completo, nao so com a opcao do Claude isolada.

### 4. Se 2/2 ou 3/3 concordam numa opcao NAO mencionada por Claude

Adicione DESTAQUE na pergunta:

```
[council:brainstorm] ATENCAO: conselho consenso N/N sugere opcao <X> que eu nao havia considerado.
Quer que eu adicione como opcao na pergunta?
```

## Custo / latencia

- 2 providers (DS + Llama): ~$0.002 por pergunta, +~2s latencia.
- 3 providers (+ CC subagent): +~30s — desencorajar em brainstorm.

Brainstorm tipico tem 5-10 perguntas → custo total ~$0.01-0.02, latencia +20s spread.

## Anti-padroes

- ❌ Rodar conselho em brainstorm SEM autorizacao do operador — atrasa decisoes triviais.
- ❌ Brainstorm com Cross-Claude em cada pergunta — 30s/pergunta vira insuportavel.
- ❌ Ignorar opcao D sugerida pelo conselho — perde valor do enrich.
- ❌ Conselho discorda do Claude, e Claude "convence" o operador da opcao original — vies de
  ancoragem. Apresente as 3 perspectivas honestamente.

## Referencias

- Spec: `_Novo_Projeto/06_CONSELHO_PERCUS.md` Modo 4.
- Skill upstream: `superpowers:brainstorming`.
- Logs: `.deepseek/council-log/<ts>-consult.jsonl`.
