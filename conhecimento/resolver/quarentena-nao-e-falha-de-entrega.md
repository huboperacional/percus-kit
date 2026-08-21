## Quarentena de kill-switch não é falha de entrega — e a tela precisa da diferença {#quarentena-nao-e-falha-de-entrega}

`tags: kill-switch, quarentena, WA_PROACTIVE_ENABLED, facade, wa_client, motivo, mensagem de erro, UX de falha, envio proativo, WhatsApp, cliente cru, gate, inventário de remetentes`

**Contexto:** produto com kill-switch de envio proativo (ver [[kill-switch-no-facade]]) e uma tela que relata, canal a canal, se o aviso saiu. Com a quarentena **ligada**, o facade recusa o envio.

**Sintoma:** a tela diz *"o WhatsApp não aceitou o envio (envio_proativo_em_quarentena)"*. O administrador vai investigar o número do destinatário, o aparelho, o provedor — e o problema é uma trava **nossa**, ligada de propósito, que nenhuma dessas checagens revela.

**Causa raiz:** o call-site trata todo `success=False` como a mesma coisa. O resultado do facade carrega a distinção (um `error` reservado para a quarentena), e quem consome joga fora essa informação ao montar a mensagem.

**As duas frases mandam a pessoa fazer coisas diferentes** — e é isso que torna a distinção obrigatória, não cosmética:

| Estado | O que a tela deve dizer | O que a pessoa faz |
|---|---|---|
| Entrega falhou | "o WhatsApp não aceitou o envio (`<motivo>`)" | confere o número, o aparelho, tenta de novo |
| Quarentena ligada | "o envio proativo está em quarentena neste produto" | avisa por fora e **espera** — tentar de novo não muda nada |

**Solução:** exponha um predicado no facade (`foiBloqueadoPorQuarentena(resultado)`) para o call-site não comparar a string do erro na mão, e trate-o **antes** do ramo genérico de falha:

```python
resultado = await evo.sendMessage(numero, texto, proativo=True, remetente="convite_contador")
if evo.foiBloqueadoPorQuarentena(resultado):
    return Envio(enviado=False, motivo="o envio proativo está em quarentena neste produto")
if not resultado.success:
    return Envio(enviado=False, motivo=f"o WhatsApp não aceitou o envio ({resultado.error})")
```

**A armadilha que vem junto:** um caminho de envio escrito meses depois do kill-switch importa o **cliente cru** (`gowa_client`) em vez do facade, e nasce fora do gate — não por descuido de gate, mas porque o import "óbvio" para quem escreve um módulo de notificação é o cliente. Quem pega isso é a guarda que varre o código-fonte por `sendMessage(`; classifique o arquivo numa categoria que diga **onde** está o gate dele (`GATEADOS_PELO_FACADE`), senão a próxima pessoa procura um `proactiveBlocked` que não existe ali.

⚠️ **Consequência que precisa ser declarada, não descoberta:** com a quarentena ligada em produção, a feature nova **não envia** — e isso é o desenho funcionando. Escreva no plano e na tela; senão a primeira pergunta na volta é "por que o convite não chegou?".

**Ref:** Empresa Milionária, 2026-08-20 — o aviso de aprovação (M1-2) e o convite do contador (M1-7) chamavam o cliente cru; os dois iniciam conversa com quem não escreveu para nós.
