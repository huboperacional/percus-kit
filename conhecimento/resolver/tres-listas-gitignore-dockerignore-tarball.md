## São TRÊS listas: .gitignore, .dockerignore e o filtro do tarball {#tres-listas-gitignore-dockerignore-tarball}

tags: deploy, segredo, docker, tarball, buildkit, gate

**Sintoma.** Um segredo (`.env` com API key) reaparece no servidor depois de você ter "consertado o
vazamento".

**As três listas, e o que cada uma NÃO protege.**

| Lista | Protege | Não protege |
|---|---|---|
| `.gitignore` | o repositório | o tarball de deploy, o contexto de build |
| `.dockerignore` | o contexto de build (a imagem) | o **disco do servidor** |
| filtro do `tarfile.add(..., filter=)` | o que sobe pro servidor | — |

Um Dockerfile com `COPY . .` e sem `.dockerignore` leva **tudo** que estiver no diretório — inclusive
o que o git nunca viu, porque está ignorado.

**A armadilha da terceira lista, medida no Micro Investors (2026-08-19).** O `.dockerignore` foi
criado na `v88`, conferido (`ls .env` = 0 no servidor) e o item dado por fechado. No deploy da `v90`
a chave **reapareceu** em `/opt/.../frontend-build-v90/.env`: o script de deploy novo foi copiado do
template da `v87`, **anterior ao conserto**, e o filtro do tarball dele nunca excluiu `.env`.

O `.dockerignore` fez o trabalho dele — as imagens finais têm **0** `.env`, conferido rodando
`docker run --rm --entrypoint sh <img> -c 'find / -name .env'`, não por raciocínio sobre multi-stage.
Mas o arquivo pousou no **disco** assim mesmo. Varredura: presente nos build dirs `v42`..`v87` e
`v90`; **com a chave** de `v80` em diante. `v88` e `v89` limpas — a prova de que o conserto existia e
não foi carregado adiante.

**Como aplicar.**

- Ao escrever script de deploy copiando de um anterior, **compare o filtro com o mais recente que
  passou**, não com o que estiver mais à mão. Conserto que vive só no script de uma versão morre na
  próxima cópia. O lugar do conserto é o template.
- **Ponha o gate no próprio script** (`ls $BUILD_DIR/.env | wc -l`, espera 0). Foi ele que pegou
  isto, num deploy em que todo o resto passou verde.
- Antes do upload: `tar tzf pacote.tgz | grep -iE "\.env|\.auth|credential|key"`. Além do `.env`,
  cace sessão viva de teste (`e2e/.auth/` guarda access **e** refresh do operador).
- **Prove o filtro executando-o** contra nomes plantados (`.env`, `.env.local`, `.env.example`), não
  lendo o código dele.

**Quarta cópia, que quase todo mundo esquece: o cache do BuildKit.** Builds anteriores ao
`.dockerignore` deixam o segredo numa camada cacheada. `docker builder du` mostra o tamanho;
`docker builder prune -af` limpa. Num VPS compartilhado isso é pedido ao operador, não iniciativa —
mas sem isso a remoção dos arquivos em disco é meia mitigação. No caso medido: 929 entradas /
21,4 GB, 100% recuperáveis, e 37,77 GB liberados no total.

**Se já vazou:** rotacionar é decisão do operador — chave compartilhada entre projetos derruba
ferramenta em todos eles até a nova ser propagada. Se ele recusar a rotação, remover as cópias
(disco **e** cache de build) é o que resta.
