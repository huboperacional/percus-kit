## Rate-limit lendo o PRIMEIRO IP do X-Forwarded-For não limita nada {#xff-primeiro-ip-e-forjavel}

`tags: rate limit, x-forwarded-for, xff, ip, spoof, forjado, traefik, proxy, cloudflare, cdn, enumeracao, login, brute force, dos`

**Contexto:** rate-limit por IP num app atrás de proxy (Traefik, nginx). O código lê
`xff.split(",")[0]`, com o comentário de sempre: "o primeiro é o cliente, o proxy acrescenta o dele
à direita". O limite parece funcionar em teste e não segura nada em produção.

**Causa raiz:** o `X-Forwarded-For` é **enviado pelo cliente**. O que o proxy faz é *acrescentar* o
IP real da conexão à direita, não apagar o que veio. Então o atacante manda
`X-Forwarded-For: <aleatório>` a cada requisição, vira uma origem nova toda vez, e o balde nunca
enche. Num login sem senha — só e-mail, ou magic link — isso significa enumeração ilimitada.

**Solução:** leia o **último** item, não o primeiro. É correto nos dois comportamentos possíveis do
proxy: se ele acrescenta, o último é o IP real; se ele sobrescreve o cabeçalho, o último é o único, e
também é o real. Não depende de adivinhar configuração.

```ts
const itens = (cabecalho ?? "").split(",").map(p => p.trim()).filter(Boolean);
return itens.at(-1) || "desconhecida";   // sem cabeçalho: um balde só, falha fechada
```

O `filter(Boolean)` não é zelo: `"1.2.3.4, 5.6.7.8,"` com vírgula sobrando daria string vazia como
último item, e string vazia é uma origem nova a cada pedido — limite nenhum, de novo.

**Armadilha na direção oposta — e ela derruba o produto:** "último" supõe **um** proxy confiável na
frente. Se alguém ligar um CDN (nuvem laranja do Cloudflare, por exemplo), o último passa a ser o IP
do CDN, **todo visitante vira a mesma origem**, e o limite derruba o site inteiro para todo mundo.
Não é degradação, é queda. Ou seja: a contagem de saltos confiáveis é uma decisão de topologia que
tem de estar **escrita** ao lado do código, e revisada quando o DNS mudar. Com CDN na frente, use o
cabeçalho que ele fornece (`CF-Connecting-IP`) ou conte da direita pulando os saltos confiáveis.

**Diagnóstico em 30s:** mande duas requisições com `X-Forwarded-For` diferente e veja se caem no
mesmo balde. Se cada uma abre um balde novo, você está lendo o primeiro.

**Ref:** LiliCalc, Fase 4 (2026-09-12). O login é só e-mail (ADR de exceção), então o rate-limit era
a única defesa contra enumerar compradores — e estava lendo o primeiro item.
