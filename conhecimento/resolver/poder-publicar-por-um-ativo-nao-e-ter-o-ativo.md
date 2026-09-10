## Poder PUBLICAR por um ativo não é TER o ativo — e a mensagem de erro esconde isso {#poder-publicar-por-um-ativo-nao-e-ter-o-ativo}

`tags: meta, business manager, ativo, pagina, instagram, publico personalizado, engajamento, mensagem de erro enganosa, permissao, R23`

**Sintoma:** uma conta de anúncios publica normalmente por uma Página (os anúncios rodam, o
`page_id` aparece no criativo, tudo entrega), mas criar um **público de engajamento** dessa mesma
Página falha. Pior: a mensagem culpa outra coisa. No Meta, ela diz *"Nome do evento inválido para o
público personalizado: o nome do evento deve ter menos de 50 caracteres e só pode conter
caracteres alfanuméricos e sublinhados"* — sobre `page_engaged`, que tem 13 caracteres e é o nome
correto.

**Reprodução real** (D4U, 2026-09-09): o payload foi copiado **byte a byte** de um público que
existe e tem 57.000 pessoas noutra conta do mesmo cliente:

```json
{"inclusions":{"operator":"or","rules":[{"event_sources":[{"type":"page","id":1379770285438561}],
 "retention_seconds":31536000,
 "filter":{"operator":"and","filters":[{"field":"event","operator":"eq","value":"page_engaged"}]}}]}}
```

Mesmo assim: recusa. O que separa as duas contas não está no payload:

| pergunta | resposta na conta que funciona | na que falha |
|---|---|---|
| a conta pode publicar pela Página? | sim | **sim** (`promote_pages` lista, 6 anúncios usam) |
| o Business Manager TEM a Página? | sim | **não** (`owned_pages` e `client_pages` vazios) |

`GET /{page_id}?fields=business` mostrou que a Página pertence a **outro** BM. Publicar foi
concedido; **possuir**, não. Público de engajamento se constrói a partir do ativo, então exige a
segunda coisa.

**Como diagnosticar em 2 chamadas**, antes de mexer no formato da regra:

```bash
GET /{page_id}?fields=business                 # de quem é o ativo
GET /{business_id}/owned_pages                 # o BM da conta tem alguma página?
GET /{business_id}/client_pages                # ou acesso a alguma?
```

Vazio nas duas = não adianta ajustar a regra; falta o ativo.

**Saída que funcionou sem depender do cliente:** o público equivalente já existia na conta que
pertence ao BM dono, e público personalizado **pode ser compartilhado entre contas de anúncio** —
`POST /{audience_id}/adaccounts` com `adaccounts=["<id>"]`. ⚠️ **Ids sem o prefixo `act_`**: com
`act_` o Meta responde *"Param adaccounts[0] must be a valid ID string"*. Depois disso o público
aparece na outra conta e pode ser usado como semente. Para o Instagram não houve saída: não havia
público equivalente em conta nenhuma, e criá-lo esbarra no mesmo ativo faltando.

**Why:** é a mesma família de "dar acesso ao pixel ≠ conectar o pixel à conta de anúncio" — a
plataforma tem vários níveis de relação com o mesmo objeto, e conseguir uma operação não prova as
outras. Diagnosticar pela mensagem de erro leva a gastar horas no formato do payload, que estava
certo desde o início.

**How to apply:** ao ver erro de formato num payload que você copiou de algo que funciona, pare de
mexer no payload e vá medir a **relação com o ativo**. E, ao relatar a pendência, escreva
exatamente qual relação falta — "compartilhar a página" é ambíguo, "adicionar a Página como ativo
do BM X" não é.
