## Smoke de fluxo de cartão Pagar.me em PROD sem browser/OTP {#smoke-pagarme-card-sem-browser}

`tags: pagarme, billing, smoke, cartao, tokenizacao, docker exec, dotenv, prod, cobranca`

**Quando:** validar que um fix no fluxo de cartão (`createCustomer`/`updateCustomer`/`createCard`)
funciona de verdade contra a API real do Pagar.me em produção, sem precisar de uma sessão de
browser autenticada (OTP) nem reimplementar a UI de tokenização.

**Passos:**
1. Confirme `PAGARME_ENV=test` no `.env` de prod (`grep '^PAGARME_ENV=' .env`) — sem isso qualquer
   chamada real vira cobrança de verdade.
2. **Tokenize o cartão direto**, sem browser: `POST {PAGARME_API_BASE_URL}/tokens?appId={PAGARME_PUBLIC_KEY_TEST}`
   com `{"type":"card","card":{"number":"4000000000000010","holder_name":...,"holder_document":...,
   "exp_month":...,"exp_year":...,"cvv":...}}` — cartão de teste aprovado do Pagar.me v5. Isso é
   exatamente o que o JS do form faria no browser; rodar server-side com a chave pública TEST é
   equivalente e evita orquestrar um Playwright autenticado só pra pegar um token.
3. Escreva um script Python curto que importe as funções do client (`pagarmeClient.updateCustomer`/
   `createCard`) e chame com o token do passo 2 + CPF sintético (`123.456.789-09`) + endereço
   fake — replica a lógica exata da rota HTTP sem precisar da sessão/cookie de auth.
4. **Copie o script pro container rodando** (`docker cp script.py <cid>:/tmp/`) e rode com
   `docker exec <cid> python /tmp/script.py` — **não** `docker exec <cid> env` pra checar as vars
   primeiro, ele não mostra nada carregado via `load_dotenv()` (ver
   `feedback-docker-exec-env-hides-dotenv`). O script precisa importar o módulo que dispara o
   `load_dotenv()` (ex. `execution.database.connection`) ANTES de ler `os.environ`, senão
   `PAGARME_PUBLIC_KEY_TEST` etc. vêm `None`/`KeyError` mesmo estando no `.env`.
5. Aponte pra um tenant de teste já existente com `pagarme_customer_id` real (evita `createCustomer`
   novo) e **não persista** o resultado no banco de prod — o smoke só precisa confirmar que a
   chamada de API sucede (`status=active`), não mutar o tenant real.

**Armadilhas:** confundir "está em test mode" com "pode usar dado de terceiro real" — sempre CPF
sintético/cartão de teste documentado, nunca dado de cliente real, mesmo em `PAGARME_ENV=test`;
esquecer o import que dispara `load_dotenv()` faz o script "funcionar" localmente (fora do
container, onde a env já está no shell) e falhar silenciosamente dentro dele.

**Ref:** tiatendo, sessão 2026-08-07 (fechamento do smoke `PAGARME_ENV=test` de O4b, PROD `0.294.0`);
`feedback-docker-exec-env-hides-dotenv`; [pagarme-erro-rotativo-antifraude](../resolver/pagarme-erro-rotativo-antifraude.md).
