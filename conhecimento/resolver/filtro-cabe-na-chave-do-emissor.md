## Ao proteger alguém de um envio, o filtro tem que caber na CHAVE de cada emissor {#filtro-cabe-na-chave-do-emissor}

`tags: emissor, destinatario, filtro, guarda, is_admin, chave de busca, multi-tenant, outbound proativo, varredura`

**Sintoma:** você fecha o vazamento num emissor e replica "o mesmo filtro" nos outros. Um deles
continua alcançando quem deveria estar protegido — e o teste do filtro copiado passa.

**Causa raiz:** cada emissor encontra o destinatário por uma **chave diferente** (conversa, telefone,
tabela de clientes, JID de configuração). Uma marca gravada em UMA dessas entidades (ex.: uma coluna
`is_admin` na tabela de conversas) simplesmente não alcança o emissor que busca por outra chave —
registros criados por canais que nascem sem aquela entidade (loja web, painel) ficam órfãos e passam
pelo filtro sem nem serem avaliados.

**Solução:** ao varrer emissores, responda DUAS perguntas por emissor, não uma: (1) ele pode alcançar
quem quero proteger? (2) por qual CHAVE ele acha o destinatário? O filtro mora na chave dele — e onde
duas chaves coexistem, a guarda é dupla. Comparação de telefone é sempre por DÍGITOS
(`regexp_replace(x,'[^0-9]','','g')`): um lado guarda E.164 com `+` e o outro sem, e comparar cru casa
ZERO linhas **passando como sucesso** — falha silenciosa.

**Ref:** tiatendo `0.258.0` (2026-07-29); `scripts/auditAdminReach.py` mediu 0 ocorrências ANTES do
fix — medir também serve pra saber que não há o que consertar.
