# Formato: `CONTEXT.md` — vocabulário do domínio

**Dono de:** a linguagem. Nada além disso.

**Por que existe:** se você e o operador entendem coisas diferentes por "cancelamento", nenhuma spec salva o projeto. Este é o artefato que o V1 não tinha.

> **`CONTEXT.md` é um glossário — e nada mais.** Sem detalhe de implementação, sem decisão de arquitetura (isso é ADR), sem estado (isso é PLANO/HANDOFF). Se você está escrevendo *como funciona*, está no arquivo errado.

---

## Estrutura

```markdown
# CONTEXT — {projeto}

Linguagem deste domínio. Um termo, um significado.

## {Termo}
{Definição em 1-2 frases.}
**Não confundir com:** {termo vizinho} — {a diferença que importa}.

## Pedido
Intenção de compra registrada, ainda sem pagamento confirmado.
**Não confundir com:** Venda — só existe após pagamento aprovado.
```

## Quando escrever

Durante o `grilling` (`loops/grilling.md`), no momento em que um termo é **fixado** — não depois, em lote. Termo resolvido esfria rápido.

Gatilhos:
- O operador usa uma palavra com **duas leituras possíveis** → fixe agora.
- O operador usa um termo que **conflita** com o que já está no glossário → aponte na hora: *"seu glossário define X como A, mas você parece querer B — qual é?"*
- O **código discorda** do que o operador acabou de dizer → traga a contradição à tona.

## Regras

- **Criação preguiçosa.** Não crie o arquivo "para ter". Ele nasce quando o primeiro termo é resolvido.
- **Um termo, um significado.** Sinônimo no domínio é dívida: escolha o canônico e registre o descartado como "não confundir".
- **Sem implementação.** "Pedido é uma row em `orders`" está errado aqui. Nome da tabela é implementação.
