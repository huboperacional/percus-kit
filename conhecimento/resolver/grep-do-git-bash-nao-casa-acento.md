## `grep -i` do Git Bash não casa ACENTO: a varredura de "não sobrou nada" dá verde falso em português {#grep-do-git-bash-nao-casa-acento}

`tags: grep, ripgrep, rg, Git Bash, MSYS2, Windows, acento, UTF-8, case folding, locale, varredura de aceitacao, criterio de ausencia, verde falso, FR de limpeza`

**Sintoma:** o critério de aceitação é *"a busca não acha mais nada"*, o `grep` devolve vazio, e você
declara limpo — com as ocorrências vivas no arquivo.

**Medido em 2026-08-17:** varrendo `família`/`famílias` num `.tsx`,
`grep -rniE "fam[ií]li"` achou **1 de 3**; `rg` com o mesmo padrão achou **3 de 3**.

**Causa.** É o locale do bundle MSYS2 que acompanha o Git para Windows: o case-folding do `-i` não
cobre os bytes acentuados em UTF-8. O padrão está certo; a ferramenta é que não alcança.

⚠️ **O perigo não é errar — é a direção do erro.** Falso-negativo em critério de AUSÊNCIA se parece
exatamente com sucesso. Um `grep` que erra para mais faz barulho e alguém investiga; um que erra para
menos entrega uma varredura vazia, que é a própria forma da aprovação.

**Solução.** Em qualquer varredura cujo critério seja "não achou nada", use **`rg`** (ou a ferramenta
Grep do harness, que é ripgrep). Vale dobrado em texto português — e a suíte de aceitação de um FR de
limpeza é o caso clássico, porque ela roda uma vez, dá verde e ninguém repete.

**Regra curta:** antes de aceitar "a busca não achou nada", pergunte se a busca **conseguiria** achar.

**Vizinhos:** [#texto-em-array-de-props-escapa-de-tudo](texto-em-array-de-props-escapa-de-tudo.md) — lá a
string existe em formato que a busca não prevê; aqui ela está em formato previsto e a ferramenta é que
falha. [#psql-sem-contexto-mede-rls-nao-o-dado](psql-sem-contexto-mede-rls-nao-o-dado.md) — mesma família:
o instrumento cega, e a cegueira se parece com aprovação.

**Ref:** Empresa Milionária, 2026-08-17. Achado por um subagente que rodou as duas ferramentas no mesmo
padrão e reportou a divergência em vez de confiar na primeira.
