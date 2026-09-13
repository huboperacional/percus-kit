## Nome de sessão MUDA a cada reconexão — e "anunciar" o arquivo não basta: espere a RESPOSTA antes de escrever na árvore compartilhada {#nome-de-sessao-muda-a-cada-reconexao-e-anunciar-nao-basta}

`tags: ListAgents, SendMessage, sessao paralela, sessão paralela, multi-sessao, janela, reconexao, reconexão, nome de sessao, identidade, prompt de retomada, checkpoint, arvore compartilhada, árvore compartilhada, HANDOFF, git apply -R, coordenacao entre janelas`

**Sintoma.** O prompt de retomada diz *"esta janela era a `tiatendo-ce`"*; o `ListAgents` diz que
você é a `tiatendo-34`. Um peer responde que **ele** é a `ce`, renomeado. Horas depois o `ListAgents`
diz que você é a `e4`, depois a `27`, e a principal que se chamava `ac` agora se chama `a3`. Nome
gravado em `HANDOFF.md` ou `COORDENACAO-JANELAS.md` na véspera já não resolve para ninguém.
Segundo sintoma, na mesma sessão: você anuncia por mensagem *"vou editar o HANDOFF"*, edita **um
minuto depois** — e a resposta chega dizendo *"estou consolidando os 3 artefatos, espere"*. Seu
trecho já está na árvore que a outra janela vai commitar.

**Causa raiz.** O nome de sessão é atribuído **na conexão**, não no transcript: cada reconexão (VS
Code dormindo, retomada de dia seguinte) gera sufixo novo para a MESMA conversa. Prompt de retomada
que afirma identidade descreve a conexão que o escreveu, não a que o lê. E o anúncio de arquivo é
**assíncrono**: ele vira combinado só quando o outro lado RESPONDE — antes disso é uma intenção que a
outra janela ainda não leu.

**Correção.**
1. Prompt de retomada fala do **TRABALHO** ("a frente X foi feita por uma janela chamada `ce`,
   depois `93`"), nunca "esta janela era a X". A primeira instrução é *rode `ListAgents` e pergunte
   por mensagem quem é quem antes de assumir papel*.
2. Ao receber um prompt assim: `ListAgents` **antes** de ler o resto; a frase de identidade é
   hipótese.
3. Registro em doc de coordenação cita **a cadeia** de nomes (`34→e4→27`) e o **papel**, não um nome só.
4. Anunciou arquivo? **Espere a RESPOSTA do peer** antes de escrever. `notify_when_idle` **não**
   substitui isso: ele é one-shot, avisa que o peer PAROU (ou saiu), não que ele concordou — e só
   funciona da conversa principal, com peer na mesma máquina. Serve para saber quando perguntar de
   novo, não para liberar a escrita.
5. Já escreveu e o peer está consolidando? `git diff HEAD -- arquivo > full.diff` (**`HEAD`**, não
   `git diff` seco: se o seu hunk já foi estagiado, o diff seco sai VAZIO e o `apply -R` seguinte é
   no-op silencioso — vazio aqui significa *já está no índice*, não *não há nada seu*). Separe **seu**
   hunk, `git apply -R seu.patch`, confira que só o hunk do peer ficou, e reaplique depois do commit
   dele. Commit sempre com pathspec e só o seu hunk no índice (`git diff --cached`).

**Armadilha de método.** Acreditar na primeira linha e "conferir depois" não desfaz a crença — a
verificação tem que vir ANTES da afirmação. E `mtime` de um hunk alheio prova QUANDO, nunca QUEM:
pergunte à janela viva, não à árvore. Verbetes irmãos:
[[commit-sem-pathspec-leva-o-indice-de-todas-as-sessoes]],
[[duas-sessoes-mesmo-working-tree-arquivo-staged-some-e-volta]].

**Ref:** tIAtendo, janelas paralelas, 09-12/09/2026 (`ce`→`93`, `ac`→`a3`, `34`→`e4`→`27`).
