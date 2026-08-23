## `next build` na mesma pasta envenena o `next dev` — a página abre sem CSS e o texto certo passa na conferência {#build-de-producao-envenena-o-dev-server}

`tags: nextjs, next dev, next build, .next, 404, _next/static, screenshot, evidencia, falso verde, porta ocupada, multiplas sessoes`

**Sintoma:** a página abre, o texto está correto, e **nenhum estilo é aplicado** — tudo em serifa
preta sobre branco. O console mostra 404 em série:

```
GET /_next/static/css/app/layout.css   404
GET /_next/static/chunks/main-app.js   404
GET /_next/static/chunks/app/page.js   404
```

**Causa raiz:** `npm run build` e `npm run dev` gravam no **mesmo `.next/`**, com manifestos
incompatíveis. Rodar o build (para conferir que compila antes de um deploy, por exemplo) e depois
subir o `dev` deixa o servidor de desenvolvimento servindo um manifesto de produção: ele aponta para
chunks com hash que o dev não gera.

**Conserto:** `rm -rf .next` e suba o `dev` de novo. Não há flag; é o diretório compartilhado.

**Por que isto é perigoso e não só chato:** página sem CSS **ainda renderiza o texto certo**. Se a
foto foi tirada para provar uma correção de texto, ela prova — e passa numa conferência rápida como
evidência válida, escondendo que o layout nunca foi verificado. É evidência que confirma metade e
parece confirmar tudo.

**Como não cair:**
1. **Nunca interleave `build` e `dev` na mesma pasta.** Se precisar dos dois, `rm -rf .next` entre
   eles.
2. **Antes de guardar qualquer screenshot como evidência**, confirme que o CSS carregou —
   `getComputedStyle(document.body).backgroundColor` não pode ser `rgba(0, 0, 0, 0)`, ou meça o
   `fontWeight` de um título que você sabe que é bold.
3. **Leia a porta no log do processo**, não assuma 3000. Com várias sessões na mesma árvore o Next
   sobe em 3001, 3002, 3003… e fotografar a porta errada é fotografar a árvore de outra pessoa:
   ```bash
   grep -oE 'http://localhost:[0-9]+' <log-do-dev> | head -1
   ```

Ver também: [[o-screenshot-pega-o-que-a-guarda-nao-ve]].
