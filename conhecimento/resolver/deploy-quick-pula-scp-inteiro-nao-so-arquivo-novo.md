## Deploy `--quick` pula o SCP INTEIRO, não só "arquivo novo" — código antigo compila e roda sem erro {#deploy-quick-pula-scp-inteiro-nao-so-arquivo-novo}

tags: deploy, scp, quick, docker build, footgun, stale code, cache, chunk hash, next.js, rebuild com codigo antigo

**Sintoma:** fix commitado, testado, `npm run build` local passa, `deploy_frontend_v2.py --quick`
roda sem erro, "Deploy complete!", `/health` ok — e o bug **continua no ar**, idêntico a antes do
fix. Nenhum erro em lugar nenhum; parece que o deploy "não pegou" por acaso.

**Causa raiz:** `--quick` foi desenhado (comentário no próprio script) pra pular só o SCP quando
"nenhum arquivo mudou" — mas na prática o parâmetro pula o passo de sincronização **por completo**,
incondicionalmente, sempre que passado, e reconstrói a imagem Docker **a partir do código já
presente na VPS** (do deploy anterior). Se o código local mudou desde o último deploy full — mesmo
sendo um arquivo MODIFICADO, não novo — o build na VPS usa a versão VELHA, produz um bundle/imagem
igualmente "válido" (compila, sobe, health-check passa) mas sem o fix. Confirmado inspecionando o
hash do chunk JS servido em prod vs. o hash do build local: divergiam mesmo após "deploy bem-
sucedido". A doc antiga ("`--quick` PULA SCP, arquivo NOVO exige FULL") estava incompleta — não é
só arquivo novo, é QUALQUER mudança não sincronizada antes.

**Solução:** depois de um fix, o PRIMEIRO deploy que o carrega tem que ser FULL (sem `--quick`),
mesmo que o footgun de uplink degradado torne isso mais lento/arriscado. Pra confirmar que o deploy
realmente pegou o código novo: comparar o hash do arquivo/chunk servido em prod (via `fetch()` no
console ou `docker exec <container> ls` no diretório de build) contra o hash do build local — nunca
confiar só em "Deploy complete!" + `/health` ok, porque um deploy com código velho passa exatamente
pelos mesmos checks que um com código novo.

**Ref:** Família Milionária, sessão 2026-08-07 — `execution/deploy_frontend_v2.py`. Descoberto
debugando por que o fix do bug de preço (ver entrada acima) continuava reproduzindo em prod mesmo
após "deploy completo": `docker exec <container> ls .next/static/chunks/app/assinatura/` mostrou o
hash do chunk ANTIGO mesmo com uma imagem Docker nova e com timestamp recente — o Dockerfile builda
a partir do código NO DISCO da VPS, que só é atualizado pelo passo de SCP que `--quick` pula.
