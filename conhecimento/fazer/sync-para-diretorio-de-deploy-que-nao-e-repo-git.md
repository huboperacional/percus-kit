## Sincronizar código para um diretório de deploy que NÃO é repositório git {#sync-para-diretorio-de-deploy-que-nao-e-repo-git}

`tags: deploy, sync, git archive, tar-pipe, rsync, .env de producao, troca de diretorio, arquivos apagados, bit de execucao, chmod, rollback, VPS`

**Quando usar:** a VPS tem `/opt/<projeto>` com o código, mas **não é um clone** — então não há `git pull`. O código precisa viajar da máquina de desenvolvimento, sem levar segredo e sem deixar lixo.

### 1. Monte o pacote com `git archive`, nunca com `tar` da árvore

```bash
git archive --format=tar HEAD | ssh <host> 'mkdir -p /opt/<projeto>.new && tar -x -C /opt/<projeto>.new'
```

🔑 **`git archive` inclui só o que o git rastreia, então `.env` fica de fora POR CONSTRUÇÃO.** `tar` da árvore de trabalho depende de alguém lembrar de digitar `--exclude`, e essa é a linha que some numa pressa. Exclusão que depende de memória não é exclusão.

### 2. Troque o diretório; não sobreponha

```bash
ssh <host> '
  set -e
  cd /opt
  cp -p <projeto>/<caminho>/.env  <projeto>.new/<caminho>/.env
  test -s <projeto>.new/<caminho>/.env
  grep -q "^DATABASE_URL=" <projeto>.new/<caminho>/.env
  BAK=<projeto>.bak-$(date +%Y%m%d-%H%M%S)
  mv <projeto> "$BAK" && mv <projeto>.new <projeto>
  echo "antigo em /opt/$BAK"'
```

🔑 **`tar -x` por cima ACRESCENTA e SOBRESCREVE, mas nunca REMOVE.** Um commit que apaga arquivos sobe pela metade e o sintoma é péssimo: no caso medido, 28 arquivos apagados (rotas mortas, imagens e fontes antigas) continuaram na VPS, e o Next **recompilou em produção justamente as rotas que o `301` tinha sido escrito para cobrir**. A limpeza deployou como no-op.

Descubra o tamanho do problema **antes** de escolher o método:
```bash
ssh <host> 'cd /opt/<projeto> && find . -type f | sed "s|^\./||" | sort' > vps.txt
git ls-files | sort > git.txt
comm -23 vps.txt git.txt        # existe na VPS e nao no git
```

### 3. Preserve o que só existe lá — e saiba o que é

Da lista acima, cada arquivo cai em um de dois grupos: **precisa sobreviver** (o `.env` de produção, um script chamado por cron) ou **é cadáver de commit anterior**. Copie o primeiro grupo para `.new` antes da troca, com `cp -p`. As travas (`test -s`, `grep -q` numa chave obrigatória) rodam **antes** do `mv` — sem `.env` válido, nada é trocado.

⚠️ **Script que o cron chama e que só existe na VPS é dívida.** Ele depende de alguém lembrar de preservá-lo em todo sync. Aponte o cron para o caminho que o sync entrega (`<projeto>/scripts/x.sh`) e a dependência desaparece.

### 4. Confira o bit de execução no git, não no disco

```bash
git ls-files -s '*.sh'    # 100644 = SEM bit de execucao
git update-index --chmod=+x deploy.sh
# ⚠️ `update-index` mexe SÓ no índice. Sem commit, `git archive HEAD` continua
# empacotando 100644 e o deploy segue morrendo em `permission denied`.
git add deploy.sh && git commit -m "chore: bit de execução do deploy.sh"
# prova, e é a prova que importa (o que o archive REALMENTE empacota):
git archive --format=tar HEAD | tar -tv | grep deploy.sh   # tem de vir 100755
```

⚠️ **Em repositório criado no Windows o bit costuma nunca ter sido versionado.** O arquivo é executável na VPS porque alguém deu `chmod` à mão um dia; todo sync derivado de `git archive` entrega `100644` e o deploy morre em `permission denied`. Foi o que travou um deploy real na primeira tentativa. Uma trava `test -x` antes do `mv` transforma isso em erro claro em vez de deploy quebrado.

### 5. Rollback é um `mv`

O `.bak-<timestamp>` da etapa 2 é o rollback inteiro. Custa ~17 MB e vale a noite que economiza.

Relacionado: [verificacao-pos-deploy-mente-por-cache-de-borda](../resolver/verificacao-pos-deploy-mente-por-cache-de-borda.md).
