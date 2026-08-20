## next/image quebra atrás de Basic Auth no middleware {#next-image-quebra-atras-de-basic-auth}

tags: next, middleware, basic-auth, imagem, staging

**Sintoma.** O site sobe protegido por senha básica no middleware, a página carrega, mas toda
imagem local some. No log do servidor:

```
⨯ The requested resource isn't a valid image for /logo.png received null
```

**Causa.** O `next/image` **não** entrega o arquivo direto: ele chama o próprio servidor para
otimizar a imagem. Essa requisição interna **não carrega o cabeçalho `Authorization`** do
visitante. O middleware então devolve 401, o otimizador recebe um corpo vazio e reporta
"isn't a valid image".

O matcher padrão gerado pelo `create-next-app` exclui `_next/static` e `_next/image`, mas **não**
exclui os arquivos de `public/` — e é de lá que vêm logo, favicon e ilustração.

**Correção.** Liberar os estáticos no middleware, com **lista fechada de extensões de mídia**:

```ts
const caminho = req.nextUrl.pathname
if (/\.(png|jpe?g|gif|webp|avif|svg|ico|mp4|webm)$/i.test(caminho)) {
  return NextResponse.next()
}
```

**Não** use `/\.[a-z0-9]{2,4}$/` para "qualquer coisa com extensão": isso libera sondagem por
`/.env`, `/config.php` e `/backup.sql`, que passam a receber 404 da aplicação em vez de 401 da
proteção. Também não é preciso incluir `css`, `js` ou `map` — o Next serve esses por
`/_next/static`, que o matcher já exclui.

**Vale para qualquer proteção no middleware**, não só Basic Auth: cookie de staging, allowlist de
IP, feature flag. Sempre que a proteção olha um cabeçalho do visitante, a requisição interna do
otimizador não o tem.

**Exceções irmãs que aparecem junto.** Na mesma configuração costumam quebrar por motivo idêntico:

- **healthcheck do orquestrador** — não manda credencial; atrás da senha o container é marcado
  como não-saudável e reiniciado em laço;
- **webhook de gateway de pagamento** — não faz Basic Auth; recebe 401 em todo evento, e o Asaas
  **para a fila inteira** depois de 15 falhas seguidas;
- **rota de painel com login próprio** — a credencial básica não sobrevive ao POST de server
  action, e o formulário de login simplesmente não envia.

Visto no Salas Flex, 2026-08-20.
