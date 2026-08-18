## Deploy de Worker na conta de OUTRA pessoa: 3 armadilhas que param o deploy antes de começar {#deploy-worker-cloudflare-conta-de-cliente}

`tags: cloudflare workers, wrangler, versions upload, token account-owned, 9106, memberships, node_modules velho, dir de build no VPS, preview sem ativar, npm ci`

**Contexto:** publicar um Worker na conta Cloudflare de um cliente, a partir de um dir de build no VPS, sem tocar no site que já está no ar.

---

**1. `wrangler deploy` PUBLICA; quem sobe sem ativar é `wrangler versions upload`.**

Se o objetivo é preview, `deploy` é a ferramenta errada — ele desvia o tráfego de produção na hora. `versions upload` cria a versão, devolve uma *Version Preview URL* própria e imprime *"To deploy this version to production traffic use the command wrangler versions deploy"*. O apex continua servindo o que servia.

Para **segredos** vale o mesmo par: `wrangler secret put` cria versão **e publica**; `wrangler versions secret bulk <json>` cria versão com os segredos **sem ativar**.

> ⚠️ **`wrangler versions secret` existe — medido, não suposto.** Um revisor afirmou que o namespace `secret` não tem variante `versions`. Tem: em **wrangler 3.114.17**, `wrangler versions secret --help` lista `put`, `bulk`, `delete` e `list`, e o `bulk` respondeu `✨ Success! Created version <id> with 3 secrets.` seguido de *"To deploy this version to production traffic use the command wrangler versions deploy"*. Versão fixada aqui porque disponibilidade de subcomando muda entre majors — confira com `--help` antes de assumir ausência **ou** presença. Num Worker que ganhou `main` recentemente, usar o `secret put` distraidamente ativa o código novo no site vivo.

⚠️ **Como provar que o apex não se mexeu:** `md5sum` do HTML servido **antes** e **depois**, e `cmp`. "Abri e parecia igual" não é medição.

---

**2. Token account-owned quebra em `/memberships` (erro 9106) — e o `whoami` NÃO avisa.**

`wrangler whoami` responde bonito e mostra a conta certa, mas `versions upload` e `deployments list` falham com:

```
A request to the Cloudflare API (/memberships) failed.
Authentication failed (status: 400) [code: 9106]
```

`/memberships` é endpoint de **usuário**; um token *account-owned* não o alcança. O wrangler o consulta só para descobrir a conta.

**Solução:** passar `CLOUDFLARE_ACCOUNT_ID` explícito — com ele o lookup é pulado e o comando roda.

⚠️ E o token pode não estar no ambiente: o wrangler carrega o `.env` **do diretório do projeto** por conta própria. Por isso `whoami` funciona no SSH mas `CLOUDFLARE_API_TOKEN=$CF_API_TOKEN` chega vazio — a variável nunca esteve no shell. Ler do arquivo (`grep ^CF_API_TOKEN= .env | cut -d= -f2-`) e conferir só o **tamanho** (`${#VAR} chars`), nunca o valor.

---

**3. `node_modules` velho no dir de build reprova o build, e a mensagem aponta pro lugar certo pelo motivo errado.**

Sintoma: `next build` falha com `Cannot find module '@cloudflare/workers-types'` — mas a dependência **está** no `package.json`. O `package.json` chegou pelo `git archive`; o `node_modules` é de antes.

**Solução:** `npm ci` no dir de build.

🔑 **A generalização:** o verbete vizinho [[docker-context-stale-tree-fails-build]] trata de **fonte** obsoleta no dir de build. Esta é a mesma classe em **dependência** — e a guarda mental "conferi que não há `build-src/`/`src-extract/` sobrando" não cobre, porque a árvore de fontes estava perfeita. Ao reaproveitar dir de build, a pergunta é "o que aqui NÃO veio do archive?", e `node_modules` é a resposta mais comum.
