## Sentinela por `??` confunde "não achei" com "achei, e o campo é null" — e o teste só passa se o produto falhar {#sentinela-por-nullish-confunde-nao-achei-com-achei-e-vazio}

`tags: typescript, javascript, nullish coalescing, ??, null, undefined, sentinela, expect.poll, playwright, R1, falso vermelho, teste invertido, desarquivar, soft delete`

**Sintoma:** um teste de ponta a ponta fica **vermelho** num passo que o servidor executou com sucesso. O log do
backend mostra a operação com `200 OK`, a API devolve o estado esperado quando consultada à mão, e o teste insiste
que o recurso "sumiu". Olhando só o vermelho, a leitura natural é *"o produto está quebrado"* — e ele não está.

**Reprodução real** (Empresa Milionária, R1 bancário da conta, 16/09):

```ts
// passo "desarquivar": espera arquivada_em voltar a null
await expect
  .poll(async () => (await contaNoServidor(id))?.arquivada_em ?? 'sumiu', { timeout: 15_000 })
  .toBeNull()
```

A intenção era boa: se a conta **não for encontrada**, devolver `'sumiu'` em vez de `undefined`, para o erro dizer
o que aconteceu. O problema é que `??` não distingue **de onde** veio o vazio:

| Situação | `conta?.arquivada_em` | `... ?? 'sumiu'` | O teste espera `null` |
|---|---|---|---|
| conta não encontrada | `undefined` | `'sumiu'` | ❌ vermelho (certo) |
| **conta encontrada e desarquivada — o SUCESSO** | **`null`** | **`'sumiu'`** | ❌ **vermelho (errado)** |
| conta encontrada e ainda arquivada | `'2026-09-16T…'` | `'2026-09-16T…'` | ❌ vermelho (certo) |

🔑 **Não existe entrada que faça esse teste passar.** O `??` troca `null` **e** `undefined` pelo sentinela, e `null` é
exatamente o valor que o sucesso produz. O teste estava escrito de um jeito que **só ficaria verde se o produto
falhasse de uma forma específica** — e, como o sentinela nunca é `null`, nem assim.

### Por que passa despercebido

- **O passo irmão parece igual e está certo.** No mesmo arquivo, o passo "arquivar" usava `?? null` com
  `.not.toBeNull()`: ali o sentinela **é** o valor de falha, e conta sumida reprova de verdade. Os dois lados usam a
  mesma forma, e só um está invertido.
- **O teste nunca tinha rodado** contra banco real. Escrito para uma janela futura, a expressão nunca encontrou o
  caso de sucesso.
- **O vermelho confirma a suspeita errada.** Numa migration nunca executada (`arquivada_em` era coluna nova), *"o
  desarquivar não grava"* é a hipótese mais plausível — e o teste a sustenta.

### Como distinguir, antes de mexer no produto

Os três passos que desfizeram a dúvida, **com o backend ainda de pé**:

1. **Ler o log do servidor** atrás da requisição do passo: `POST …/desarquivamento 200 OK`. O produto recebeu e aceitou.
2. **Conferir a semântica da consulta no código**, não supor: o lookup com `incluir_arquivadas=true` não filtra nada,
   então a conta não podia sumir dele.
3. **Reproduzir pela API**: desarquivar a mesma conta à mão e ler o campo — `arquivada_em = None`. Aplicar a
   expressão do teste a esse resultado correto devolveu `'sumiu'`.

### O conserto

Separar os dois vazios em **valores diferentes**, sem operador que os funda:

```ts
.poll(async () => {
  const conta = await contaNoServidor(id)
  return conta === undefined ? 'sumiu' : conta.arquivada_em
}, { timeout: 15_000 })
.toBeNull()
```

E **sabotar a asserção nova**, porque ela acabou de mudar: tirar o clique em "Desarquivar" tem de deixar o teste
vermelho **na linha nova**, com o campo ainda preenchido. Asserção corrigida que nunca reprovou não prova que
discrimina.

### A regra que resolve a classe

Sentinela para "não encontrado" **nunca** por `??` (nem por `||`) quando o **campo lido pode legitimamente ser
`null`** — soft delete (`deletado_em`, `arquivada_em`), datas opcionais, relações anuláveis. Nesses campos, `null` é
estado de negócio, não ausência. A pergunta de revisão é uma só: *"o valor que o sucesso produz é um dos que o `??`
substitui?"* Se for, o teste está invertido.

Mesma família, outra linguagem: em Python, `None == None` inverte filtro por chave opcional.

### Verbetes relacionados

- [[fallback-de-env-nao-dispara-com-string-vazia]]
- [[sabotagem-que-nao-aplica-reporta-verde]]
- [[a-sabotagem-prova-o-que-voce-imaginou]]
