## Retrato de árvore compartilhada vence em minutos — conclua da medição mais nova, não da que já estava na tela {#retrato-de-arvore-compartilhada-vence-em-minutos}

`tags: git status, snapshot, estado compartilhado, sessao paralela, inferencia, atribuicao, reset --soft, create mode, staging, medicao, re-medir, coordenacao entre janelas`

**Sintoma:** você conclui com confiança sobre o estado de um repositório e a conclusão está errada —
não porque o dado estava errado, mas porque ele **descrevia outro momento**. O `git status` que você
tem na tela foi verdadeiro quando rodou.

**Duas ocorrências no mesmo dia (2026-09-12, `percus-kit`, ~6 janelas ativas), a mesma raiz:**

1. **Autoria.** Um arquivo apareceu `??` no meio da sessão. O `git status` do início da sessão não o
   listava, então concluí *"outra sessão está escrevendo agora"*. O operador disse que não havia
   outra sessão; aceitei e reescrevi a conclusão. Estava certo o sinal e errada a minha desistência —
   mas o erro de método veio antes: **o snapshot do início da sessão não descrevia o presente**, e eu
   o usei como se descrevesse.
2. **Staging.** Às 20:25 medi a árvore: um pacote de 16 arquivos estava `??`. Às 20:49 uma janela
   commitou sem pathspec, levou os 16, e desfez com `git reset --soft`. Concluí que *"o reset
   promoveu untracked a staged"* e pedi que ela desestagiasse. **Falso.** Entre 20:25 e 20:49 — 24
   minutos que eu não contabilizei — a dona do pacote estagiou tudo, deliberadamente, provavelmente
   preparando o commit. Desestagiar teria atropelado o trabalho dela minutos antes de ir.

**O comando que desempatou o segundo caso, e que vale guardar:**

```bash
git show --summary <commit> | grep "create mode"
```

**Commit não cria arquivo untracked** — só entra no commit o que já estava no índice. Se aparecem
linhas `create mode`, aqueles arquivos **estavam estagiados antes do commit**. Isso separa "o reset
promoveu" de "o reset restaurou" em um comando, e resolveu o que a discussão não resolvia.

**Por que é traiçoeiro:** medição não parece opinião. Um `git status` colado na conversa carrega a
autoridade de um fato, e continua carregando depois de envelhecer. Quanto mais rigorosa foi a
medição original, mais confiança indevida ela empresta à inferência feita meia hora depois.

**A regra:** em árvore compartilhada, **retrato tem validade de minutos**. Antes de *agir* sobre o
estado — commitar, desestagiar, pedir que alguém desfaça algo — **re-meça**, mesmo que você tenha
medido há pouco e nada indique mudança. Antes de *concluir* sobre um intervalo, verifique que a sua
medição cobre as duas pontas dele: duas observações em pontas diferentes não descrevem o meio.

**O consolo técnico, dado por uma janela que acertou onde eu errei:** ela não re-mediu por
desconfiança, re-mediu **por hábito de commit** — e foi essa re-medição que lhe deu álibi em vez de
opinião. A diferença não foi cuidado, foi o número de vezes que o comando rodou. Logo o conserto não
é "seja mais cauteloso": é **tornar a re-medição um passo fixo**, que roda sem precisar de suspeita.

**Discriminante:** sua conclusão depende de um estado que **outra sessão pode ter mudado**? Então ela
depende de *quando* você mediu, e o "quando" tem que entrar na conta explicitamente. Se você não
consegue dizer a que horas foi a sua medição e a que horas é o fato que quer explicar, você não tem
uma inferência — tem uma coincidência.

**O agravante não é errar: é descobrir e não voltar.** Caso medido no mesmo dia, em outro projeto e
por outra janela, com a mesma forma. Uma auditoria afirmava *"o que está no ar segue sendo o commit
de 08/09"* — conclusão sobre o meio a partir de duas pontas (*"o HEAD não compila, logo não pode
estar em produção"* + *"o último deploy documentado foi em 08/09"*). Horas depois, a mesma janela
abriu o site e achou uma combinação que **não existe em commit nenhum**: um card de hoje ao lado de
um cabeçalho de 08/09. Registrou o achado **numa seção nova** — e deixou a afirmação original de pé.
O documento passou a se contradizer consigo mesmo, com duas páginas de distância, e ia ser lido
assim.

Daí um passo que não é óbvio e fecha o buraco: **ao registrar um achado que contradiz algo que você
já escreveu, `grep` pela afirmação antiga e mate.** Procure **pelo que você afirmou**, não pelo que
descobriu — o texto velho não contém as palavras do achado novo, então buscar pelo achado não acha a
contradição. É a mesma economia da R25: informação em dois lugares diverge, e aqui os dois lugares
estavam no mesmo arquivo.

E o reparo é melhor quando substitui o **raciocínio**, não só o fato: quem lê aprende mais com *"eu
concluí sobre o meio"* do que com *"produção não pode ser datada assim"*.

**A afirmação vencida nem sempre vira falsa — às vezes vira órfã. E órfã não dispara alarme em
leitura nenhuma.** Quando a mesma janela rodou a disciplina acima no próprio documento —
`grep` por *"não reverificado"*, *"nunca aberta no navegador"*, *"não reconferido"*, isto é, pelas
**afirmações**, não pelos achados — saíram **cinco** linhas contraditas pelo trabalho da própria
noite. Quatro eram do tipo simples: diziam "não verificado" sobre coisas que tinham sido medidas
horas depois.

A quinta era de outra natureza e é a que ensina. Ela rastreava como **pendente** o ajuste de um
componente que **ninguém renderiza mais**: o componente virou órfão quando outra tela passou a usar
um shell diferente, e o plano seguia rastreando a cor de um botão numa tela morta. Lida sozinha, a
linha continuava fazendo sentido perfeito — o sujeito da frase é que tinha deixado de existir. Só
olhando o código se vê.

Essa é a diferença que importa: contradição factual pode ser pega relendo, porque o texto passa a
soar errado. **Item que envelheceu de categoria — de "pendente" para "inexistente" — nunca soa
errado.** Por isso o `grep` pela afirmação antiga tem que ser um passo mecânico e não um instinto:
o instinto só dispara no primeiro tipo. (No caso, a limpeza fechou sozinha: `grep` no repositório
inteiro sem nenhuma referência ao componente, build e 264 testes verdes depois de removê-lo.)

Ver [[nome-de-sessao-muda-a-cada-reconexao-e-anunciar-nao-basta]] (a metade sobre identidade: *mtime
prova QUANDO, nunca QUEM*) e
[[cd-para-inspecionar-repo-alheio-deixa-a-sessao-apontada-para-ele]].
