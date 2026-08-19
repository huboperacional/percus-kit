## Imagem velha transforma mudança de uma linha em deploy de 26 mil {#imagem-velha-transforma-mudanca-pequena-em-deploy-grande}

`tags: deploy, imagem docker, tag, staleness, blast radius, worktree compartilhado, overlay, risco, R5, decisao de deploy`

**Contexto:** commitei uma correção de **uma linha** (nome de modelo num registry de provedores) e o
pedido foi "deploya tudo". O serviço que carrega esse código roda uma imagem construída **48 dias
antes**.

**A conta que ninguém faz:** entre o commit daquela imagem e o `HEAD` havia **74 commits, 121
arquivos e +26.012 linhas** nos diretórios que o `Dockerfile` copia — trabalho de várias sessões, que
eu não revisei. Buildar do `HEAD` para levar uma linha poria tudo isso em produção **de carona**, sem
ninguém ter pedido e sem ninguém ter olhado.

**Causa raiz:** em repositório compartilhado por várias sessões, a distância entre a tag em produção
e o `HEAD` **não é proporcional ao que você mudou**. O raio de explosão de um deploy é definido pelo
`Dockerfile` (o que ele copia) e pela idade da imagem — nunca pelo tamanho do seu diff.

**Como decidir:** meça a distância antes de subir.

```bash
docker inspect <imagem>:<tag> --format '{{.Created}}'
git log --oneline --since=<data> -- <dirs que o Dockerfile copia> | wc -l
git diff --stat <sha-da-imagem> HEAD -- <dirs>
```

**Saídas, em ordem de preferência:**
1. **A mudança pega carona** no próximo deploy legítimo daquela frente, quando alguém tiver revisado
   o que vai junto. Vale ainda mais se o ganho imediato for zero — ver
   [[medir-antes-de-escrever-a-justificativa]].
2. **Overlay:** construir sobre a imagem em produção trocando **só** o diretório da sua mudança. Não
   é gambiarra: é o mesmo padrão já usado para separar dois serviços que compartilham imagem.
3. Deployar do `HEAD` — só depois de aceitar explicitamente os N commits alheios.

**O que não fazer:** tratar "deploya tudo" como instrução literal quando "tudo" inclui trabalho de
terceiros que o pedinte não sabe que existe. Meça, mostre a conta, recomende.
