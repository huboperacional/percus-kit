## Escape de gate libera o SEU commit e deixa o repo barrando TODA sessão {#escape-de-gate-deixa-o-repo-bloqueando-toda-sessao}

`tags: gate, PERCUS_GATE_OVERSIZE, escape declarado, teto de arquivo, CONTEXT.md, HANDOFF.md, arvore compartilhada, multi-sessao, bloqueio coletivo, drift, condicao pre-existente`

**Sintoma:** um gate de tamanho barra o commit. Você declara o escape com um motivo honesto, o
commit passa, e você segue. Minutos depois, **outra sessão** — que não tocou naquele arquivo —
bate no mesmo gate e tem de declarar escape também. E a seguinte. E a seguinte.

**A confusão que causa isso** é ler o escape como se ele fosse sobre a *ação*. Não é: o gate mede
o **estado do arquivo no repositório**. Seu escape libera a sua gravação; o arquivo continua acima
do teto para todo mundo que vier depois. Escape serve para uma condição **pontual** — nunca para
deixar o repo num estado que cobra escape de quem não causou nada.

O próprio gate avisa: *"escape reincidente vira achado do `loops/drift.md` — é sinal de desenho
errado"*. Se cada sessão contorna, a regra morre por uso, e ninguém decidiu isso.

**Caso medido (Empresa Milionária, 2026-09-02).** O `CONTEXT.md` tinha **exatamente 150 linhas** —
o teto — com 23 verbetes, antes do módulo novo existir. A sessão acrescentou 34 linhas de
vocabulário (já encurtadas de 54), declarou o escape, e commitou. A sessão vizinha bateu no gate
no commit seguinte, foi conferir, viu o arquivo **limpo** e acima do teto, e avisou em vez de
cortar — decisão certa, e é por isso que a causa apareceu.

**O diagnóstico só fecha quando você mede a BASE.** *"Meus verbetes estão gordos"* era falso: a
base já estava no limite, então **qualquer linha nova quebrava**. Sem medir
`git show HEAD~1:arquivo | wc -l`, o esforço vai para encurtar o próprio texto — que não resolve.

**O que fazer**

1. **Desfaça primeiro, discuta depois.** O bloqueio coletivo é dano em curso; a decisão estrutural
   (subir o teto / dividir o arquivo) pode esperar, ele não.
2. **Meça a base antes de culpar o seu acréscimo.** Arquivo no teto não aceita nada.
3. **Não apare conteúdo alheio para caber.** Se as entradas existentes carregam significado, cortar
   remove informação e some com o sintoma — a causa fica de pé para o próximo tropeçar.
4. **Dê outra casa ao conteúdo.** Vocabulário de módulo cabe na spec dele; histórico cabe em
   `docs/historico/`. O gate está dizendo *"este arquivo não é o lugar"*, não *"escreva menos"*.
5. **Leve a decisão de teto ao operador**, e diga que até ela chegar o arquivo não cresce.

**Anti-sinal:** você declarou escape e o arquivo continua acima do teto ao fim do turno. Isso não é
um commit liberado — é uma armadilha armada para a próxima sessão.
