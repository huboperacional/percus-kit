## `iptables DOCKER-USER` bloqueando 100% do tráfego externo pra uma porta publicada, sem exceção nenhuma (nem pro seu próprio serviço) {#docker-user-drop-total-sem-excecao}

`tags: iptables, docker-user, firewall, porta bloqueada, connection timed out, postgres, 5432, docker swarm, porta publicada, DROP, sem excecao, n8n nao alcanca postgres, vps compartilhado`

**Sintoma:** um serviço com porta publicada via Docker (`*:5432->5432/tcp` no `docker service ls`)
está saudável, a porta está exposta, mas QUALQUER tentativa de conexão externa (inclusive de outro
serviço legítimo no MESMO ecossistema, rodando noutro VPS) trava com `Connection timed out` — não
`connection refused` (que indicaria porta fechada), timeout mesmo, consistente por dias, não
intermitente.

**Causa raiz:** regra `DROP` na chain `DOCKER-USER` do iptables (`iptables -L DOCKER-USER -n
--line-numbers`) bloqueando `0.0.0.0/0` pra essa porta, **sem nenhuma regra `ACCEPT` antes dela**
pra nenhum IP — nem pro consumidor legítimo do próprio ecossistema. `DOCKER-USER` é a chain que o
Docker usa pra filtrar tráfego destinado a portas publicadas, e roda ANTES das regras normais de
`INPUT`/`FORWARD` — um `DROP` ali bloqueia mesmo que tudo o mais pareça liberado.

**Como confirmar sem adivinhar:** `iptables -L DOCKER-USER -n --line-numbers` direto no VPS que
hospeda o serviço (não no cliente que está tentando conectar — de lá só se vê o timeout, não a
causa). Se aparecer só uma linha `DROP ... dpt:<porta>` sem `ACCEPT` antes, é isso.

**Solução (mínima, escopada — não abrir a porta geral):** inserir uma regra `ACCEPT` pro IP
específico do consumidor legítimo, ANTES da regra de `DROP` (posição 1): `iptables -I DOCKER-USER 1
-s <IP do consumidor> -p tcp --dport <porta> -j ACCEPT`. Mantém o bloqueio geral pra todo o resto —
não é "abrir a porta", é adicionar uma exceção pontual.

**Cuidado — isto é mudança de firewall em infra COMPARTILHADA:** confirme com o operador (ou quem
administra o VPS) antes de aplicar; é uma ação difícil de reverter cegamente e que afeta outros
consumidores do mesmo host. Não presuma que "existe uma credencial configurada com esse host" prova
que a conexão já funcionou de verdade — pode ter sido só o campo da UI confirmado visualmente, nunca
testado ao vivo.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-11/12 (VPS compartilhado 161.97.129.138, administrado pelo
projeto irmão `Melhoria na VPS`) — um achado ANTERIOR no mesmo projeto (sessão de 2026-08-05) já
tinha tropeçado nessa mesma regra ao testar a porta de fora, mas foi contornado assumindo que uma
credencial existente "confirmava" que funcionava, sem teste ao vivo — o bloqueio ficou sem corrigir
por mais uma semana até essa entrada.
