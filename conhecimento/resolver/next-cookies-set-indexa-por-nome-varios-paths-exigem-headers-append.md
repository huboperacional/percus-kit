## `res.cookies.set()` do Next indexa por NOME — emitir o mesmo cookie em vários `path` num laço sobrescreve e sai UM `Set-Cookie`; use `headers.append` {#next-cookies-set-indexa-por-nome-varios-paths-exigem-headers-append}

`tags: next, cookie, Set-Cookie, path, RFC 6265, ResponseCookies, headers.append, sessao, rotas irmas, gate cego, R23`

**Sintoma:** um login emite cookie de sessão para várias rotas irmãs (`/relatorio`, `/relatorio-v2`,
`/relatorio-v3`) com um laço `res.cookies.set(NOME, token, { path })`. Testes verdes. Em produção o
usuário entra a senha e **só a última rota do laço abre** — as outras devolvem o portão de novo, sem
erro nenhum na tela. Medido em 2026-09-05 no `paid-media-web`: 74 testes verdes, 1 `Set-Cookie` na
resposta real, com `Path=/plano-d4u-verba-v3` (a última volta).

**Causa raiz, em duas camadas:**

1. **Cookie de `path` só casa em `/`.** Pela RFC 6265 §5.1.4, `cookie-path` casa com o request se
   for igual, **ou** se for prefixo **e** o caractere seguinte for `/`. Um cookie em
   `/plano-d4u-verba` chega em `/plano-d4u-verba/entrar` mas **não** em `/plano-d4u-verba-v2` (o
   seguinte é `-`). Rotas irmãs com sufixo não herdam sessão da rota base — e não há path
   intermediário que resolva. Saídas: rotas aninhadas, `path: "/"` (alarga demais), ou um cookie
   por rota.
2. **`ResponseCookies` do Next é um mapa por nome.** Três `set()` com o mesmo nome e paths
   diferentes se sobrescrevem; a resposta carrega só a última. O laço "óbvio" está silenciosamente
   errado.

**Correção:** serialize o cabeçalho e acumule.

```ts
const token = assinarSessao();
for (const path of CAMINHOS_DE_SESSAO) {
  res.headers.append("Set-Cookie", `${NOME}=${token}; Path=${path}; Max-Age=${ttl}; SameSite=Lax; HttpOnly; Secure`);
}
```

O logout precisa do mesmo tratamento — apagar com `set()` num laço apaga um path só, e o usuário
"sai" de uma rota continuando dentro das outras.

**Por que 74 testes não viram:** o gate provava que a LISTA de caminhos cobria as três rotas — e
cobria. Verificava a **estrutura de dados que alimenta o efeito**, nunca o efeito. Quando o efeito é
um cabeçalho, o gate assere sobre `res.headers.getSetCookie()` chamando o route handler de verdade:

```ts
const res = await POST(pedido(SENHA));
const paths = res.headers.getSetCookie().map(c => /;\s*Path=([^;]+)/i.exec(c)?.[1]).sort();
expect(paths).toEqual([...CAMINHOS_DE_SESSAO].sort());
```

Visto reprovando com o `set()` de volta: `expected [ Array(1) ] to have a length of 3`. Vale para
qualquer API de framework com semântica de upsert/dedup por chave: a coleção de entrada estar certa
não prova que a saída tem N itens.

**Como saber que resolveu:** `curl -i -X POST .../entrar` mostra N linhas `Set-Cookie`, uma por
path; um `curl -b jar` em cada rota irmã devolve o conteúdo, não o portão.
