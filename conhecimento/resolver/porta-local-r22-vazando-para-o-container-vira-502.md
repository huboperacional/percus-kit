## Porta local do R22 vazando para o script `start` vira 502 no Swarm {#porta-local-r22-vazando-para-o-container-vira-502}

`tags: 502, traefik, docker swarm, next start, porta, R22, PERCUS_PORT_BASE, deploy, bad gateway, R23`

**Sintoma:** o serviço sobe, `docker service ls` mostra `1/1`, o log da aplicação
diz `✓ Ready`, o certificado TLS está emitido e o domínio responde — mas toda
rota devolve **502 Bad Gateway**. Nada no log da aplicação indica erro, porque do
ponto de vista dela está tudo certo.

**Causa:** o bloco de portas locais alocado pelo R22 (`PERCUS_PORT_BASE`) foi
parar no script `start` do `package.json`, e não só no `dev`:

```json
{
  "dev": "next dev --port 3180",
  "start": "next start --port 3180"
}
```

O contêiner então escuta na 3180, enquanto o label do Traefik aponta para a porta
canônica do serviço:

```yaml
- traefik.http.services.<app>.loadbalancer.server.port=3000
```

O Traefik encaminha para 3000, ninguém atende, e ele devolve 502. **Não é erro de
rede, de TLS nem de DNS** — é a aplicação escutando no lugar errado.

**Por que passa despercebido:** localmente funciona perfeitamente, porque em dev
o navegador vai direto na 3180. O erro só aparece no primeiro deploy, e como o
log da aplicação está limpo, a investigação começa pelo Traefik e pelo
certificado — os dois lugares errados.

**Diagnóstico em um passo:** compare o que a aplicação diz no log com o label do
Traefik.

```bash
docker service logs <stack>_web --tail 5 | grep -i "local\|port"
#   - Local:  http://localhost:3180     <- aqui está a resposta
docker service inspect <stack>_web --format '{{json .Spec.Labels}}' | grep -o 'server.port=[0-9]*'
#   server.port=3000
```

**Correção:** a porta do R22 é alocação **da máquina de desenvolvimento**, para
que dois projetos Percus não colidam em `npm run dev`. Ela não tem significado
nenhum dentro do contêiner, que é isolado por definição.

```json
{
  "dev": "next dev --port 3180",
  "start": "next start"
}
```

`next start` usa 3000 por padrão e respeita a variável `PORT`, então o contêiner
fica alinhado com o label sem precisar de configuração extra.

**Regra geral:** porta local alocada pelo R22 entra apenas em `dev`, `preview`,
`storybook` e afins. Em `start`, `docker-compose` e labels de Traefik, vale a
porta canônica do serviço.
