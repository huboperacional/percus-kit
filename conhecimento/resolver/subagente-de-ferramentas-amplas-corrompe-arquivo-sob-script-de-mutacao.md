## Um subagente de ferramentas amplas rodando junto com um script de mutação corrompe o arquivo-alvo, silenciosamente {#subagente-de-ferramentas-amplas-corrompe-arquivo-sob-script-de-mutacao}

`tags: subagente, Agent tool, mutação, mutation testing, race condition, general-purpose, Tools *, working tree, corrupção silenciosa, TDD, cross-claude-review`

**Sintoma:** um bloco de código que você nunca editou intencionalmente aparece alterado — não
com erro de sintaxe, não com marca óbvia, mas com um **condicional inteiro removido**, um `if X
else Y` virando só `Y`. Os testes daquele trecho específico começam a falhar quando rodados sós,
mas uma suíte maior rodada minutos antes tinha passado limpa. `git diff` contra o HEAD confirma:
o commit está correto, só o **working tree** está errado.

**Causa raiz:** um script de mutação (`scripts/mutacao*.py` no padrão deste kit) segue o ciclo
`read original bytes → write mutated bytes → roda testes → restore original bytes`, tudo sobre
o MESMO arquivo em disco, várias vezes em sequência. Se, na janela entre o write mutado e o
restore, **outro processo com permissão de escrita** tocar o mesmo arquivo — um subagente
dispatchado com `Tools: *` (ex.: `general-purpose`, usado pra um review Cross-Claude) que decida
explorar/rodar algo no meio do caminho — o restore final do script de mutação sobrescreve
**por cima** de qualquer edição legítima feita nessa janela, ou o subagente lê/edita uma versão
já mutada e deixa uma mistura dos dois.

**Por que passa despercebido:** o script de mutação **sempre imprime "arquivo restaurado" e sai
com código 0** quando termina normal — nada no output dele indica que houve uma escrita externa
no meio. Rodar a suíte completa LOGO DEPOIS pode até passar (se a corrupção não tocar o caminho
que a suíte exercita naquele momento), dando falsa confiança; a corrupção só aparece quando um
teste isolado ou um caso de borda específico é exercitado depois.

**Como evitar:**

1. **Nunca dispatch um subagente de ferramentas amplas (`Tools: *`) enquanto um script de
   mutação estiver rodando sobre o mesmo repositório** — mesmo que o subagente só tenha
   instrução de "revisar" (read-only por intenção não é read-only por ferramenta: o subagente
   tem acesso a Bash/Edit e pode rodar qualquer coisa).
2. Prefira rodar scripts de mutação **em foreground** ou aguardar a notificação de conclusão
   antes de iniciar qualquer outro trabalho que edite arquivos no mesmo repo — inclusive edições
   suas, feitas diretamente, no mesmo arquivo-alvo (`ALVO_ARQ`).
3. **Antes de commitar**, sempre `git diff HEAD` no arquivo tocado e leia o diff inteiro — não
   confie em "os testes passaram" sozinho. Se algo no diff não corresponde a uma intenção sua,
   compare contra `git show HEAD:<arquivo>` pra confirmar se a divergência é do working tree
   (corrupção local, sem risco pro histórico) ou já estava no commit anterior (bug real,
   pré-existente).
4. Depois de qualquer suspeita, re-rode a suíte completa E a bateria de mutação **do zero**,
   não confie em resultados obtidos antes da correção.

**Ver também:** [[fixture-que-mente-faz-a-mutacao-mentir-junto]] — outra classe de contra-prova
de mutação que parece confiável e não é · [[duas-sessoes-mesmo-working-tree-arquivo-staged-some-e-volta]]
— a mesma família de colisão transitória, mas entre duas sessões Claude, não entre um subagente e
um script de mutação.
