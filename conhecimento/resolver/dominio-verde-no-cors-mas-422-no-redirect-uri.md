## Domínio novo passa no CORS e ainda dá `422 redirect_uri not allowed` {#dominio-verde-no-cors-mas-422-no-redirect-uri}

`tags: auth-service, redirect_uri, magic-link, allowlist, cors, domains.yaml, audiences.origins, default_redirect_uri, migracao de dominio, 422, quebra silenciosa, frontend_url, convite, sso`

**Sintoma:** um produto migra o domínio do frontend (`app2.x.com` → `app.x.com`) e atualiza o
`FRONTEND_URL`. O **login normal continua funcionando**, mas convite de usuário, confirmação de
onboarding e callback de SSO param — todos com `422 {"detail":"redirect_uri not allowed for this
audience"}` vindo de `POST /auth/magic/issue`. Fica dias sem ninguém notar, porque o caminho quente
está intacto.

**Causa raiz:** no auth-service existem **duas allowlists de domínio independentes**, e migrar numa
não migra na outra:

| camada | onde mora | decide |
|---|---|---|
| CORS | `infra/domains.yaml` → `cors_allowed_origins` (global, entra na imagem via `cors-sync.py`) | se o **browser** consegue chamar o auth |
| `redirect_uri` | `auth.audiences.origins` (row por audience, no banco) | se o **magic-link** pode apontar pra lá |

O domínio novo em geral já está no `domains.yaml` (alguém lembrou do CORS), então **o preflight passa
verde e o `cors-smoke` dá 100%** — e o `magic/issue` recusa assim mesmo. Verde numa camada não diz
nada sobre a outra.

Por que o login não denuncia: `POST /otp/request` **não manda `redirect_uri`**. Só os fluxos que
mintam magic-link a partir do `FRONTEND_URL` do consumer passam pelo allowlist — convite,
promote/confirm, SSO. São de baixa frequência, então a quebra é invisível.

**O terceiro lugar, quase sempre esquecido:** o **`default_redirect_uri`** da mesma row, usado quando
o chamador **não** manda `redirect_uri`. Apontando pro domínio velho ele não quebra enquanto o antigo
estiver no ar — vira armadilha que dispara sozinha no dia do desligamento.

**Solução:** uma migration que faz as **duas** mudanças na row, com `UPDATE` guardado pelo valor
esperado (idempotente, e não sobrescreve ajuste manual):

```sql
UPDATE auth.audiences
   SET origins = origins || ARRAY['https://app.x.com']::text[]
 WHERE audience = '<slug>' AND NOT (origins @> ARRAY['https://app.x.com']::text[]);

UPDATE auth.audiences
   SET default_redirect_uri = 'https://app.x.com/open'
 WHERE audience = '<slug>' AND default_redirect_uri = 'https://app2.x.com/open';
```

**Mantenha o domínio antigo no allowlist** até o consumer confirmar que ele saiu do ar: adicionar é
aditivo e reversível, remover no meio da migração quebra quem ainda aponta pra lá. Antes de mexer no
`default_redirect_uri`, confirme que a rota de aterrissagem responde `200` no domínio novo.

**Verificação — o teste feliz não basta.** "Passou a aceitar" e "passou a aceitar tudo" dão o mesmo
`201`. Rode os três:

1. o `redirect_uri` que falhava → `201`;
2. os domínios que já funcionavam → ainda `201` (não regrediu);
3. **controle negativo com ataque de sufixo**: `https://app.x.com.evil.com/open` → tem que dar `422`.
   Se passar, a checagem virou substring em vez de origin exata.

**Relacionado:** [Métrica que dá o MESMO valor extremo pra população inteira é bug da medição](medicao-uniforme-na-populacao-inteira-e-bug-da-medicao.md)

**Ref:** Plexco Tasks, migração `app2.plexco.com.br` → `app.plexco.com.br`, 2026-09-01. Migration
`026_plexco_tasks_app_domain` no auth-service; validação em `redirect_uri_allowed()`
(`app/modules/magic/web.py`). O consumer mandou `file:line` do lado dele, o request exato e o
controle com o domínio antigo — foi isso que tornou o conserto direto.
