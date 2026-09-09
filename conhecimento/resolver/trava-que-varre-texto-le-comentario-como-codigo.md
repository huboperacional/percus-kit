## Trava mecânica que varre TEXTO lê comentário como código — e o cego vale nos dois sentidos, com custo assimétrico {#trava-que-varre-texto-le-comentario-como-codigo}

`tags: trava mecanica, guard-rail, regex, AST, varredura, falso positivo, falso negativo, docstring, comentario, killswitch, anti-vacuo, R23`

**Sintoma:** um guard-rail que varre os fontes por expressão regular reprova a suíte num arquivo onde
você **só escreveu um comentário**. A mensagem acusa uma chamada que não existe. Ou, pior e sem
sintoma nenhum: o guard-rail fica verde para sempre sobre chamadas que ele nunca olhou.

**Causa raiz:** a varredura casa o **texto** do arquivo, e texto não distingue código de prosa nem
respeita a gramática da linguagem. Isso produz dois erros opostos:

**Falso positivo — o barato.** Citar `enviar(...)` num comentário ou docstring reprova a trava. Some
em minutos, mas tem um custo cultural que não some: ensina a equipe a escrever **prosa evasiva perto
de código sensível**, que é o oposto do que se quer justamente onde o comentário mais importa.

**Falso negativo — o caro, e ele é silencioso.** Uma regex que trata **um** nível de parênteses
aninhados — o padrão `(?:[^()]|\([^()]*\))*` é o exemplar — **não casa** uma chamada como
`enviar(destino, fmt(brl(v)))`. E chamada que não casa **não é verificada**: fica invisível, não
reprovada. Num guard-rail, invisível é o pior estado possível, porque **o verde afirma exatamente
aquilo que não foi olhado**. Bastava alguém formatar um valor dentro do argumento.

**Correção:** varra por **AST**, não por texto. O parser enxerga a chamada independentemente de
aninhamento, formatação ou quebra de linha, e **não enxerga comentário nenhum** — os dois cegos
fecham de uma vez. Reconheça a chamada tanto como `Attribute` (`mod.enviar`) quanto como `Name`
(`from mod import enviar`), que a varredura por nome não distinguia.

Duas regras que a conversão **não** dá de graça:

1. **Piso anti-vácuo, MEDIDO e não chutado.** Uma varredura que passa a achar zero (rename, refactor,
   import novo) dá PASS sobre nada. Conte quantas chamadas existem hoje e trave abaixo disso. ⚠️ Chutar
   o piso reprova na primeira execução — o que é barulhento e barato, mas mostra por que se mede.
2. **`**kwargs` conta como NÃO declarado.** O guard-rail existe para tornar a decisão **visível no
   call-site**; um dicionário montado longe dali esconde justamente o que ele deve expor.

**A medição que você provavelmente vai encontrar, e o que fazer com ela:** as duas versões tendem a
ver o **mesmo número** de chamadas reais hoje — a diferença é latente. Foi assim no caso que gerou este
verbete: 28 e 28, com o único extra da regex sendo um comentário. **Isso não invalida a troca, mas
muda como você a defende:** escreva um teste que prove os dois lados **por construção** (uma chamada
aninhada que a regex perde; um comentário que ela casa), senão a próxima pessoa volta para regex sem
enxergar o preço, e não haverá contagem que denuncie.

**Assimetria que decide a prioridade:** se a trava guarda algo cujo falso negativo custa caro — um
kill-switch anti-ban, um gate de escrita, uma checagem de permissão —, a conversão vale mesmo sem
sintoma. E, pelo mesmo motivo, **não a faça às pressas**: trava de segurança mal convertida deixa de
guardar em silêncio, o que é pior do que reprovar por prosa.

**O irmão desta moeda:** o erro simétrico é a **docstring falsa** — prosa que descreve o contrário do
que o código faz (*"as mensagens mais recentes"* sobre uma query que devolve as mais antigas). Aquele
não tem trava nenhuma que o pegue, porque nenhuma varredura confere prosa contra comportamento, e
propaga por N consumidores porque todos leem a mesma mentira. **Comentário é superfície de contrato,
não decoração:** ao ler um que descreva ordenação, direção, recência ou sinal, confira contra a
implementação antes de confiar — ainda mais se ele já tem consumidores.
