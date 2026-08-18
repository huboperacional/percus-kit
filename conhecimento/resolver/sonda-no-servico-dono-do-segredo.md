## Worker precisa de segredo que outro serviço cifrou → sonda roda DENTRO do serviço dono (endpoint interno fail-closed) {#sonda-no-servico-dono-do-segredo}

`tags: segredo cifrado, criptografia divergente, AES-GCM, AES-CBC, scrypt, master key, blast radius, endpoint interno, X-Internal-Auth, hmac.compare_digest, constant-time, fail-closed, traefik host rule, exposto na internet, worker, monitor de saude, degradar nao abortar`

**Sintoma:** job agendado no worker precisa validar/usar credenciais de tenant cifradas por OUTRO serviço, e a descriptografia falha ou exigiria copiar a master key. Causa-raiz típica: criptos diferentes por design (Paid Media: worker = AES-CBC + scrypt de `ENCRYPTION_KEY`; tracking = AES-GCM + `PMT_MASTER_KEY`). Copiar a chave amplia blast radius; duplicar a lógica de probe cria drift.

**Solução:**
1. A sonda roda DENTRO do serviço dono do segredo, reusando o módulo existente (ex.: `credential_test.py`), exposta num endpoint interno (`POST /internal/...`).
2. Auth por header de segredo compartilhado (`X-Internal-Auth`) com `hmac.compare_digest` (constant-time) e **fail-closed**: env ausente ⇒ 403 SEMPRE, travado por teste.
3. ⚠️ Se o Traefik roteia o serviço por **Host rule**, `/internal` é alcançável da INTERNET — o header é o único gate; "rede interna" não protege nada. Smoke obrigatório: curl público sem header ⇒ 403.
4. O cliente no worker NUNCA levanta exceção (serviço fora ⇒ elo degrada pra `desconhecido`, não aborta a varredura) e retorna `(resultado, motivo_erro)`.

**Ref:** Paid Media Automation, 2026-07-20, fatia 2 do monitor de saúde (elo credencial). Memória: `project_tracking_health_monitor_fatia2`.
