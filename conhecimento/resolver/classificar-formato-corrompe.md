## Ambiguidade de dado (2 formas válidas do mesmo identificador) — classificar por formato corrompe {#classificar-formato-corrompe}

`tags: ambiguidade, telefone, 9 digito, identity, dedup, classificacao, formato, ATO, merge, probe, ground-truth, ninth digit, phone number`

**Contexto:** um identificador tem 2 formas válidas de representar a MESMA entidade (ex.: telefone BR
com/sem 9º dígito), e o sistema precisa decidir se duas formas são "a mesma pessoa" pra fins de
dedup/login/merge. Sintoma: usuário legítimo travado (`no_account`/login falha) porque a conta foi
gravada numa forma e o sistema não reconhece a outra forma como a mesma pessoa.

**Causa raiz:** a tentação óbvia é "classificar o formato" (ex.: `libphonenumber.number_type()`) pra
decidir se uma forma ambígua deveria convergir pra outra. **Isso corrompe dados silenciosamente**: testado
empiricamente (auth-service, 2026-07-06/07) — 8/8 números fixos brasileiros reais, ao inserir o 9º dígito,
passam a classificar como MOBILE no libphonenumber (a formatação estrutural bate, o dado real não). Um gate
"promove se a forma-B classificar como tipo-X" promove **praticamente tudo**, incluindo dado que não deveria
convergir → risco de merge cross-pessoa (classe ATO/vazamento de identidade).

**Um "probe" sozinho (ex.: sondar se o WhatsApp responde numa forma) também NÃO fecha o problema:**
"não há resposta agora" não prova "não há dono nunca" (dono real pode estar com o dispositivo desligado no
momento do probe) — abre uma classe de risco mais sutil (sequestro adiado: quando o dono real aparecer
depois, o sistema já atribuiu o identificador a outra pessoa).

**Solução:** nunca decidir convergência por classificação/formato. Confiar SÓ em **prova real e positiva**
já observada pelo sistema (ex.: entrega confirmada, autenticação bem-sucedida completada) como sinal de
"essas duas formas são a mesma entidade" — nunca inferir a partir do dado em si. Quando essa prova real
também alimenta um mecanismo de escrita/aprendizado automático, adicionar uma trava de colisão (nunca
gravar um valor que já pertence a OUTRA entidade) antes de persistir, mesmo que o sinal pareça confiável.

**Ref:** `D:\Claud Automations\auth-service\docs\superpowers\specs\2026-07-07-delivery-confirmed-identity-matching-design.md`.
Memória: `phone_write_canon_9digito_2026-07-06`. 3 achados adversariais reais na mesma sessão (conselho
pre-mortem + 2× Cross-Claude CRÍTICO) até chegar nessa formulação — não pule a revisão adversarial em
domínio de identidade/auth.
