## `1/1` no Swarm não significa roteável — e o 404 provoca rollback à toa {#swarm-1de1-nao-significa-roteavel}

`tags: docker swarm, traefik, deploy, 404, rollback, gate, service update, converged, healthcheck`

**Contexto:** `docker service update` converge, `docker service ls` mostra `1/1`, você verifica as
rotas e recebe **404 em tudo**. A conclusão natural — "o deploy quebrou o app" — está errada.

**O que `1/1` diz:** a task subiu. **O que ele não diz:** que o Traefik já a descobriu e registrou o
router. Medido: **~15 segundos** entre o `1/1` e a primeira resposta 200.

**Custo real de errar isso:** um rollback desnecessário em produção. A imagem estava íntegra o tempo
todo — confirmado depois com
`docker run --rm --entrypoint sh <img> -c "ls /usr/share/nginx/html"`, comparando com a versão
anterior.

**Gate correto — poll até o código esperado, NUNCA `sleep` fixo:**

```bash
for i in $(seq 1 18); do
  code=$(curl -s -o /dev/null -w "%{http_code}" https://host/rota)
  [ "$code" = "200" ] && break
  sleep 5
done
```

**Antes de reverter por 404, separe as duas hipóteses:** 404 do Traefik (sem backend registrado) ou
404 do app (build ruim). Inspecionar o conteúdo da imagem responde em segundos e não custa downtime.
