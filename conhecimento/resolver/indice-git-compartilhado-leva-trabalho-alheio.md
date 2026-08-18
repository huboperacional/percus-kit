## Adicionar um arquivo ao índice do git e depois fechar o registro sem restringir o escopo pode levar junto o que outro processo já tinha preparado no mesmo diretório {#indice-git-compartilhado-leva-trabalho-alheio}

`tags: git, indice, pathspec, sessão paralela, staged, working tree compartilhado, registro acidental`

**Contexto:** duas sessões Claude Code rodando no MESMO diretório de trabalho (não em git worktrees
isolados), cada uma trabalhando em arquivos diferentes. Uma sessão (Fluxo de Páginas) tinha preparado
os próprios arquivos (6 novos: `page-flow-focus.ts` etc.) no índice, mas ainda não tinha fechado o
registro. A outra sessão, pra fechar um checkpoint de documentação, adicionou só `docs/STATUS.md` ao
índice e em seguida fechou o registro sem informar quais arquivos deveriam entrar.

**Sintoma:** o registro resultante trouxe **12 arquivos**, não 1 — os 6 arquivos alheios (já
preparados pela outra sessão) foram junto, com uma mensagem que não os menciona. Só descoberto porque
o resumo do registro foi conferido logo depois (hábito, não pela suspeita — o número de arquivos bateu
estranho).

**Causa raiz:** adicionar um arquivo específico ao índice só afeta AQUELE arquivo — mas não tem
escopo sobre o que MAIS já estava preparado. Fechar o registro sem informar o escopo processa o índice
INTEIRO, não só o que a última adição tocou. Num diretório exclusivo de uma sessão isso é invisível
(só a própria sessão prepara coisas); num diretório COMPARTILHADO, qualquer preparo alheio anterior
vaza pro seu registro.

**Solução:**
- Antes de fechar QUALQUER registro num diretório que pode ter atividade paralela: conferir o estado
  completo do índice, **sem filtro que esconda linhas** (um filtro por nome de arquivo esconde
  exatamente os arquivos alheios que você precisa ver).
- Informar o escopo explícito de arquivos ao fechar o registro também, não só ao preparar — é a rede
  de segurança que funciona mesmo se a conferência prévia for esquecida ou lida rápido demais.
- Se o vazamento já aconteceu e ainda não foi publicado: desfazer só o último registro mantendo TUDO
  preparado (zero perda de conteúdo, nem o seu nem o alheio) → devolver os arquivos alheios pro estado
  "modificado, não preparado" exato de antes → refazer o registro só com o arquivo próprio, com escopo
  explícito desta vez.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.155→156), checkpoint de STATUS.md durante
sessão paralela "Fluxo de Páginas" ativa no mesmo diretório.
