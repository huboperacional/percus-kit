## Os `.sh` do percus-review chegam ao cache do plugin com CRLF — e o `install-git-hooks` copia o template assim para `.git/hooks` {#sh-do-plugin-no-cache-chega-com-crlf-e-o-hook-nativo-copia-assim}

`tags: crlf, autocrlf, gitattributes, plugin cache, percus-review, install-git-hooks, pre-commit, hook nativo, sh, git bash, windows, linux, portabilidade`

**Medido (LiliCalc, 2026-09-14, plugin 6.53.0).** No kit,
`plugin/percus-review/git-hooks/pre-commit.template.sh` está em LF no índice e na árvore
(`git ls-files --eol` dá `i/lf w/lf`). No cache instalado
(`.claude-home/plugins/cache/percus-tools/percus-review/6.53.0/`), o mesmo template tem **95 bytes
`\r`** — e pelo menos 15 `.sh` de `hooks/` também têm CR. O kit não tem `.gitattributes` e roda com
`core.autocrlf=true`. Onde a conversão acontece (publicação, instalação ou cópia para o cache) não
foi isolado.

**Consequência:** a skill `/percus-review:install-git-hooks` manda copiar o template literal para
`.git/hooks/pre-commit`, e o hook nativo nasce em CRLF.

**O que foi medido que NÃO quebra:** no Git Bash desta máquina, o `sh` executou o hook CRLF
corretamente (sem review, imprimiu o BLOCK nativo e saiu 1). O risco é fora dele: um `sh` de Linux —
hook rodando em CI, repositório clonado num servidor, WSL — lê `then\r` como erro de sintaxe, e hook
que falha bloqueia todo commit. Isso **não** foi medido em Linux; é a mesma classe de
[git-archive-windows-crlf-mata-entrypoint](git-archive-windows-crlf-mata-entrypoint.md).

**Ao instalar, converta e confira:**

```sh
tr -d '\r' < <template> > .git/hooks/pre-commit
tr -cd '\r' < .git/hooks/pre-commit | wc -c    # tem que dar 0 (conte o byte; grep -c inverte no Git Bash)
sh -n .git/hooks/pre-commit                    # parse ok
```

E teste o hook sem passar por `git commit` — a Layer 1 barra o comando antes, e aí o teste não mede
a Layer 2: num repositório descartável com algo staged, rode `sh .git/hooks/pre-commit` na raiz sem
`.deepseek/reviews` (espera exit 1), com `latest.jsonl` recém-criado (exit 0) e com ele envelhecido
(`touch -d '10 minutes ago'`, exit 1).

**Correção de raiz, no kit (não feita aqui):** `.gitattributes` com `*.sh text eol=lf`, e achar o
passo que converte os `.sh` a caminho do cache.
