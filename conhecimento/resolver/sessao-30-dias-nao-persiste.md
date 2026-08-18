## Sessão de 30 dias que "não persiste": como provar de que lado está o defeito {#sessao-30-dias-nao-persiste}

tags: refresh token, rotacao, sessao de 30 dias, re-OTP, cold start, descarte em falha transitoria,
clearTokens, delete_cookie, 401 e so, 422 RequestValidationError, rolling update, localStorage entre
abas, AbortController, auth-service, consumer

**Origem:** auth-service, 2026-07-25 → 07-30. Operador reportou re-OTP "em todos os projetos".
Resultado: **6 de 7 consumers** tinham o mesmo defeito, o auth estava correto.

### A métrica que decide (não use auditoria de código)

Auditoria de código dá **falso PASS**. A prova é a **rotação do refresh token em produção**. No
auth-service, via `scan_iter("auth:refresh:*")` + payload JSON de cada chave:

- **rotações** = tokens com `used_at` preenchido.
- **vida da família** = `max(created_at) - min(created_at)` da mesma família = quanto tempo aquela
  sessão se sustentou renovando.
- `parent_id=None` + `used_at=None` + 1 token = **família criada no login que nunca renovou**.

Leitura: vida mediana **0,0h** = o `rt` é emitido e nunca usado. Sessões de **20+ dias vivas** em
outro consumer = prova positiva de que o servidor está correto (use isso pra inocentar o auth em
vez de argumentar).

### Os dois defeitos que o checklist ingênuo não pega

1. **COLD START** — o refresh só existe no caminho reativo (interceptor de 401). No boot **não sai
   request nenhuma** → não há 401 → não há refresh → tela de login com o `rt` de 30 dias intacto no
   storage. "Renova no 401?" passa e a sessão morre assim mesmo.
   *Teste de 30s:* apagar **só o access token**, F5 com Network aberto. Tem que sair
   `POST /token/refresh` → 200.

2. **DESCARTE EM FALHA TRANSITÓRIA (o dominante)** — `clearTokens()` / `delete_cookie()` em
   **qualquer** não-2xx ou no `catch` de rede/timeout. Um 502 de 3s destrói a sessão de 30 dias.
   **Não vira incidente: vira "o pessoal anda relogando mais".** O gatilho mais comum é o **próprio
   rolling update do serviço de auth** (segundos de 502 no proxy), então atinge **todo mundo ao
   mesmo tempo**.
   *Regra:* descartar credencial **só** quando o servidor **confirma** sessão morta. No contrato
   Percus isso é **`401` e só** — `403` não é emitido nessa rota e **`422` é o
   `RequestValidationError` do FastAPI** (body malformado = drift de contrato). Com 422 na lista, o
   dia em que o schema mudar apaga a sessão de **todos os usuários de todos os produtos**.

3. **A segunda metade, que todo mundo esquece:** consertar o `doRefresh` preserva a credencial
   (resolve o **custo**), mas se o **chamador** tratar todo `null` como sessão morta o usuário
   continua sendo **expulso** pro `/login` (a **interrupção**). Exige as duas metades.

### Armadilhas de sinal (custaram bug real)

- **Não use "ainda existe refresh token?" como prova de falha transitória** — o interceptor pode ter
  **rotacionado** logo antes, e aí uma identidade rejeitada (conta desativada, token válido)
  rotacionaria pra sempre sem nunca deslogar. Use estado **por aba** (contador de refreshes OK).
- **`localStorage` é compartilhado entre abas** — "o token mudou?" é sinal contaminado, e uma aba
  parada reapresentando o `rt` velho **queima a família** da aba que acabou de renovar.
- Quem passar a **aguardar** o refresh no boot precisa de **timeout** (`AbortController`), senão
  troca re-OTP por tela branca. O abort conta como transitório.
