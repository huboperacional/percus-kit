## Variável no `.env` mas fora do `docker-compose.yml` não chega no container — e a que está no compose sem valor chega como string vazia {#env-no-dotenv-mas-fora-do-compose-nao-chega-no-container}

`tags: docker, docker-compose, env, swarm, deploy, string vazia, nullish coalescing, R23`

Dois modos de falha vizinhos, ambos silenciosos, ambos em compose que **enumera** variáveis em vez
de usar `env_file`.

**Modo 1 — a variável nunca chega.** O compose lista cada env à mão:

```yaml
environment:
  - GHL_PIT_TOKEN=${GHL_PIT_TOKEN:-}
```

Se a feature nova lê `process.env.MINHA_VAR` e ninguém acrescentou a linha correspondente, pôr
`MINHA_VAR=` no `.env` da VPS **não interpola em lugar nenhum**. O `.dockerignore` normalmente
mantém o `.env` fora da imagem, então não há segunda via. O container sobe sem a variável e o
código cai no ramo de "não configurado".

**Por que é caro:** o ramo de não-configurado costuma ser um caminho de degradação pensado para ser
raro. Se ele vira o caminho rotineiro, o comportamento de exceção passa a ser o normal — no caso que
gerou este verbete, todo cadastro caía no fallback que mandava CPF, endereço e chave PIX por
WhatsApp, exatamente o oposto da propriedade que o desenho protegia.

**Modo 2 — a variável chega vazia.** `${VAR:-}` significa "use `$VAR`, ou string vazia se não
existir". Então uma variável ausente do `.env` **não chega como `undefined`** — chega como `""`.
Isso quebra o reflexo de usar `??`:

```js
const secret = process.env.OTP_HMAC_SECRET ?? gerarFallback();   // ERRADO: "" passa
const secret = process.env.OTP_HMAC_SECRET || gerarFallback();   // certo
```

`??` só cai no fallback com `null`/`undefined`. Com `""`, um HMAC vira `HMAC(key="", dado)` — função
pública determinística, reversível por rainbow table se o dado tiver espaço pequeno (um CPF tem 11
dígitos). O código pensa que está protegido e não está.

**Verificação antes do deploy** — barata e vale o hábito:

```bash
for v in VAR_A VAR_B VAR_C; do
  grep -q "$v" docker-compose.yml || echo "FALTA no compose: $v"
done
```

**E o deploy certo:** env **nova** exige `docker stack deploy`. `docker service update --force`
recria o container com a imagem nova mas **não** recarrega variáveis que não existiam antes.

**Regra prática:** ao ler uma env que veio de compose com `:-`, trate string vazia como ausente
(`||`, ou `if (!valor)`), nunca só `??`. E ao adicionar env nova, o compose é parte da feature, não
do deploy.
