## Fix commitado depois do teardown herda um verde que nunca teve {#fix-depois-do-teardown-herda-o-verde}

`tags: verificacao, infra efemera, container, teardown, falso verde, timestamp, artefato de rodada, R20, janela de teste, rastreamento`

**Contexto:** infra de teste efêmera (container, túnel, ambiente descartável) vive numa janela. O
teste falha perto do fim dela, alguém corrige, commita — e a correção entra no registro como se
estivesse provada. Ninguém mente: a narrativa de fechamento é escrita depois e descreve a
**intenção** ("corrigido"), não a **evidência** ("rodado verde").

**Caso medido (2026-09-01):** um `HANDOFF.md` afirmava *"3 dos 4 buracos de tela com R1 postgres
PROVADO, sobem para `[5-T]`"* e nenhum dos três tinha rodado. A reconstrução por relógios:

| Hora | Evento |
|---|---|
| 14:21:32 | última rodada — `test-results/.last-run.json` com `status: "failed"` no spec X |
| 14:26:14 | registro de fechamento gravado — **container derrubado** |
| 14:27:56 | commit da reescrita que "corrigia" o spec X |

A correção é **1min42s posterior ao teardown**. Não havia mais infra para exercê-la. O `git log`
não mostra isso: os commits aparecem em sequência limpa e nada indica que o ambiente morreu no meio.

**Como medir, e são três relógios independentes:**

1. `git log --format='%h | %ad' --date=iso-local <arquivo>` — quando o fix foi commitado.
2. O **mtime** do registro de autorização/fechamento da janela — quando a infra caiu. ⚠️ Não use o
   campo de timestamp *dentro* do arquivo: ele costuma marcar a **abertura**, enquanto o texto é
   reescrito no fechamento. Ler o campo como se fosse o teardown produz alerta falso.
3. O artefato da última rodada (`test-results/.last-run.json` no Playwright, equivalente no seu
   runner) — o que de fato passou e o que falhou.

**A assimetria que importa:** o diretório de resultados normalmente só guarda pasta para teste que
**falhou**. Ele refuta ("isto falhou") mas não confirma ("isto rodou e passou"). Para o resto, o
veredito honesto é **INCERTO**, nunca "reprovado" — e "incerto" é uma marca legítima de registrar.

**Corolário sobre onde está a verdade:** quando o documento de estado narrativo (HANDOFF, changelog,
release notes) diverge do rastreamento por tarefa (PLANO, board, issue), aposte no **segundo**. Ele é
escrito no momento da tarefa; o primeiro é escrito no fechamento, e é ali que o otimismo entra. No
caso acima o PLANO dizia *"Falta: R1 postgres"* e estava certo o tempo todo.

Ver também [[a-sabotagem-prova-o-que-voce-imaginou]].
