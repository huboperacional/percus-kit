## CLAUDE.md aponta pro caminho ANTIGO do canon (`_Novo_Projeto`) — script não existe mais, renomeado pra `percus-kit` {#claudemd-caminho-canon-stale}

`tags: canon renomeado, CLAUDE.md desatualizado, percus-review-auto.ps1, caminho stale, _Novo_Projeto, percus-kit, script nao encontrado, pwsh file nao reconhecido`

**Contexto:** CLAUDE.md de projetos (ex.: tiatendo) instrui rodar `pwsh -File
"D:\Claud Automations\_Novo_Projeto\scripts\percus-review-auto.ps1"` antes de cada commit (R11).
O diretório `_Novo_Projeto` não existe mais — o canon foi renomeado pra
`D:\Claud Automations\percus-kit` em 30/07 (já registrado na memória de projeto
`feedback-projeto-escreve-no-canon-e-normal`), mas o CLAUDE.md de pelo menos um projeto não foi
atualizado pra refletir isso.

**Causa raiz:** renomear o diretório do canon é uma mudança cross-repo que não dispara atualização
automática nos `CLAUDE.md` de cada projeto individual — cada um tem a cópia do caminho antigo
hardcoded, e ela só é descoberta quando alguém tenta rodar o comando de verdade.

**Solução:** se `pwsh -File "...\_Novo_Projeto\scripts\..."` falhar com "The argument '...' is not
recognized as the name of a script file", o caminho real é
`D:\Claud Automations\percus-kit\scripts\<mesmo nome>`. Todos os scripts
(`percus-review-auto.ps1`, `percus-milestone-review-auto.ps1`, e as versões `.sh`) migraram
juntos. Vale a pena, ao achar isso num projeto, também corrigir o `CLAUDE.md` dele pra não repetir
a busca na próxima sessão.

**Ref:** sessão tiatendo, 2026-08-03, frente calculadora de demora (S4) — descoberto ao tentar
rodar o wrapper R11 pela primeira vez na sessão.
