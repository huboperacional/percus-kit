## Vigia que lê ausência: o discriminador é CONTROLE POSITIVO no domínio de falha do MEDIDOR, não a fração da população {#controle-positivo-por-dominio-de-falha-do-medidor}

`tags: watchdog, ausencia como sinal, controle positivo, dominio de falha, coletor, fracao da populacao, cegueira parcial, falso positivo em massa, desativacao automatica, guard, R23`

**Origem:** Paid Media Automation, 2026-09-06 — fechando com código o risco que o
`client_account_watch` (vigia que desativa cliente sem gasto) carregava documentado e **aceito sem
mitigação** por duas sessões.

**O defeito da classe.** Um vigia lê uma fonte de dados e trata **ausência de registro** como sinal
ruim. Ausência tem duas causas opostas: o sujeito parou (fato sobre ele) ou o **medidor** cegou
(fato sobre nós). Se o vigia soma as duas no mesmo contador e o contador termina em ação
destrutiva, uma falha do medidor pune sujeitos inocentes — e pune **todos de uma vez**, porque a
causa nossa é idêntica para todo mundo.

🔑 **O discriminador certo: o instrumento provou que funcionou HOJE?** Não "quantos estão ruins",
mas "existe evidência positiva de que o medidor rodou". E a granularidade dessa pergunta é o
**domínio de falha do medidor** — a unidade que quebra junto. Se há um coletor por plataforma, a
pergunta é por plataforma:

> Se **alguma** conta da plataforma P reportou valor > 0 no dia D, o coletor de P rodou → ausência
> em P é fato sobre a CONTA. Se **nenhuma** reportou, não há prova de que o instrumento funcionou,
> e ausência em P não é atribuível ao sujeito.

⚠️ **Por que a FRAÇÃO da população é pior — e este verbete corrige a recomendação anterior**
([[watchdog-de-ausencia-le-depois-do-produtor]] sugeria a fração). Dois furos:

1. **Ruído em população pequena.** Numa carteira de 10, um fim de semana com metade dos sujeitos
   legitimamente parados dá fração alta → suspensão → alerta que ninguém fecha.
2. **Cega para a cegueira PARCIAL, que é o caso mais comum.** Um coletor no chão e o outro de pé
   deixa metade dos sujeitos `ok`, a fração global baixa, o gate passa — e a metade cega é contada
   errado. A fração só enxerga o apagão total, que é o caso fácil.

O controle positivo pega os três: apagão total, cegueira parcial, e o vigia rodando **antes** do
produtor.

**Como aplicar, na ordem:**
1. **Qual é o domínio de falha do medidor?** (um coletor por plataforma? por região? por token?)
   O controle positivo se apura NESSA unidade, não globalmente e não por sujeito.
2. **Suspenda só quem depende do domínio sem prova.** Sujeito cujo registro EXISTE com valor zero
   é fato medido e conta normalmente — **só a ausência é suspeita**. Um filho cego contamina o pai
   (não dá para afirmar "não gastou em lugar nenhum" com uma conta invisível).
3. **Não invente estado para "dia suspenso".** Se a máquina já tem regra de lacuna na cadeia
   ("não verifiquei neste dia → recomeça"), basta **não escrever nada**: o dia suspenso vira uma
   lacuna e a regra existente recomeça o contador. Zero coluna, zero migration.
4. **Um alerta agregado por tick**, não um por sujeito — quando a causa é nossa ela é idêntica
   para todos, e N mensagens iguais são N vezes menos lidas que uma que diz "N sujeitos".
5. **Meça se o guard ficaria calado em dia normal ANTES de ligar.** Aqui: 12 dias de histórico,
   controle positivo presente em 12/12 (GOOGLE 9-12 contas com gasto/dia, META 7-8). Sem essa
   medição você não sabe se criou proteção ou ruído diário.

✅ **O teste que prova que o guard é preciso e não uma anistia:** encontre o caso real em que o
sujeito ESTÁ mesmo parado, numa plataforma COM controle positivo, e prove que o guard **não o
salva**. Sem esse caso você tem um guard que nunca deixa agir e não sabe. No caso real: a conta
Meta do cliente não reportava linha desde 01/09, mas a plataforma teve 8 contas com gasto todos os
dias — `medicao_confiavel = True`, contador segue, desativação mantida.

🟠 **Limite que precisa ficar DECLARADO:** o controle positivo prova que o coletor **rodou**, não
que cobriu **toda** unidade. Falha de token numa conta só continua indistinguível de "essa conta
parou" — dentro do nosso próprio banco é irresolúvel. A saída não é mais guard, é **mensagem**:
nomeie a unidade ausente e a data da última vez que ela reportou, para um humano resolver. Ver
[[agregado-no-pai-esconde-a-ausencia-do-filho]].

⚠️ **E se o domínio tiver poucas unidades**, o controle positivo pode faltar legitimamente e o
vigia para de agir para elas. É aceitável **desde que o alerta seja alto** — o modo de falha vira
"não age e grita", nunca "age errado em silêncio". Meça o inventário antes (aqui: 19 contas META,
15 GOOGLE — instrumento usável).

Relacionado: [[watchdog-de-ausencia-le-depois-do-produtor]] (a medição que originou o problema),
[[zero-so-vale-como-prova-com-controle-positivo]] (o princípio-mãe),
[[mudanca-de-semantica-de-status-faz-o-historico-mentir]] (por que cruzar com o log do produtor
não resolvia).
