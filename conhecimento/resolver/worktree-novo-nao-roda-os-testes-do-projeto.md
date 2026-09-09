## Worktree novo não roda os testes do projeto — três causas independentes, todas invisíveis até você tentar {#worktree-novo-nao-roda-os-testes-do-projeto}

`tags: git worktree, untracked, .env, R20, autorizar-acao-externa, node_modules, symlink, ln -s, npm install, vps-test, subagent, SDD, R23`

**Sintoma:** você cria `git worktree add` pra isolar uma feature, o checkout copia tudo, `git status`
fica limpo — e então **nenhum comando de teste funciona**. O runner de backend reclama de variável de
ambiente ausente, o hook de ação externa bloqueia, e `tsc`/`vitest` nem existem. Nada disso aparece
no `git status`, porque nada disso é rastreado pelo git.

**Causa raiz:** um worktree herda **só o que está no git**. Tudo que o projeto precisa pra rodar e
que é untracked/ignorado fica pra trás. São três coisas distintas, e você bate nelas uma de cada vez:

**1. O `.env` não vem.** É untracked (gitignored), então o worktree nasce sem ele. Qualquer runner
que leia credencial (`SERVER_ROOT_PASSWORD`, `DATABASE_URL`) morre com "ausente no .env". Conserto:
`cp .env <worktree>/.env` — confira antes que ele é gitignored **nos dois** (`git check-ignore -q
.env` em cada), senão você acabou de preparar um vazamento de segredo em commit.

**2. A autorização do R20 mora no diretório PRIMÁRIO.** O `autorizar-acao-externa.ps1` grava em
`.percus/acao-externa-autorizada.json` relativo ao **cwd**, e o hook `external-action-guard` procura
no cwd do comando. Rodando a partir do worktree, o hook não enxerga a autorização criada no checkout
principal e bloqueia — mesmo dentro da janela de 60 min, mesmo com comandos idênticos tendo passado
minutos antes. Conserto: rode o script **com o cwd no worktree**, o que cria o arquivo lá.
(Relacionado: [[autorizacao-r20-invisivel-quando-o-cwd-da-sessao-entra-em-subdiretorio]].)

**3. `node_modules` pode ser um symlink apontando pra fora do repo.** Em monorepo com frontend em
subpasta, `frontend/node_modules` às vezes é symlink pra outro worktree. O worktree novo não ganha
nem o symlink nem o alvo. E aqui mora a armadilha que custa mais tempo:

> **`ln -s` no Git Bash do Windows COPIA em vez de linkar** quando symlink nativo não está
> disponível. Você acha que criou um link em 1 segundo e na verdade disparou a cópia de um
> `node_modules` inteiro — que trava, e ainda deixa uma cópia **parcial** no lugar.

Pior: apagar a cópia parcial pode ser impossível se o ambiente tiver guard de segurança em `rm -rf` /
`Remove-Item` / `rd /s /q` sobre aquela árvore. Você fica com um diretório inútil e sem como removê-lo.

**Conserto que funciona sem apagar nada:** rode **`npm install`** dentro do worktree. Ele reconcilia
o diretório parcial (não exige base limpa) e resolve o problema inteiro. É literalmente o passo de
setup que qualquer skill de worktree manda fazer — a tentação de ser esperto com symlink é o que
faz você pular ele.

⚠️ **Efeito colateral de `npm install`:** ele pode reescrever o `package-lock.json` (no caso medido,
removeu uma entrada de peer-dep opcional). Isso é efeito da **sua montagem**, não do trabalho da
feature, e o CI roda `npm ci` a partir desse arquivo. **Reverta o lockfile antes de commitar**
(`git restore -- frontend/package-lock.json`), senão você entrega uma mudança de dependência
disfarçada de mudança de feature.

**Medido no Plexco Tasks (2026-09-04)** montando `.worktrees/frente-raias` pra uma execução
subagent-driven: as três causas apareceram em sequência, cada uma só depois de resolver a anterior.
Custo total antes de o primeiro teste rodar: ~40 minutos e um subagente bloqueado duas vezes.

**Discriminante, em uma linha:** o comando funciona no checkout principal e falha no worktree por
"arquivo/variável/autorização ausente"? Então é untracked que não veio — procure `.env`, `.percus/`
e `node_modules`, nessa ordem, antes de suspeitar do código.

**Faça isto ao criar worktree em projeto com backend + frontend:**

```bash
git worktree add .worktrees/<nome> -b <branch>
cp .env .worktrees/<nome>/.env                 # confira gitignore nos dois
cd .worktrees/<nome>/frontend && npm install   # NÃO tente symlink de node_modules
cd .. && git restore -- frontend/package-lock.json
# e rode autorizar-acao-externa.ps1 COM cwd aqui, não no checkout principal
```

**Lição pro subagente:** se você delega a execução, diga ao subagente pra **escalar** o bloqueio em
vez de contornar. No caso medido o implementador foi bloqueado 4x pelo guard do R20 e parou sem
setar `PERCUS_EXTERNAL_OVERRIDE`, sem copiar o arquivo de autorização e sem editar o hook — decisão
certa, porque nenhuma dessas três é dele pra tomar, e o diagnóstico que ele trouxe valia mais que
um contorno silencioso.
