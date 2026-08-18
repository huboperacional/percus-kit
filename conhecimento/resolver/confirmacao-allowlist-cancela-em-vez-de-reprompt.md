## Fluxo de confirmação com allowlist fixo cancela silenciosamente em vez de reprompt {#confirmacao-allowlist-cancela-em-vez-de-reprompt}

tags: confirmacao, bot, whatsapp, allowlist, sim nao, is_affirmative, is_negative, cancelamento silencioso, ux, fonte unica, correcao ambigua, reprompt

**Sintoma:** print de conversa real (usuário reporta bug): bot pede confirmação ("Responda *sim*
pra confirmar"), usuário responde algo que NÃO é "sim" mas também não é uma recusa de verdade — no
caso real, uma tentativa de CORRIGIR um dado errado no card ("Banco do Brasim" tentando consertar
um nome extraído errado). O bot trata isso como recusa e cancela: "Beleza, não cadastrei a dívida."
— sem avisar que não entendeu, perdendo o contexto e forçando o usuário a recomeçar do zero.

**Causa raiz:** o handler do estado de confirmação usava um **allowlist fixo** (`resp not in
("sim","s","confirmar","isso","pode","claro")` → cancela) em vez da fonte única de
afirmativo/negativo já estabelecida no projeto (`is_affirmative`/`is_negative`, com um TERCEIRO
resultado — indeterminado — que outros fluxos de confirmação do MESMO projeto já tratavam
corretamente com reprompt, não cancelamento). O fluxo novo (Dívida) foi escrito do zero em vez de
reusar o padrão já provado; um allowlist binário não tem como representar "não entendi", só
"sim"/"não" — qualquer coisa fora do allowlist vira "não" por construção.

**Solução:** confirmação com resposta em linguagem natural precisa de TRÊS resultados, não dois:
afirmativo → confirma; negativo explícito → cancela; **indeterminado → REPROMPTA mantendo o estado/
sessão vivo**, nunca cancela por default. Se o projeto já tem uma fonte única de classificação sim/
não (regex, `is_affirmative`/`is_negative`, ou equivalente) usada por outro fluxo de confirmação,
qualquer fluxo NOVO de confirmação deve reusá-la — não reinventar um allowlist ad-hoc. Teste que
prova a correção: mandar uma resposta plausível-mas-não-reconhecida (não é nem "sim" nem "não" óbvio)
e assertar que o estado NÃO foi limpo (sessão sobrevive) e a resposta não contém a mensagem de
cancelamento.

**Ref:** Família Milionária, sessão 2026-08-07 — `processDividaConfirmation` em
`familia-api/app/modules/whatsapp/divida_flow.py`, commit `4b6d127`. Fix trocou o allowlist por
`is_affirmative`/`is_negative` de `app.modules.whatsapp.intents` — mesma fonte já usada pela
confirmação de Lançamento (`_processConfirmation`) e por `processDividaSelection` no MESMO arquivo,
nunca adotada por `processDividaConfirmation`. Smoke ao vivo em prod reproduzindo a conversa exata
do print: 9/9 PASS.
