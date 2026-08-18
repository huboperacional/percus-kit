## Guarda que usa uma ferramenta para EMITIR o próprio bloqueio fica muda quando ela falta {#guarda-muda-sem-a-ferramenta-que-usa-pra-falar}

`tags: hook, PreToolUse, jq ausente, fail-open, fail-closed, guarda muda, deny, exit 2, command -v, testar a chamada`

Um hook que monta o JSON de `deny` **com `jq`** tem uma dependência circular escondida: sem `jq`, ele não consegue **nem dizer que quer bloquear**. E guarda muda, para o harness, é indistinguível de guarda que aprovou.

Dois furos aparecem juntos, e o segundo é o que engana:

1. **Na entrada** — `CMD=$(... jq ... || echo "")` zera a variável quando o `jq` falha; o padrão não casa e o hook sai 0. Conserto: sem parse confiável, case o padrão contra o **payload cru** (o texto do comando está lá dentro), errando para o lado de bloquear.
2. **Na saída** — o `deny` não sai. Conserto: o contrato de `PreToolUse` aceita **duas vias** — JSON com `permissionDecision`, ou **`exit 2` com o motivo em stderr**. Falhando a primeira, use a segunda.

⚠️ **Não teste com `command -v jq`.** Isso verifica se o arquivo **existe**; um `jq` presente porém quebrado (versão incompatível, binário corrompido, PATH envenenado) passa nesse teste e falha ao rodar — voltando à guarda muda. Teste pelo **resultado**: `SAIDA=$(jq -n ... 2>/dev/null)` e decida por `[ -n "$SAIDA" ]`.

⚠️ **E o teste dessa borda precisa exigir a ASSINATURA da mensagem, não só `exit 2`** — um erro de sintaxe no próprio guard também sai 2, e o caso passaria verde com o fallback quebrado.

**Vizinhos:** [#gate-marcador-antes-de-validar](gate-marcador-antes-de-validar.md) — lá o gate se autoaprova; aqui ele perde a voz.

**Ref:** Paid Media Automation, 2026-08-15 — achado pela perna Cross-Claude do conselho, num guard que a perna única tinha aprovado. `jq` já faltou nesta máquina antes (é o workaround #1 do kit para Windows), então não era hipótese.
