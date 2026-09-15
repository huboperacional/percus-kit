## Pasta criada por hook no diretório atual vira rota fantasma e quebra teste de navegação {#pasta-de-hook-no-diretorio-atual-vira-rota-fantasma}

tags: hooks, cwd, nextjs, app-router, teste, navegacao, falso-positivo, windows

**Sintoma.** Um teste que lista as pastas de rota do app (cobertura de navegação, "nenhuma tela
órfã", menu × rotas) passa a falhar com uma aba que ninguém criou — por exemplo
"`.deepseek` é aba conhecida (KNOWN_TABS)". Parece regressão de navegação. Nenhum arquivo de rota
mudou.

**Por que morde.** Hooks de sessão (orçamento de contexto, logs de review) gravam pastas como
`.deepseek/context-budget/` **relativas ao diretório atual**, não à raiz do git. Um `cd` solto para
uma subpasta do app — seu ou de um subagente — faz o hook seguinte criar essa pasta **dentro da
árvore de rotas**. A pasta fica vazia, não aparece no `git status` (costuma estar ignorada) e o
scanner do teste, que anda no disco, a trata como rota.

**Caso real** (Paid Media Automation, 2026-09-14). Suíte do web com 5 falhas em vez das 2 de
baseline; 3 eram `nav-cobertura-de-telas.test.ts` acusando `.deepseek`. `find` achou seis pastas
`.deepseek/context-budget` vazias em `web/src/app/dashboard/clients/[id]/(shell)/…`, criadas entre
16:15 e 17:38 por duas sessões diferentes cujo diretório tinha escorregado para subpastas. Removidas
só as vazias, o teste voltou a 35/35.

**Como resolver.**

```bash
find web -name node_modules -prune -o -name .deepseek -print
rmdir "<pasta>/.deepseek/context-budget" "<pasta>/.deepseek"   # rmdir falha sozinho se houver arquivo
```

Nunca `rm -rf` em pasta de outra sessão: remova só as vazias e deixe as que têm log.

**Como evitar.**

- Comando em subpasta sempre em subshell: `(cd web && npx vitest run …)`. Um `cd` solto muda o
  diretório da sessão para os comandos (e hooks) seguintes.
- Passe a mesma regra no prompt de todo subagente que roda comandos.
- Ao escrever scanner de rotas ou de fonte, ignore diretórios que começam com `.` ou pergunte ao git
  quais arquivos são rastreados, em vez de andar no disco.
