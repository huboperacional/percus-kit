## Arquivo em `public/` sombreia a rota do Next com o mesmo nome — e a rota nunca roda {#arquivo-em-public-sombreia-rota-do-next}

`tags: next.js, app router, public, static, route handler, rota morta, sombreamento, llms.txt, robots.txt, sitemap.xml, codigo que nunca executa`

**Sintoma:** você edita `src/app/<nome>/route.ts`, faz build, sobe, e o conteúdo servido em `/<nome>` continua o antigo. Nenhum erro, nenhum aviso de build, e o arquivo editado está claramente correto.

**Causa raiz:** existe `public/<nome>` com o mesmo caminho. No Next, o estático de `public/` é resolvido **antes** das rotas do sistema de arquivos, então ele ganha. A rota compila, entra no build, aparece na listagem de rotas — e nunca executa.

🔑 **A pista que identifica isso em segundos é o tamanho do corpo servido bater exatamente com o do arquivo estático**, e não com o que a rota geraria. Medido em 2026-08-18: `/llms.txt` servia 3.842 bytes, idênticos ao `public/llms.txt`, enquanto a rota dinâmica gerava outro texto.

**Solução:**
1. Antes de debugar a rota, procure o sósia:
   ```bash
   ls public/<nome>* ; rg -l "<um trecho do texto servido>" public/ src/
   ```
2. Escolha **um** dono e apague o outro. Não deixe os dois "por segurança" — o que sobra é código que ninguém executa e que a próxima pessoa vai editar de novo.
3. Para escolher, compare o CONTEÚDO, não a data nem a elegância. No caso medido, o estático tinha 6 seções curadas e a rota 4 mais pobres, e o único valor exclusivo da rota (listar posts do blog) tinha acabado de virar lista vazia — então a rota morreu.

⚠️ **Vale para todo nome que o Next também resolve por rota:** `robots.txt`, `sitemap.xml`, `manifest.json`, `favicon.ico`. Um `public/sitemap.xml` esquecido congela o sitemap para sempre, e o sintoma é "o sitemap não atualiza", que manda a investigação para o lado errado.

⚠️ **A docstring da rota morta mente sem intenção.** A do caso medido dizia que existia para incluir automaticamente posts novos — promessa que nunca foi cumprida um único dia. Ao apagar, leia a docstring: ela diz qual capacidade você está perdendo, e talvez ela precise voltar de outro jeito.

Relacionado: [guarda-morta-entrypoint](guarda-morta-entrypoint.md), [next-canonical-layout-herdado](next-canonical-layout-herdado.md).
