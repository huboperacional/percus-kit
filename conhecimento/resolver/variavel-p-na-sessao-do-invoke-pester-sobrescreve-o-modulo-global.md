## Variável `$p` na mesma sessão do `Invoke-Pester` grava por cima do módulo Pester global {#variavel-p-na-sessao-do-invoke-pester-sobrescreve-o-modulo-global}

`tags: pester, invoke-pester, variavel de sessao, $p, escopo, powershell, modulo global, Pester.ps1, sobrescrita, sabotagem, teste, maquina inteira quebra, dot-source`

**Sintoma:** de repente **todo** `Invoke-Pester` da máquina falha — inclusive em outros worktrees e
outras sessões — com erro de parse num arquivo que não é teste. O arquivo quebrado é
`<Documentos>\PowerShell\Modules\Pester\<versão>\Pester.ps1`, e o conteúdo dele virou o texto de um
arquivo do projeto.

**Caso medido (2026-09-16, onda paralela do MDS no percus-kit).** Um implementador fazia a sabotagem
exigida pelo contrato: guardava o caminho do checklist numa variável `$p`, rodava `Invoke-Pester`,
e depois gravava de volta o conteúdo original com `[IO.File]::WriteAllText($p, ...)`. O `Pester.ps1`
do módulo é carregado por dot-source (`. $ScriptBlock`) no escopo da sessão, e também usa `$p`.
Depois do `Invoke-Pester`, `$p` apontava para o `Pester.ps1` — e a "restauração" gravou o
`spec-checklist.template.md` por cima do módulo. Das 10:43 às ~10:50, todos os `Invoke-Pester` dos
outros 5 agentes da máquina quebraram; dois deles restauraram o arquivo do pacote oficial do
PowerShell Gallery.

**Por que é perigoso:** o dano não fica no worktree. O módulo é global do usuário, então uma escrita
errada de um agente derruba os testes de todas as sessões ao mesmo tempo, e o erro aparece longe da
causa (parse de um arquivo que ninguém editou de propósito).

**Como evitar:**
- Em script ou sessão que roda `Invoke-Pester`, **não use nomes curtos e genéricos** (`$p`, `$f`,
  `$path`, `$file`) para caminho que você vai GRAVAR depois. Use nome específico (`$caminhoChecklist`).
- Melhor ainda: faça a sabotagem e a restauração em **processo separado** (`pwsh -NoProfile -File`),
  ou guarde o conteúdo original num arquivo de backup com hash e restaure conferindo o hash.
- Antes de gravar de volta, confira que o caminho é o esperado (`if ($alvo -notlike '*<worktree>*') { throw }`).

**Como consertar:** baixe o pacote oficial da mesma versão (`Save-Module Pester -RequiredVersion <v>`
numa pasta temporária), copie o `Pester.ps1` e confira `Get-AuthenticodeSignature` = `Valid` em todos
os `.ps1` do módulo. Não confie em "voltou a funcionar": assinatura inválida é arquivo alterado.

**Relacionado:** [[guarda-verde-porque-nao-mede-nada]] (sabotagem mal feita também engana) ·
[[escape-unicode-escrito-pelo-agente-chega-ao-disco-como-o-caractere]] (outra escrita do agente com efeito fora do alvo).
