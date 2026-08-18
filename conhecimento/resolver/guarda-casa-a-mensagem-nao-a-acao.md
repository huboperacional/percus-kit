## Guarda de ação externa barra o COMMIT porque a MENSAGEM cita a ação {#guarda-casa-a-mensagem-nao-a-acao}

`tags: hook, PreToolUse, external-action-guard, R20, push, commit, heredoc, mensagem de commit, falso positivo, matcher, tool_input.command, bloqueio inesperado, uso vs mencao`

**Origem:** percus-kit, 2026-07-31 — um `git commit` foi barrado por uma guarda de push. E depois,
para fechar o círculo, ela barrou também a **escrita deste verbete**, porque o texto aqui contém o
literal que ela casa.

O `external-action-guard` casa padrões (push, `gh pr comment`, `slack-cli`, …) contra
`tool_input.command`, que é a **string inteira** do comando — o corpo do heredoc de `-F -` incluído.
Uma mensagem de commit que *descreve* uma ação externa é, para a guarda, indistinguível de
*executar* uma. Falar sobre a ação vira fazer a ação.

- **Sintoma:** commit bloqueado com `BLOCK (R20)`, e o campo `Comando:` do erro mostra o corpo
  inteiro da mensagem, não um comando externo.
- **Contorno imediato:** reformular ("a mesma ação externa barrada pela tool Bash" em vez do literal),
  ou escrever o arquivo pelo editor em vez de heredoc no shell. O commit é legítimo; quem está
  errado é o casamento.
- **A regra geral:** guarda que casa por regex na linha de comando inteira não distingue **uso** de
  **menção**. Vale para qualquer payload que carregue prosa: `-F -`, `<<EOF`, `-m "..."`. O conserto
  de verdade é casar só o **comando efetivo**, não o corpo.
- **Por que passa despercebido até morder:** o bloqueio parece correto à primeira vista — a string
  *está* ali. Só relendo o `Comando:` inteiro fica claro que ela está dentro do texto.

**Relacionado:** [#fail-open-esconde-teste-vacuo] — o par simétrico: lá a guarda não vê o que devia,
aqui ela vê o que não é.
