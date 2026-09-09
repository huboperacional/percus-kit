## Empacotar o deploy do COMMIT e não da árvore, sem trocar os finais de linha {#empacotar-deploy-do-commit-nao-da-arvore}

`tags: deploy, git archive, autocrlf, CRLF, windows, tar da arvore, trabalho nao commitado, sessao paralela, Dockerfile fora do repo, troca de diretorio, VPS`

**Quando:** o deploy monta um tarball da máquina de desenvolvimento e o extrai num diretório da VPS.
Trocar `tar` da árvore de trabalho por `git archive` é a correção certa — mas ela tem três
armadilhas que anulam o ganho se você não medir antes.

### Por que trocar

`tar -czf pacote.tgz .` empacota o **disco**, então trabalho não commitado de outra sessão sobe
junto, silenciosamente. `git archive HEAD` empacota o **commit**: o que não foi commitado não viaja,
por construção, e `.env` e ignorados ficam de fora sem depender de ninguém lembrar de `--exclude`.

### Armadilha 1 — no Windows, `git archive` inverte os finais de linha

Com `core.autocrlf=true` e sem `.gitattributes`, o índice guarda LF e `git archive` aplica a
conversão de checkout: o pacote sai em **CRLF**. E a árvore de trabalho costuma estar em **LF**
(arquivos escritos por editor/agente nunca passaram por um checkout). Ou seja: o método "novo"
troca o final de linha de todo arquivo de texto em relação aos deploys que funcionam hoje.

**Meça antes de trocar, nos três** — não deduza:

```sh
conta() { c=0; t=0; for f in $(find "$1" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.json' -o -name '*.css' \)); do
  t=$((t+1)); grep -qU $'\r' "$f" && c=$((c+1)); done; echo "$1: $t arquivos, $c com CRLF"; }

conta .                                                              # arvore de trabalho
git archive --format=tar HEAD | tar -x -C /tmp/a && conta /tmp/a     # archive cru
git -c core.autocrlf=false archive --format=tar HEAD | tar -x -C /tmp/b && conta /tmp/b
```

**A correção é a flag, não abandonar o método:** `git -c core.autocrlf=false archive` devolve LF e
torna o pacote idêntico, em finais de linha, ao que já roda em produção. Medido: 206/206 CRLF no
archive cru contra 0/206 com a flag.

> Isto é a versão barata de
> [imagem buildada de `git archive` no Windows morre sem log](../resolver/git-archive-windows-crlf-mata-entrypoint.md).
> Lá o sintoma explodiu num `entrypoint.sh` (shebang vira `#!/bin/sh\r`) e a saída foi bundle +
> checkout no Linux. Se **nenhum shell script está dentro do archive** — confira com
> `grep -rl '^#!' <extraido>` — a flag resolve e o bundle é desnecessário.

### Armadilha 2 — o que o build precisa pode estar FORA do repositório

`git archive` leva só o que o git rastreia. Se o `Dockerfile`, o `entrypoint` ou o `.dockerignore`
moram fora da raiz do repo (comum quando o git cobre só `app/` e a infra fica em `infra/`, um nível
acima), o pacote sozinho **não monta um contexto de build válido** — e o erro só aparece no `COPY`.

Hoje eles costumam sobreviver na VPS por acidente: `tar -x` por cima nunca remove. Levante a lista
real antes de trocar de método:

```sh
ssh host 'cd /opt/<projeto> && find . -type f -not -path "./node_modules/*" | sed "s|^\./||" | sort' > vps.txt
git ls-files | sort > git.txt
comm -23 vps.txt git.txt      # existe na VPS e nao no git: preservar ou e cadaver
```

Cada linha cai em **preservar** (`.env`, `Dockerfile`, `docker-stack.yml`, entrypoint) ou
**cadáver** (arquivo apagado num commit antigo que nunca saiu de lá). Se o arquivo da VPS for
byte-idêntico ao local (`md5sum` dos dois), **preserve o de lá** em vez de reenviar — o entrypoint
nunca chega perto do pacote e a armadilha 1 deixa de existir para ele.

### Armadilha 3 — extrair por cima não apaga, e um arquivo apagado pode quebrar o build

`tar -x` por cima **acrescenta e sobrescreve, nunca remove**. Um commit que apaga arquivo sobe pela
metade. No Next isso é barulhento e bom: se o commit apagou `app/page.tsx` e criou
`app/(marketing)/page.tsx`, as duas resolvem `/` e o build morre em *"two parallel pages that
resolve to the same path"*. Em outros stacks é silencioso e pior.

Por isso: **troque o diretório, não sobreponha.**

### Comando

```sh
# 1. pacote do COMMIT, com finais de linha preservados
git -c core.autocrlf=false archive --format=tar.gz -o /tmp/src.tar.gz HEAD
scp /tmp/src.tar.gz host:/opt/src.tar.gz

# 2. na VPS: extrai limpo, preserva o que so existe la, TRAVA, e so entao troca
ssh host 'set -e; cd /opt
  rm -rf p.new && mkdir p.new && tar -xzf /opt/src.tar.gz -C p.new
  for f in .env Dockerfile .dockerignore docker-stack.yml infra/docker-entrypoint.sh; do
    mkdir -p "p.new/$(dirname "$f")"; cp -p "p/$f" "p.new/$f"; done
  test -s p.new/.env && grep -q "^DATABASE_URL=" p.new/.env
  test -x p.new/infra/docker-entrypoint.sh
  head -1 p.new/infra/docker-entrypoint.sh | od -c | grep -q "\\\\r" && exit 1
  test ! -f p.new/app/page.tsx            # o arquivo que o commit apagou
  mv p p.bak-$(date +%Y%m%d-%H%M%S) && mv p.new p'
```

As travas rodam **antes** do `mv`: sem `.env` válido ou com entrypoint em CRLF, nada é trocado. O
`.bak-<timestamp>` é o rollback inteiro.

### Armadilhas

- Trocar o método e **não** medir os finais de linha — a regressão é invisível no diff e no log.
- Extrair num diretório limpo sem levantar o `comm -23` antes: some o `Dockerfile` que só existia lá.
- Confiar no `git log` para saber o que está em produção. Um diretório que já recebeu árvore não
  commitada não é reproduzível pelo log — a prova tem que ser colhida **dentro do artefato**
  (`docker exec <cid> test -f /app/<arquivo-novo>`). Ver
  [a ordem do git log não diz o que está na imagem](../resolver/git-log-nao-diz-o-que-esta-na-imagem.md).
- Serviço em `:latest` sem carimbar a imagem anterior: `docker service rollback` re-resolve a mesma
  tag e não reverte nada. `docker tag <img>:latest <img>:pre-<sha>` **antes** do build.

**Ref:** Liliflow, deploy de 4 commits em 2026-09-08 — origem das três medições. Base do método:
[sincronizar código para um diretório de deploy que não é repositório git](sync-para-diretorio-de-deploy-que-nao-e-repo-git.md).
