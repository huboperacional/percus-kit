## Watchdog que trata AUSÊNCIA como sinal ruim tem que ler depois do produtor — e quando ele erra, erra a população INTEIRA {#watchdog-de-ausencia-le-depois-do-produtor}

`tags: watchdog, ausencia de dado, janela de horario, cron, dia-alvo, coletor, falso positivo em massa, discriminador barato, desativacao automatica, dry-run que pagou o custo, R23`

**Origem:** Paid Media Automation, 2026-09-06 — dry-run do `client_account_watch` (vigia que
desativa cliente sem gasto) contra o banco de produção, antes de ligar o cron.

**O que foi medido.** O MESMO job, no MESMO banco, com a única diferença sendo o relógio:

| `now` | dia-alvo | veredito |
|---|---|---|
| 09:52 UTC (horário do cron) | D-1, já coletado | **9 `ok`, 1 `sem_gasto`** |
| 02:30 UTC (invocado à mão) | D-1, ainda NÃO coletado | **10 de 10 `sem_gasto`** |

O coletor grava D-1 às 04:00 UTC; o vigia lê às 09:52. Entre a virada do dia e as 04:00 há uma
janela de ~4h em que "não existe linha para D-1" é uma verdade sobre a **nossa coleta**, não sobre
o sujeito medido — e o job não tem como saber a diferença.

🔑 **A lição que não estava no desenho.** O risco já estava documentado, mas escrito como se
atingisse *um* sujeito por vez ("um cliente pode ser desativado por defeito nosso"). A medição
mostrou outra forma: **quando a causa é nossa, ela é idêntica para todos**, então a população
inteira entra em "dia 1 de N" no mesmo tick. Isso muda a gravidade (não é um caso a investigar, é
um desligamento em massa) e, ao mesmo tempo, entrega a defesa de graça.

⚠️ **O discriminador mais barato é a FRAÇÃO DA POPULAÇÃO, e quase ninguém o usa.** 1 de 10 ruins é
um caso; 10 de 10 ruins no mesmo minuto é a assinatura de que o problema é do **medidor**. Esse
sinal já está na mão do job — ele acabou de classificar todo mundo — e não custa nenhuma consulta
nova. Compare com a mitigação que dois reviewers independentes recomendaram no mesmo marco (cruzar
com o log do produtor): ela custa uma consulta, dá sensação de proteção e **não distingue** os dois
casos que importam, porque o status "zero linhas sem exceção" cobre tanto "o sujeito parou" quanto
"nós cegamos". Ver [[mudanca-de-semantica-de-status-faz-o-historico-mentir]].

**Como aplicar.** Antes de revisar qualquer regra de um vigia que leia ausência como sinal ruim,
responda duas perguntas — nesta ordem, antes de olhar o resto do código:

1. **Quem PRODUZ o dado que este job lê, e este job roda depois dele com folga?** Escreva a margem
   em horas. Se não souber dizer, o job não está pronto para ligar.
2. **Se o produtor falhar, quantos sujeitos ficam ruins de uma vez?** Se a resposta for "todos",
   exija que a fração da população afetada participe da decisão — nem que seja só para segurar a
   ação destrutiva e gritar mais alto.

⚠️ **Consequência operacional imediata, que vale para todo job diário deste tipo:** nunca invoque o
job à mão sem fixar o `now` dentro da janela pós-produção. No caso medido, rodar o smoke às 02:30
UTC teria gravado 10 contadores falsos e disparado 10 mensagens reais no canal de negócio — o
"teste" produzindo exatamente o incidente que ele existia para prevenir.

**Nota de método:** este achado só apareceu porque o dry-run foi rodado em **dois instantes
diferentes** de propósito, e não uma vez só. Um dry-run de uma foto responde "a lista está certa?";
dois instantes respondem "de que a lista depende?" — e é a segunda pergunta que encontra a
armadilha.

Relacionado: [[mudanca-de-semantica-de-status-faz-o-historico-mentir]].
