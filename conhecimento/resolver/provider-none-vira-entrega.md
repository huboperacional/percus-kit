## Cliente de API que devolve `None` no erro faz o produto inteiro achar que ENTREGOU {#provider-none-vira-entrega}

`tags: provider none entrega recusa retry fila pending idempotencia envio whatsapp`

tags: mensagem nao entregue, provider devolve None, WhatsApp recusou, 400 INVALID_JID, 429 rate limit, fila de retry vazia, pending_messages, achou que enviou, SENT REJECTED DROPPED, desfecho explicito, self-loop guard, idempotency key, duplicar mensagem

**Sintoma:** mensagens que o provider RECUSOU aparecem como enviadas. A fila de retry existe,
está implementada e testada — e NUNCA recebe nada. Ninguém percebe porque não há erro: o log da
recusa fica no cliente HTTP, e a camada de cima segue como sucesso.

**Causa:** o wrapper do provider engole a resposta ruim e devolve `None`
(`if status < 300 and code == "SUCCESS": return data` … `return None`), e o chamador só faz
`await client.send(...)` sem olhar o retorno. Como não LEVANTOU, "deu certo".

**Como achar:** mande de propósito pra um destino que o provider recusa (número reservado,
credencial inválida) e pergunte ao BANCO, não ao log: a linha entrou na fila de retry? Se a
resposta for "zero linhas", o produto está mentindo. Teste unitário não pega porque todo mundo
simula falha **levantando exceção** — que não é como esse tipo de envio falha.

**Como resolver:** o envio passa a declarar um **desfecho explícito**, e são TRÊS, não dois:

| Desfecho | Quem causou | Retenta? | Vai pra fila? |
|---|---|---|---|
| `SENT` | provider aceitou | — | — |
| `REJECTED` | provider recusou / rede caiu | sim | sim |
| `DROPPED` | **decisão nossa** de não enviar (guarda de segurança, destino inválido) | não | **NÃO** |

O `DROPPED` separado não é preciosismo: enfileirar um descarte deliberado faz a fila entregar
depois exatamente a mensagem que a guarda existia pra impedir. E desfecho **desconhecido** (caminho
novo que esqueceu de declarar) deve cair como `REJECTED` + log de erro — fail-safe na direção da
entrega, nunca na do silêncio.

**Armadilhas ao aplicar (as duas custaram uma rodada cada):**
- A tabela da fila costuma ter FK obrigatória (`conversation_id NOT NULL`). Há callers que
  despacham sem esse contexto — passar a enfileirar transforma perda silenciosa em **exceção no
  meio do envio**, que é pior. Sem o contexto: reporta e loga alto, não enfileira.
- **Timeout depois da entrega** é indistinguível de recusa se o wrapper engole toda exceção. O
  retry pode DUPLICAR. Decida conscientemente e ESCREVA a decisão no código; se duplicata doer, o
  lugar de separar "resposta com erro" de "sem resposta" é o wrapper, não o chamador.

**Sintoma-irmão pra procurar no mesmo repo:** algum chamador que já tentava ler o retorno
(`ok = await send(...)`; `status = "success" if ok is not False`) — ele estava escrito esperando um
bool que nunca existiu, e contabilizava 100% de sucesso. Achar isso confirma o diagnóstico.

Visto em: tiatendo `0.253.1` (2026-07-27), achado por smoke em produção depois de a suíte inteira
(4900+) e duas reviews cross-provider passarem.
