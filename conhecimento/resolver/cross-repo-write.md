## Escrever em outro repo: caixa/arquivo — exceção é a pasta comum `conhecimento\` {#cross-repo-write}

`tags: cross-repo, canon, write, commit, outro projeto, protocolo, caixa de texto, conhecimento, mover arquivo, exceção`

**Contexto:** uma sessão de um projeto (ex.: Coach, tiatendo) precisa propagar algo pra outro repo —
outro produto, ou o canon (`percus-kit`).

**Regra geral:** pra escrever em **qualquer outro repo**, NÃO edite o repo de destino direto —
entregue **texto numa caixa ou num arquivo** pro outro projeto aplicar nele mesmo. Leitura cross-repo
é livre; escrita não. Vale pros dois sentidos: projeto → projeto **e** canon → projeto (o canon
nunca faz `git mv/cp/rm` pra fora dele).

⚠️ **Exceção única (operador, 2026-07-23):** os **arquivos comuns entre projetos que ficam em
`D:\Claud Automations\percus-kit\conhecimento\`** — esses qualquer sessão **escreve e commita
direto**. É onde mora o conhecimento cross-projeto (R23: esta base, um arquivo por verbete), sincronizado via
`git pull`; obrigar caixa de texto pro próprio repositório de aprendizado só perderia o aprendizado.
**A exceção é a pasta `conhecimento\`, NÃO o canon inteiro** — a raiz do canon
(`01_REGRAS_INEGOCIAVEIS.md`, `02..06`, `CANON_VERSION.md`, plugin) segue a regra geral: mudança ali
vai por caixa/arquivo pro operador aplicar. Regra curta: **`conhecimento\` → escreve direto; qualquer
outro alvo → caixa de texto.**

**Ao commitar em `conhecimento\` vindo de outro projeto:** stage **seletivo** — commite só os arquivos
que você tocou; a árvore do canon costuma ter trabalho em voo de outra sessão (em 23/07 havia
`01_REGRAS_INEGOCIAVEIS.md` modificado por outra frente). Gate R11 com `Set-Location` no repo do
canon, em chamada separada do commit (PreToolUse).

**Ref:** memória `feedback_cross_repo_write_protocol` (reforçado 2026-05-30). Exceção adicionada
2026-07-23 (Família Milionária) e **estreitada de "canon inteiro" para `conhecimento\`** na mesma
data a pedido do operador (sessão tiatendo).
