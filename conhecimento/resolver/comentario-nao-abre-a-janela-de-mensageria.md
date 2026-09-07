## Comentário não abre a janela de mensageria — e as duas janelas da Meta não moram no mesmo lugar {#comentario-nao-abre-a-janela-de-mensageria}

`tags: meta, instagram, private reply, janela 24h, janela 7 dias, messaging window, comment, conversa, deadline, modelo de dados`

**Origem:** CL_Liliflow, 2026-09-07. Padrão portado do nudgra-oss (`metaDelivery.ts`), confirmado no
comportamento da API.

**Contexto.** A Meta roda **dois relógios** para envio, e tratá-los como um só produz erro que só
aparece no momento da rejeição:

| Janela | Vale para | Duração | Abre quando | Onde guardar |
|---|---|---|---|---|
| Private Reply | resposta a **um** comentário específico | **7 dias** | o comentário foi postado | na **tentativa de envio** |
| Mensageria padrão | DM comum | **24 horas** | a pessoa **escreveu** para você | na **conversa** |

**Causa raiz de dois erros comuns.**

1. **Colapsar as duas num campo só.** A de 7 dias é escopada a um `comment_id`: dois comentários da
   mesma pessoa carregam **dois prazos independentes**. Se ela mora na conversa, o segundo comentário
   herda o prazo do primeiro e o envio é recusado por um relógio que não é o dele.
2. **Deixar o comentário abrir a janela de 24h.** Um comentário **não** é mensagem recebida. Uma
   conversa nascida de comentário tem que ter `messagingWindowClosesAt` **nulo** — senão o sistema
   acredita que pode mandar DM comum para alguém que nunca escreveu, e descobre que não pode só
   depois de gastar a chamada.

**Solução.** Dois campos, em dois lugares, e a decisão **antes** da chamada HTTP:

```ts
if (kind === "PRIVATE_REPLY")
  return attempt.privateReplyExpiresAt > now;   // prazo do comentário
return conversation.messagingWindowClosesAt > now;  // prazo da conversa
```

E `shouldCloseConversationWindow = !isPrivateReply` — uma private reply **não consome nem fecha** a
janela da conversa, porque nunca dependeu dela.

- **O custo de descobrir depois:** sem a checagem prévia, o worker paga a chamada, recebe
  `"outside of allowed window"` como string, e inicia uma cadeia de retry que **não pode** dar certo.
- **Onde a de 7 dias não pode ser aplicada:** o webhook de comentários **não carrega timestamp**. Só
  o reconciliador de polling tem. Guarde `null` quando não souber e não force — a Meta continua sendo
  a rede de segurança; inventar um prazo é pior que não ter.
- **Sincronizar histórico só pode ESTENDER a janela, nunca encurtar:** tráfego de webhook é mais
  atual que backfill, e um timestamp velho vindo da sincronização não pode fechar janela aberta.

**Ref:** `CL_Liliflow/app/lib/meta/delivery-window.ts`, `prisma/schema.prisma`
(`Conversation.messagingWindowClosesAt`, `DmLog.privateReplyExpiresAt`).
