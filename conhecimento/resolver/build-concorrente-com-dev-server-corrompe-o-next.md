## `next build` com o dev server vivo corrompe `.next` — e o sintoma parece bug do seu código {#build-concorrente-com-dev-server-corrompe-o-next}

`tags: next.js, .next, vendor-chunks, ENOENT, dev server, build concorrente, 500, falso defeito, cache de aba, EADDRINUSE, verificacao local`

**Sintoma:** com `npm run dev` de pé, você roda `npm run build` na mesma pasta para "conferir". Depois disso o dev server começa a devolver **500** em rotas que funcionavam, o log enche de `ENOENT: lstat '.next/server/vendor-chunks'`, e uma página renderiza **sem CSS**, com texto branco sobre branco.

**Causa raiz:** os dois processos escrevem no MESMO `.next`. O build reescreve os chunks debaixo do dev server, que segue servindo referências para arquivos que não existem mais. Nada disso é do seu código — mas todo o sintoma aponta para ele.

🔑 **O caso que mais engana é o CSS pela metade**, porque ele parece bug de estilo autoral: uma folha carrega e a outra não, então **as regras com valor literal (`color: #fff`) aplicam e as com `var(--token)` viram inválidas**. O resultado é texto branco sobre fundo branco exatamente nos elementos do tema escuro — e a leitura natural ("apaguei o gradiente sem perceber") é falsa. O teste que decide em uma linha:
```js
getComputedStyle(document.documentElement).getPropertyValue('--um-token-qualquer')
// vazio => a folha de tokens nao carregou; nao e o seu CSS
```

**Solução:**
1. **Nunca rode `build` e `dev` na mesma árvore ao mesmo tempo.** Derrube o dev antes: mate quem escuta a porta, não o wrapper — `TaskStop`/Ctrl-C pode matar o `npm` e deixar o `node` filho segurando a porta, e o segundo `dev` falha com `EADDRINUSE` enquanto o primeiro, moribundo, continua respondendo.
   ```powershell
   (Get-NetTCPConnection -LocalPort <p> -State Listen).OwningProcess | % { Stop-Process -Id $_ -Force }
   ```
2. Para verificar o que vai para produção, use **build + `next start`**, nunca o dev — é o artefato real, e não compete com nada.
3. Se já corrompeu: `rm -rf .next` e rebuild. Limpar só `.next/cache` não basta.

⚠️ **Antes de culpar o código, confirme que a ABA não está velha.** No mesmo episódio, dois renders quebrados sobreviveram à troca do servidor porque o Chrome mantinha a versão anterior dos assets; o `?v=` do `<link>` na aba era diferente do que o servidor servia. `navigate_page(type: reload, ignoreCache: true)` resolveu, e só então o defeito real (nenhum) apareceu.

⚠️ **Regra de leitura:** ao ver um defeito visual, cheque a fonte antes de "corrigir". Neste caso o nome do plano e o preço pareciam ter desaparecido do markup; `grep` no `page.tsx` mostrou as duas linhas intactas. Um `sed`/`Edit` "consertando" o que não estava quebrado é o dano real desta classe.

Relacionado: [next-build-eager-client](next-build-eager-client.md), [validei-contra-a-pagina-de-erro-e-li-como-sucesso](validei-contra-a-pagina-de-erro-e-li-como-sucesso.md).
