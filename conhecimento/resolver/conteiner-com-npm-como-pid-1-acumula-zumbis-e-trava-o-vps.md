## Site lento com a página saindo do cache: contêiner com `npm` como processo principal acumula zumbis e rouba CPU do VPS inteiro {#conteiner-com-npm-como-pid-1-acumula-zumbis-e-trava-o-vps}

`tags: docker, swarm, zombie process, zumbi, npm start, pid 1, init true, tini, cpu steal, psi, pressao
de cpu, iowait, load average, vps compartilhado, lentidao, ttfb alto, next cache hit, evolution api`

**Sintoma:** o site responde em 1–2,5 s, mas a página já sai pronta do cache (`X-Nextjs-Cache: HIT`,
`X-Nextjs-Prerender: 1`) e o contêiner do app está com ~0% de CPU. Mesmo **dentro** do contêiner
(`docker exec … node -e "fetch('http://127.0.0.1:3000/')"`, sem proxy nem TLS) a resposta varia de 130 a
1500 ms. No host: `load average` perto do número de núcleos, `%Cpu` com `sy` alto (16–33%) e `wa` alto
(até 22%) e `us` baixo; `top` mostra **mil+ processos zumbis** (`1370 zombie`); `/proc/pressure/cpu`
com `avg300` acima de 15–20%.

**Causa raiz:** um contêiner **de outro projeto** no mesmo VPS roda `npm run start:prod` (ou `npm start`)
como processo principal. O `npm` não faz o papel de `init`: não recolhe os filhos que terminam, e cada
processo que a aplicação dispara e encerra vira zumbi. Os zumbis não gastam CPU sozinhos, mas a criação
contínua de processos e a tabela de processos inchada custam tempo de kernel — e todos os contêineres
passam a esperar CPU. O app "lento" era vítima, não causa.

**Como achar o culpado** (só leitura):

```bash
ps -eo ppid=,stat= | awk '$2 ~ /^Z/ {print $1}' | sort | uniq -c | sort -rn | head -5
# para cada ppid: nome do contêiner pelo cgroup
grep -o "docker[-/][0-9a-f]\{12\}" /proc/<ppid>/cgroup | head -1
docker ps --no-trunc --format "{{.ID}} {{.Names}}" | grep "^<id12>"
```

Conte duas vezes com alguns minutos de intervalo: se o número sobe, o vazamento está ativo.

**Solução:**
- **Imediata (com o "sim" do dono do serviço):** reiniciar ou desligar o serviço culpado. `docker service
  scale <servico>=0` mata o processo pai e o host recolhe os zumbis na hora (1433 → 2 no caso real). É
  reversível com `scale=1`, mas o vazamento volta.
- **Definitiva:** `init: true` no serviço do stack (o Docker põe o `tini` como PID 1, que recolhe filhos),
  ou `CMD ["node", "dist/main.js"]` direto em vez de `npm start`, ou `tini`/`dumb-init` no `ENTRYPOINT`.
- **Confirmar:** zumbis ~0, `vmstat` com `id` alto e `wa` 0, PSI caindo, e o tempo dentro do contêiner do
  app voltando a dezenas/centenas de ms.

**Armadilhas:**
- O primeiro suspeito — o contêiner com mais `%CPU` no `docker stats` — pode ser só pico. Tire uma segunda
  amostra; no caso real ele estava em 0,02% minutos depois.
- Tempo de fora do site mistura distância (VPS longe dá ~250 ms de ping, meio segundo só de TCP + TLS) com
  tempo de servidor. Meça o tempo **dentro** do contêiner para separar as duas coisas.
- Mudar serviço de outro projeto é ação externa: no padrão Percus exige a janela R20
  (`.percus/acao-externa-autorizada.json`) com a frase do operador — o override de ambiente só passou nas
  leituras.

**Ref:** LiliCalc, 2026-09-14 — `evolution_evolution-api` (`evoapicloud/evolution-api:v2.3.7`) no VPS
compartilhado; registro em `CL_LiliCalc/docs/historico/2026-09-14-r20-desativar-evolution-consumida.json`.
Relacionado: [servidor-dev-zumbi-porta-netstat-mente](servidor-dev-zumbi-porta-netstat-mente.md).
