## "Camada velha" que a camada nova referencia N vezes não está velha — está pendente de migração {#camada-velha-ainda-apontada}

`tags: refactor de estrutura, camada legada, arquivar, .archive, git mv, migracao de canon, v1 v2, ponteiro cruzado, casca fina, medir antes de mover, aposentar documento`

**Sintoma:** você move a "camada antiga" pra `.archive/` (ou renomeia/deprecia), o `git mv` roda
limpo, os testes passam — e o resultado é um diretório chamado *archive* que a camada nova precisa ler.
No caso real, o `README` recém-escrito dizia "nada em `.archive/` é lido por agente" enquanto o índice
do canon **novo** apontava pra lá. Contradição na mesma árvore, criada pelo próprio commit.

**Causa raiz:** confundir **substituído** com **antigo**. Um documento só está aposentado quando
existe destino vivo para o que ele responde. Se a camada nova ainda aponta pra ele, a camada nova é
uma **casca fina**: ela roteia, mas o conteúdo continua do outro lado.

**Solução — meça antes de mover.** Conte os ponteiros vivos por destino, excluindo registro histórico:

```bash
git mv <camada-velha> .archive/  # faça o move num branch, so pra medir
git diff | grep "^+" | grep -o "archive[/\\][A-Za-z0-9_./-]*" | sort | uniq -c | sort -rn
```

Zero ponteiro = aposentadoria de fato, siga. Dezenas = **o move é o erro**: o trabalho real é migrar
conteúdo (reescrever no formato novo), e isso é uma fase por bloco, não um commit. Reverta o move,
guarde o patch, e corrija só o **roteamento** (quem entra primeiro), declarando a camada como
"pendente de migração" com o número medido — assim ninguém tenta o atalho de novo.

Sinal de que você está no atalho errado: a varredura de referências fica enorme (dezenas de arquivos)
e você começa a reescrever ponteiro de skill, template e hook pra apontar pra dentro de `archive/`.

**Ref:** kit Percus 2026-07-29 — 89 ponteiros vivos (`01_REGRAS` 25×, `02_INFRA` 17×), incluindo o
`v2/referencia/README.md`; move revertido, virou fase de migração de conteúdo. Relacionado:
[regra-duplicada-ps1-sh](regra-duplicada-ps1-sh.md).
