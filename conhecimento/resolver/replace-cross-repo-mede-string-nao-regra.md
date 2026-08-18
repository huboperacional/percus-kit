## Replace cross-repo por string literal mede a STRING, não a REGRA — e meio par commitado é pior que nenhum {#replace-cross-repo-mede-string-nao-regra}

tags: varredura cross-repo, replace literal, convencao, redacao divergente, CLAUDE.md, AGENTS.md, par de arquivos, auditoria por conceito, palavra proibida, repo em freeze, arquivado, propagacao de regra

**Sintoma:** a varredura "corrige a convenção em todos os projetos" reporta N arquivos alterados e
soa completa. Depois de commitada, ainda há repo dizendo a regra antiga — e pelo menos um repo passa
a **contradizer a si mesmo**.

**Causa raiz:** o replace casou a **redação canônica** (`Comentários no código em **inglês**`). Cada
projeto escreveu a mesma regra com as palavras dele — `Comentários em inglês no código`,
`No código: **inglês**`, `Código em **inglês**, docs/markdown em português`. O replace mede a
string; a convenção é um **conceito**. Todo repo cuja redação divergiu sobreviveu à varredura e
saiu do relatório como "não tinha a regra".

**O agravante, e é o que faz isso valer verbete:** a regra costuma viver em **dois** arquivos por
repo (`CLAUDE.md` e `AGENTS.md`). Se o replace acerta só um e você **commita**, o estado final é
pior que o inicial: antes o repo estava uniformemente errado, agora está internamente contraditório
— e o revisor cross-provider lê o `AGENTS.md` como fonte de regra, então ele passa a cobrar a regra
velha contra código escrito na regra nova.

**Solução — auditar por conceito, não pela frase substituída.** Depois do replace, varra a
**palavra proibida** nos dois arquivos de todos os repos:

```powershell
Select-String -Path $fp -Pattern 'ingl' -Encoding utf8 |
  Where-Object { $_.Line -match '(?i)coment|c.digo|code' }
```

Só isso acha as redações divergentes. Espere falso positivo de **menção histórica** ("a regra dizia
inglês e foi corrigida em ...") — leia o contexto antes de editar, não é ocorrência a consertar.

**Antes de commitar o par:** confira que os dois arquivos do repo concordam. Commit de meio par é a
única saída que produz um estado inconsistente que ninguém pediu.

**E tire da varredura o repo em freeze/archive.** Mudar convenção de comentário de código onde não
vai entrar código é ruído puro — o próprio review cross-provider barra como violação do cutover, e
ele está certo.

**Ref:** 2026-08-14, propagação da convenção PT-BR em 13 projetos Percus. `Plexco Coach` escapou do
replace pela redação e ficou com `AGENTS.md` novo e `CLAUDE.md` velho até o review apontar;
`Plexco Tickets` (freeze desde 2026-05-24) teve a mudança revertida. Ver
`varredura-cross-repo-esbarra-em-r11` para o custo de **commitar** a mesma varredura em N repos.
