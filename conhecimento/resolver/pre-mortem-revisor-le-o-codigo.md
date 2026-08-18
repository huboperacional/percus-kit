## Pre-mortem de plano: mande o revisor LER o código, não só o plano {#pre-mortem-revisor-le-o-codigo}

`tags: pre-mortem, conselho, plano, revisor, ler o codigo, arquivos vizinhos, cross-claude, tool use, teste que passa com bug vivo, funcao isolada, caminho real`

Um plano de 5 tasks para "a transcrição parar de sumir" estava **correto em tudo que afirmava** e
ainda assim **não mudaria nada em produção**. Ele consertava o truncamento em dois lugares que
conhecia (`tasks_bot_v1.py`, `_triagem_create.py`) e ignorava um terceiro, **anterior aos dois**,
que era o que decidia (`wa_media_enrich.py:155` cortava em 255 antes de o handler ser chamado).

O revisor que leu **só o plano** (Llama) não tinha como ver. O que leu **os arquivos citados**
(Cross-Claude, 27 tool-uses) achou em uma passada — e achou junto que o teste do plano **passaria
com o bug vivo**, porque exercitava a função isolada em vez do caminho real.

**Regra prática:** no pre-mortem, liste no prompt os arquivos que o plano toca **e os vizinhos do
caminho de execução**, e peça explicitamente: *"o plano faz afirmações sobre estes arquivos —
verifique"*. Um plano internamente coerente pode estar consertando o lugar errado, e essa classe de
erro é invisível de dentro do documento.

**Sinal de alerta correlato:** se o teste do plano chama a função diretamente com dados "limpos",
pergunte de onde vêm os dados **em produção**. Foi exatamente a diferença entre verde falso e
verde real.

Visto em: Plexco Tasks, s151 (2026-07-27).
