## Teste "opt-in por marker" RODA por padrão — e gasta dinheiro em silêncio {#teste-opt-in-por-marker-roda-por-padrao-e-gasta}

`tags: pytest, marker, opt-in, addopts, llm real, credito de API, custo, suite lenta, guard de chave, load_dotenv, vedacao, flaky, nao-determinismo`

**Sintoma:** um arquivo de teste declara no docstring que "só roda com `-m <marker>`" e que "é
pulado sem a chave", e mesmo assim ele **roda em toda execução da suíte**, chamando API paga. A
suíte fica lenta e cara, e ninguém liga os pontos porque o custo não aparece em lugar nenhum.

**A forma abstrata:** em pytest, **marker não filtra nada sozinho**. `pytest.mark.X` só CLASSIFICA;
a seleção só acontece se alguém passar `-m` na linha de comando ou puser `addopts = -m "not X"` no
`pytest.ini`. Sem isso, o teste marcado roda igual a qualquer outro. O docstring que diz "use `-m X`"
descreve a **intenção do autor**, não o comportamento do runner.

Segundo mecanismo, que fecha a armadilha: o `skipif` que deveria proteger costuma depender de uma
variável de ambiente — e o próprio arquivo faz `load_dotenv()` **antes** de avaliar o guard. Então
em máquina de desenvolvedor (que tem `.env` com chave real) o skip **não** dispara, enquanto no CI
(sem chave) dispara. Resultado: o custo só existe na máquina de quem menos espera por ele.

**Caso medido (tiatendo, 2026-08-31):** `tests/restaurant/test_noteTargetGolden_llmReal.py` declara
"Pulado sem `OPENAI_API_KEY` (CI nunca roda). Custo ~US$ 0,03." O `pytest.ini` não tinha `addopts`
com exclusão. Medição:

```
pytest tests/restaurant/                    -> 195s
pytest tests/restaurant/ -m "not llm_real"  ->  35s, 38 testes DESELECTED
```

Ou seja: **38 chamadas a LLM real por regressão completa**, sob uma vedação explícita de "zero
API". Foram ~4 regressões antes de alguém notar — e o que fez notar não foi o custo, foi **uma
falha a mais que o baseline**, porque teste de LLM real é não-determinístico e um dia ele reprova.

### O que fazer

- **Antes de confiar num "isto é opt-in"**, meça: `pytest <alvo> --collect-only -q | wc -l` contra
  `pytest <alvo> -m "not X" --collect-only -q | wc -l`. A diferença é o que roda sem você pedir.
- Rode regressão com a exclusão explícita: `-m "not llm_real"` (ou o marker do projeto).
- Quem quiser tornar o opt-in real: `addopts = -m "not llm_real"` no `pytest.ini`. **É decisão de
  projeto** (muda a seleção default para todo mundo), não conserto de carona no meio de outra
  frente.
- 🪤 **Efeito colateral que custa análise:** esses testes são não-determinísticos. Quem comparar
  `nodeid`s de falha contra baseline vai ver um delta que **não é regressão** — e vai perseguir um
  defeito que não existe. Não re-rode para "confirmar a flakiness": confirmar gasta de novo.

**Parente:** [runner-de-teste-sai-zero-sem-rodar-nada](runner-de-teste-sai-zero-sem-rodar-nada.md)
— lá o runner não roda e parece verde; aqui ele roda MAIS do que você pediu e parece igual.
