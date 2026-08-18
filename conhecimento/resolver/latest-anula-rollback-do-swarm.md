## Tag `latest` no stack do Swarm anula o `failure_action: rollback` que está escrito ao lado {#latest-anula-rollback-do-swarm}

tags: docker, swarm, stack, rollback, latest, tag imutavel, deploy, update_config, failure_action, healthcheck

**Sintoma.** O `docker-stack.yml` declara `update_config: {failure_action: rollback}`, o deploy novo
sobe quebrado, o Swarm executa o rollback — e o serviço **continua quebrado**. O log diz
`rollback_completed` e não voltou nada.

**Causa.** O rollback do Swarm restaura a **spec anterior**, não a imagem anterior. Se a spec antiga
também diz `imagem:latest`, ela é reavaliada agora — e `latest` aponta para a imagem recém-buildada,
que é exatamente a que falhou. O rollback roda, obedece, e reinstala o defeito.

**Correção.** Tag imutável por deploy, injetada por variável:
```yaml
image: meu-servico:${MEU_TAG:?defina MEU_TAG com a tag construida}
```
```bash
TAG=$(date +%Y%m%d-%H%M%S)
docker build -t "meu-servico:$TAG" .
export MEU_TAG="$TAG"; docker stack deploy -c docker-stack.yml minha-stack
```
O `:?` faz o deploy **falhar** em vez de silenciosamente cair num default — sem ele, `${MEU_TAG}`
vazio vira `meu-servico:` e o Swarm resolve para `latest` de novo.

**O irmão deste defeito, e ele anda junto:** serviço **sem `healthcheck`** faz o `failure_action`
nunca disparar. O Swarm só sabe "o processo morreu"; um servidor de pé respondendo 500 em toda rota
conta como saudável, e o deploy quebrado é declarado bem-sucedido. Se você escreveu
`failure_action: rollback`, precisa de uma condição de saúde que signifique alguma coisa —
`HEALTHCHECK` no Dockerfile ou `healthcheck:` no stack, ao lado da política que o usa.

**Verificação de que o script de deploy não mente:** `curl -s` sai com código **0** num 500. Use
`curl -fsS`, e cheque a convergência explicitamente (`[ "$replicas" = "1/1" ] || exit 1`) — sem isso
o script imprime "publicado" com o serviço parado em 0/1.
