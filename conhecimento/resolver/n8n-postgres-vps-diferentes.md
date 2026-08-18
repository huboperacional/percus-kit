## Credencial n8n apontando pra hostname interno Docker que nunca vai resolver: n8n e Postgres podem estar em VPS diferentes {#n8n-postgres-vps-diferentes}

`tags: n8n credential, postgres host, docker internal hostname, service discovery, DNS de servico externo, firewall bloqueia porta, assumir mesma rede sem verificar, topologia multi-vps`

**Sintoma:** ao criar uma credencial Postgres nova pra um n8n existente, a suposição natural é usar o
hostname interno do Docker Swarm (ex. `postgres_postgres`, o nome do SERVICE) como Host, porque uma
variável de ambiente do próprio n8n (`DB_POSTGRESDB_HOST=postgres_postgres`) parece confirmar isso.
A suposição está ERRADA quando o n8n de fato usado (a URL pública que o operador informa, tipo
`https://xxx.dominio.com.br`) roda numa MÁQUINA DIFERENTE do VPS onde o Postgres está hospedado —
hostname interno de Docker Swarm só resolve dentro da mesma rede overlay, na MESMA máquina.

**Causa raiz:** `DB_POSTGRESDB_HOST` (ou variável equivalente) presente num `.env`
compartilhado/herdado não prova que aquele valor se aplica ao n8n que você está de fato configurando
— pode ser resquício de outro ambiente/instância n8n que roda na MESMA máquina do Postgres. Verificar
isso exige checar a TOPOLOGIA real, não confiar na variável.

**Solução (ordem de verificação, do mais rápido ao mais definitivo):**
1. DNS do hostname público do n8n — se o IP resolvido for DIFERENTE do IP do VPS do Postgres, já
   descarta hostname interno Docker de cara.
2. Testar conexão TCP direta na porta do Postgres a partir de QUALQUER máquina externa (não precisa
   ser o n8n) — se travar/recusar, há firewall bloqueando por design (`iptables -L DOCKER-USER`
   mostra a regra DROP explícita), o que é esperado/correto pra um Postgres compartilhado não devia
   estar exposto cru pra internet.
3. **Mais confiável de todos:** pedir pro operador abrir uma credencial Postgres JÁ EXISTENTE E
   FUNCIONAL no mesmo n8n (se houver outro projeto configurado lá) e olhar o campo Host na UI — a UI
   do n8n mostra host/porta/database/user em texto claro (só a senha é mascarada). Ground truth
   direto, sem precisar adivinhar topologia de rede.

**Trade-off:** pular a verificação e confiar só na variável de ambiente herdada teria produzido uma
credencial que falharia silenciosamente (timeout) só na hora de testar/ativar o workflow — mais caro
de debugar depois do que verificar antes de criar.

**Ref:** Kommo-Disparo-WhatsApp, sessão 2026-08-05 (`execution/setup_n8n_credentials.py`).

**Ref:** Paid Media Automation, cont.150, sessão 2026-08-05.
