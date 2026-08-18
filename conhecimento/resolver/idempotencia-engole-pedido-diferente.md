## Retorno antecipado de idempotência ENGOLE o pedido que veio diferente {#idempotencia-engole-pedido-diferente}

tags: idempotencia, retorno antecipado, early return, operacao repetida, PUT parcial,
guarda pulada, 200 sem efeito, aprovar ja aprovado

**Sintoma:** uma operação idempotente (aprovar, arquivar, ativar, confirmar) responde **200 e
não faz nada** quando o recurso já está no estado pedido — o que é correto — mas a chamada
trazia **outros campos** junto, e eles somem sem aviso. Pior: as guardas que validariam esses
campos **não rodam**, porque o retorno antecipado acontece antes delas.

No caso medido, o endpoint de aprovação aceitava correções no mesmo corpo (o requisito manda
"corrigir e aprovar na mesma ação"). Aprovar um título **já aprovado** mandando `categoria_id`
de outra empresa devolvia **200**: o `return` da idempotência vinha antes da checagem de
referência, e o cliente via sucesso com o dado intacto.

**Causa raiz:** "idempotente" foi lido como "se o estado final já vale, não faça nada". O certo
é **"se o PEDIDO é o mesmo, o resultado é o mesmo"**. Um pedido que carrega mudança não é o
mesmo pedido, mesmo que o estado-alvo coincida.

**Solução:** separe *repetição* de *pedido diferente com o mesmo destino* antes do retorno:

```python
pedidas = {c: v for c, v in correcoes.items() if v is not None}

if recurso.estado is ESTADO_ALVO:
    if pedidas:                       # não é repetição: é edição pedindo carona
        raise EstadoInvalido("já está X; a correção de ... é uma edição — use o PATCH")
    return recurso                    # repetição pura: devolve, e SEM gravar evento
```

Duas consequências que valem para qualquer caso assim:

- **Repetição pura não grava histórico.** Um evento por clique num histórico imutável é ruído
  que ninguém consegue apagar depois.
- **A recusa tem que apontar o caminho certo** (aqui, o `PATCH`), senão quem está integrando
  fica sem saída visível.

**Como foi encontrado:** por um harness genérico que ataca **todo endpoint** com referência da
empresa vizinha no corpo e exige 4xx. Nenhum teste escrito à mão cobria a combinação
"já aprovado" + "corpo com correção" — era uma casa fora do tabuleiro de quem escreveu os
testes, e dentro do tabuleiro de quem varre por construção.

**Ref:** Empresa Milionária, Fase B Task 8 (fila de aprovação), 2026-08-14.
