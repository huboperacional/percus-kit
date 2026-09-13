## Bind mount de ARQUIVO prende o inode: `os.replace`/`mv` no host não chega no container que já está rodando {#bind-mount-de-arquivo-prende-o-inode-e-o-replace-nao-chega-no-container}

`tags: docker, swarm, bind mount, inode, os.replace, rename, escrita atomica, .env, load_dotenv, verificacao, falso negativo, R23`

**Sintoma:** você corrige um arquivo montado no container (`.env`, config, YAML) com escrita
atômica — temporário + `os.replace` (ou `mv`) — e, ao conferir **dentro do container vivo**
(`docker exec ... cat` / `python -c ...`), ele ainda mostra o conteúdo **antigo**. Parece que a
escrita falhou. Não falhou: no host o arquivo está certo.

**Reprodução real** (tiatendo, 2026-09-13): `/opt/tiatendo/.env` montado como
`- ./.env:/app/.env:ro` no compose. Três chaves reescritas e três adicionadas por `os.replace`.
Medido na sequência, sem imprimir valor (só `sha256`):
- no **host**, e num container **novo** (`docker run --rm -v /opt/tiatendo/.env:/chk/.env:ro`):
  as chaves novas, com hash igual ao da fonte;
- no container **vivo** (`docker exec` + `python-dotenv` em `/app/.env`): o hash **antigo** das
  três reescritas, e as três adicionadas **AUSENTES**.

**Causa raiz:** bind mount de **arquivo** amarra o caminho dentro do container ao **inode** que
existia no momento da montagem. `os.replace`/`rename`/`mv` não alteram aquele inode — criam um
novo e trocam a entrada de diretório no **host**. O container continua segurando o inode velho
até ser recriado. Escrita **no lugar** (`open(path, "w")`) mudaria o inode compartilhado e o
container veria — mas é justamente a escrita que TRUNCA antes de gravar e deixa o arquivo vazio
se o processo morrer no meio. As duas propriedades puxam em direções opostas.

**Solução:**
- **Para VERIFICAR** uma escrita atômica: leia no host, ou num container **descartável**
  (`docker run --rm --network none --entrypoint python3 -v <arquivo>:<destino>:ro <imagem> -`),
  usando o **mesmo parser** que a aplicação usa. **Nunca** confirme pelo `docker exec` no
  container vivo — ele devolve o valor velho e produz um falso negativo.
- **Para o container PASSAR a ver:** recrie a tarefa (restart / `service update --force` /
  deploy). Some isso ao plano de validação da mudança; não é automático.
- **Se o arquivo precisa ser relido em runtime** (config com reload): monte o **diretório**, não o
  arquivo. Com bind de diretório, a troca de entrada feita pelo rename é visível lá dentro.

**Contra-regra:**
- Para `.env` lido por `load_dotenv()` isto quase nunca muda o comportamento do app: ele lê uma
  vez no import e **não sobrescreve** variável já presente no ambiente. O efeito que importa é na
  VERIFICAÇÃO — é ali que o inode preso engana.
- Bind mount de **diretório** não sofre disso. Confira no compose (`- ./tenants:/app/tenants` é
  diretório; `- ./.env:/app/.env:ro` é arquivo) antes de aplicar este verbete.

Relacionado: [[escrita-atomica-tmp-rename-leva-o-modo-do-temporario]] (o `mkstemp` cria `0600` e
o `os.replace` carrega esse modo para o destino — o outro efeito colateral da mesma técnica).
