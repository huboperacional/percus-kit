## `tokens_out` exatamente igual ao `max_tokens` é TRUNCAMENTO, não erro do modelo {#tokens-out-igual-ao-teto-e-truncamento-nao-erro-do-modelo}

`tags: llm, max_tokens, json, parse_error, truncamento, discriminador, observabilidade, custo`

**Sintoma:** a integração com LLM que pede JSON começa a falhar no parse todo dia. Parece
"instabilidade do modelo" ou "prompt que piorou", e o retry não salva.

**O discriminador, e ele é perfeito:** compare `tokens_out` com o `max_tokens` da chamada.
Se forem **iguais**, a resposta foi **cortada no teto** e o JSON está incompleto — não há
malformação nenhuma a debugar. Medido num caso real: `parse_error ⟺ tokens_out == max_tokens` em
**12 de 12** ocorrências ao longo de dois meses, e **toda** chamada bem-sucedida abaixo do teto
(515–676 contra teto 700). Zero exceção nas duas direções.

**Por que passa despercebido por dias:** o retry costuma reenviar **o mesmo prompt com o mesmo
teto**, então contra truncamento ele reproduz o corte idêntico. A falha deixa de ser intermitente e
vira determinística — e o fallback "graceful" (gravar `{parse_error}` e seguir) esconde isso do log
de erros. No caso medido foram **4 dias, 4 de 4 chamadas**, com a IA cobrada em todas.

**O gatilho típico:** alguém enriquece o prompt (uma seção nova, mais contexto) e a SAÍDA cresce
junto. O teto ficou onde estava. Antes: pico de 676 contra 700 — folga de 3,5%, que ninguém olha.
Depois: estoura toda vez.

**O que fazer:**
1. Dimensione o teto contra a **maior saída observada**, com folga declarada (ex.: 2×), e escreva a
   medição no comentário — teto é número medido, não número redondo.
2. Extraia o teto para **constante nomeada**. Um literal no call site faz o conserto da constante
   não valer nada — o gate tem de cobrar as duas metades (o valor E a fiação).
3. Grave o motivo do `parse_error` **no banco**, não só no log: o log do container não sobrevive ao
   redeploy, e é exatamente aí que a investigação chega.
4. Trate `tokens_out == max_tokens` como **falha declarada**, nunca como resposta.

⚠️ E desconfie da janela: se um outro defeito derrubou o job no mesmo período, ele **mascara** a
regressão. No caso medido, a mudança que quebrou e a correção de uma queda anterior foram
commitadas **no mesmo dia** — enquanto o job estava morto ninguém podia ver que a mudança do dia o
tinha quebrado.
