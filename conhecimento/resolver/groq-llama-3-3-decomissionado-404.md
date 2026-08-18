## Perna Groq do conselho responde 404: `llama-3.3-70b-versatile` foi decomissionado {#groq-llama-3-3-decomissionado-404}

`tags: conselho, groq, llama-3.3-70b-versatile, 404, modelo decomissionado, council-orchestrator, pre-mortem, perna muda, consenso de 2 de 3, R11`

**Sintoma:** o `council-orchestrator` roda, devolve JSON com `"status": "ok"` para DeepSeek e
Cross-Claude, e para a perna Groq devolve `"error": "Response status code does not indicate success:
404 (Not Found)"` com `latency_ms` de ~300 ms. O run **inteiro** continua parecendo utilizável — o
`summary` só lista `"groq-llama: error"` no meio de outras linhas, e quem lê a síntese vê dois
pareceres substanciosos e segue em frente.

**Causa raiz:** o Groq **aposentou** o modelo `llama-3.3-70b-versatile`. Não é rede, não é chave, não
é rate limit — é 404 de rota: o id do modelo não existe mais no catálogo deles. Latência de 300 ms
(contra 40 s e 107 s das outras pernas) é a assinatura: a requisição nem chegou a um modelo.

**Quando quebrou, medido nos próprios logs:** funcionava em **2026-08-03** e **2026-08-06**
(`groq-llama -> ok llama-3.3-70b-versatile` nos dois `*-pre-mortem.jsonl`), e estava 404 em
**2026-08-17**. Ou seja, quebrou em algum ponto dessa janela e **ninguém percebeu**, porque o
orchestrator não falha quando uma perna morre.

**Por que isto importa mais do que parece:** o critério de "risco crítico" do pré-mortem é
**≥2 providers apontando o mesmo risco**. Com uma perna morta, "2 de 3" vira "2 de 2" — ou seja,
**consenso unânime disfarçado de maioria**, e qualquer risco que só o Llama veria simplesmente não
aparece. É a mesma classe de
[[reference_review_limpo_pode_ser_vacuidade]]: a ferramenta responde, o resultado parece legítimo, e
o que falta é invisível.

🔴 **NÃO existe "trocar por outro Llama" — confirmado em 2026-08-17 por sessão independente
(tiatendo), listando `GET /models` com a chave real.** Os ÚNICOS modelos `llama` que a chave enxerga
hoje são `meta-llama/llama-prompt-guard-2-22m` e `-86m`, que são **classificadores de prompt, não
modelos de chat**. O catálogo de chat que sobrou é de outra família (`openai/gpt-oss-120b`,
`openai/gpt-oss-20b`, `qwen/qwen3.6-27b`, `groq/compound`). Ou seja o conserto **troca a família do
modelo**, não a versão — e com isso a perna deixa de ser "a perspectiva Llama" e passa a ser outra
coisa, o que precisa ser dito ao operador em vez de silenciosamente renomeado.

🔴 **O id morto está em 9 arquivos do plugin `6.36.5`, e dois deles NÃO são o conselho:**
`providers/_registry.json:23` · `providers/groq-llama.ps1:16` · `providers/groq-llama.sh:8` ·
`scripts/council-orchestrator.ps1:58` · `scripts/council-orchestrator.sh:17` ·
**`scripts/fact-check-triage.ps1:33,39`** · **`scripts/fact-check-triage.sh:11`** ·
`tests/council-tie-breaker.tests.ps1:21`. O `fact-check-triage` é o **pré-requisito que a própria
skill `council-consult` exige** antes de escalar finding crítico — então a trava anti-"conselho
ratifica premissa não verificada" (incidente Plexco Tasks 2026-05-18) está apoiada no mesmo modelo
morto. Consertar só o wrapper do conselho deixa essa metade quebrada.

**Solução:**
1. Trocar o id do modelo no wrapper do Groq por um vivo no catálogo atual deles (checar
   `GET https://api.groq.com/openai/v1/models` com a chave antes de escolher — não adivinhar pelo
   nome). **Varra os 9 sítios acima, não só `providers/`.**
2. **Antes de confiar num pré-mortem, conferir quantas pernas realmente responderam.** No JSON:
   `responses[].status`. Se veio `error`, o consenso mudou de denominador e precisa ser dito em voz
   alta no relatório ao operador.
3. Considerar fazer o orchestrator **falhar alto** (ou pelo menos gritar) quando uma perna volta
   erro, em vez de listar num `summary` que ninguém lê.

🔴 ~~**A checagem barata que separa "perna morta" de "perna lenta" é a latência.**~~ **REVOGADO em
2026-08-18.** Valia enquanto a perna era Llama. Com `openai/gpt-oss-120b` a perna **saudável**
responde em **636–789 ms** — dentro da faixa que este verbete ensinava a ler como "morta". Usar
latência hoje produz **falso positivo**, que é pior que a falta do sinal. O que vale agora:
`status == "ok"` **e** `content` não-vazio. Detalhe em
[[troca-para-modelo-de-raciocinio-esvazia-teto-de-tokens]].

---

### ✅ RESOLVIDO em 2026-08-18 (canon 6.39.0)

Catálogo reconferido com a chave real no dia (`GET /openai/v1/models`): `llama-3.3-70b-versatile`
segue ausente, e os únicos `llama` visíveis continuam sendo os classificadores
`meta-llama/llama-prompt-guard-2-22m|-86m`. Confirmado o diagnóstico de 2026-08-17.

**A perna Groq passou a rodar `openai/gpt-oss-120b`** ($0.15/$0.60 por 1M — **mais barata** que o
Llama que substituiu). Os 9 sítios do plugin foram varridos, mais 4 que este verbete não listava:
`04_MODEL_ROUTING.md`, `06_CONSELHO_PERCUS.md`, `README.md` e a tabela de preço em
`scripts/analyze_council_spend.py`.

**O id do provider continua `groq-llama`, de propósito** — é chave histórica em log antigo,
`default_set` e assert de teste. A mentira está declarada no campo `_nota_id` do
`providers/_registry.json` e no cabeçalho de `council-tiebreaker.ps1`: quem diz o modelo é o campo
`model`, nunca o id.

**Consequência de preço que quase passou:** o alias `groq-llama` na tabela de custo se justificava
por "mapeia 1:1 num único modelo que nunca mudou de preço". A troca matou a premissa, e o alias
mantido precificaria run **novo** ao preço do modelo **morto** — 3,9× pra cima na entrada, calado.
Alias removido; o id do modelo antigo **fica** na tabela para o histórico continuar somando ao preço
da época.

⚠️ **A troca de família reabriu três defeitos no `fact-check-triage`** (teto de tokens, guarda de
`status`, regex de formato) que não têm nada a ver com Groq e vão repetir na próxima troca de modelo.
Estão em [[troca-para-modelo-de-raciocinio-esvazia-teto-de-tokens]] — leia **antes** de trocar
qualquer modelo por um de raciocínio.

**Ref:** observado em 2026-08-17 rodando `council-pre-mortem` no projeto Scraper-prospeccao,
canon 6.36.6. Log: `.deepseek/council-log/20260817-080310-pre-mortem.jsonl`.
Resolvido em 2026-08-18 no `percus-kit`, canon 6.39.0.
