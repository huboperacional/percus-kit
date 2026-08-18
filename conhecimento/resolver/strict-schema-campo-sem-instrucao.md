## Schema `strict` que OBRIGA o campo mas não ENSINA quando preenchê-lo produz silêncio, não erro {#strict-schema-campo-sem-instrucao}

`tags: structured outputs, function calling, strict, tool schema, prompt, openai, campo obrigatório, regressão silenciosa`

**Sintoma:** um recurso simplesmente para de acontecer. Nada estoura, nada loga, nenhum teste
fica vermelho. No caso real: "quero falar com um atendente" deixou de escalar para humano.

**Causa raiz:** ao trocar o contrato do LLM eu reescrevi o system prompt do zero e esqueci
**quatro** dos campos do schema (`atendente`, `entrega`, `endereco`, `pagamento`). Como o
schema é `strict`, todo campo está em `required` — então o modelo **é obrigado a preencher**
e devolve `false`/`null` para o que não entendeu que devia usar. O contrato continua válido, o
parse continua funcionando, a suíte continua verde. O recurso só some.

**Solução:** ao criar ou reescrever um tool schema, faça a checagem cruzada explícita —
**todo campo do schema tem uma linha de instrução no prompt?** É uma lista de dois conjuntos e
leva um minuto. E quando o schema substitui um anterior, faça o diff dos dois PROMPTS, não só
o dos schemas: o schema novo pode estar completo enquanto o prompt novo está pela metade.

**Corolário do mesmo caso** (contrato declarativo, "o LLM diz como o estado deve ficar"):
enuncie a **consequência da omissão**, não só a instrução positiva. "Repita as linhas que
permanecem" foi lido como sugestão; o que faltava era "toda linha que você NÃO incluir será
REMOVIDA". A regra positiva e a consequência negativa não são a mesma frase para um LLM.

**Ref:** tiatendo, frente do carrinho declarativo (2026-07-29), commit `6740202`.
