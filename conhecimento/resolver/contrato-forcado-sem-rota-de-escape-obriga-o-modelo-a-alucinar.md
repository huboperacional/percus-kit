## Contrato forçado sem rota de escape OBRIGA o modelo a alucinar — não é "o LLM errou" {#contrato-forcado-sem-rota-de-escape-obriga-o-modelo-a-alucinar}

`tags: llm, tool_choice, function calling, alucinacao, contrato inviavel por construcao, openai, extrator, guarda`

**Sintoma:** o modelo inventa dados plausíveis a partir de uma entrada que não os contém, e a investigação para em *"o LLM alucinou"* — que é descrição, não causa. Procura-se um default errado no código e não se acha nenhum, o que reforça a conclusão errada.

**Caso medido (2026-08-18):** um bot financeiro propôs `receita · "sim" · R$ 1,00` a partir da mensagem `"sim"`. Varredura confirmou que **não existia** default `1.0` em lugar nenhum do caminho. A causa estava na chamada:

```python
tools=[EXTRACTION_TOOL],
tool_choice={"type": "function", "function": {"name": "registrarLancamento"}},
```

`tool_choice` **forçado** numa única função, e um system prompt que só ensinava a extrair. Para o texto `"sim"` o modelo **não tinha resposta legal**: nenhuma saída do contrato correspondia a *"isto não é um lançamento"*. Ele não escolheu inventar — foi **obrigado**.

🔑 **A generalização:** quando um contrato de saída não tem estado para "não se aplica", o modelo preenche com o que for mais provável. A alucinação vira **requisito do desenho**, não desvio dele. É a mesma família de defeito de um contrato de código impossível de honrar (ex.: sinal transitório em atributo de memória num caminho que relê o objeto N vezes) — o problema não é quem executa, é o que foi pedido.

**Solução — dar uma saída legal, sem abrir mão da garantia:**
- Acrescente uma segunda tool explícita (`naoEhLancamento`, `naoSeAplica`) e troque o `tool_choice` forçado por **`"required"`** — não por `"auto"`.
- ⚠️ `"required"` mantém a garantia de que **sempre sai uma tool call**, então o caminho feliz não degrada para prosa livre. `"auto"` troca um bug silencioso por outro: o modelo passa a responder em texto e o caminho válido para de funcionar sem erro.
- Passe `parallel_tool_calls=False` se o parse lê só `tool_calls[0]`: com duas tools, uma chamada paralela em segundo lugar seria descartada em silêncio.
- Some uma guarda **determinística** de ancoragem (o dado proposto tem de ser rastreável à entrada). Ela cobre o caso em que o modelo ignora a rota de escape. Uma não substitui a outra.

⚠️ **A guarda de ancoragem é sobre RASTREABILIDADE, nunca sobre magnitude.** No caso medido, `R$ 1,00` é valor perfeitamente legítimo (estacionamento, taxa); o defeito era o texto não conter valor **nenhum**. Ler o incidente como "valor baixo é suspeito" — a leitura mais tentadora, porque o print mostrava R$ 1,00 — derrubaria lançamento real. Congele isso num teste com esse nome.

⚠️ **O risco do conserto é o INVERSO do bug, e é silencioso:** a rota de escape vira atrator e passa a recusar entrada válida porém bagunçada, sem erro e sem sintoma — só ausência. Troca-se dado inventado por dado que **sumiu**, e se descobre pelo cliente. Antes de trocar o contrato, **congele um corpus de regressão** com a classe "tem de passar" (não só a classe "tem de barrar") e emita uma métrica de taxa de recusa **com identificador de quem foi recusado** — taxa agregada esconde exatamente o caso que importa, que é um cliente cujo tráfego inteiro passou a ser recusado.
