## Campo novo no contrato JSON entre 2 serviços deployados separadamente fica ausente no frontend se o backend for pra produção primeiro {#contrato-novo-precisa-dos-dois-deploys-juntos}

tags: deploy sequenciado, contrato de api, campo novo, microservico, backend frontend dessincronia, optional chaining, docker service update, breaking change silencioso, feature invisivel

**Contexto:** feature que adiciona um campo novo na resposta JSON de um endpoint (`spendConfidence`),
consumido por uma tela que já lia outros campos do mesmo payload. Backend (`services/tracking`) e
frontend (`web`) são imagens Docker separadas, deployadas via `docker service update` uma de cada
vez, não atomicamente.

**Sintoma:** depois de deployar só o backend (`services/tracking`) com o campo novo, a tela em
produção não mostrava a feature nova — sem erro de console, sem 5xx, só ausência silenciosa.
Investigação inicial suspeitou de bug no cálculo do backend (o valor parecia "errado" por não
aparecer), até checar a network tab e ver que a API **já respondia corretamente** com o campo novo
preenchido — o problema era que o `web` ainda rodava a imagem de ANTES da feature, que nem sabia que
esse campo existia.

**Causa raiz:** dois serviços com um contrato JSON compartilhado, deployados de forma independente e
sequencial (não atômica). Deployar o produtor (backend) do campo novo sem deployar o consumidor
(frontend) na mesma janela deixa uma janela real, em produção, onde o campo existe na resposta mas
o código que deveria lê-lo ainda não existe no ar.

**Por que não quebrou:** o frontend já tinha sido escrito com acesso defensivo (`data.campoNovo?.x
?? 0`) por causa de um achado de code-review — não por antecipação deliberada desse cenário exato,
mas o efeito foi o mesmo: sem esse `?.`, o acesso direto (`data.campoNovo.x`) teria lançado
`TypeError` e quebrado a tela INTEIRA (não só escondido a feature nova) durante essa mesma janela de
dessincronia. A defesa vale mesmo quando "o deploy vai ser rápido" — a janela existe de qualquer
forma.

**Solução:**
1. Ao adicionar um campo novo a um contrato JSON consumido por outro serviço deployado
   separadamente, trate o acesso a esse campo no lado consumidor como **potencialmente ausente**
   (optional chaining + fallback), mesmo que o plano seja deployar os dois juntos — a ordem real de
   `docker service update` não é atômica entre dois `services:` diferentes.
2. Ao fazer o deploy de uma feature que toca contrato entre 2+ serviços, faça os dois `docker
   service update` na MESMA janela — não passe pra outra tarefa entre um e outro. Se notar que só um
   foi feito, o próximo passo é sempre completar o outro antes de considerar a feature no ar.
3. Ao investigar "a feature nova não aparece" em produção, confira a resposta REAL da network tab
   ANTES de suspeitar do cálculo do backend — se o campo já vem certo na resposta, o backend está
   certo e o problema é no consumidor (deploy desatualizado, cache, ou lógica de renderização), não
   na fonte do dado.

**Ref:** Paid Media Automation, sessão 2026-08-07 — feature "confiança do gasto" na tela HubSpot
(`docs/superpowers/plans/2026-08-07-hubspot-spend-confidence-plan.md`). Campo `spendConfidence`
adicionado em `services/tracking/app/modules/crm/hubspot_campaign_performance.py`; consumido em
`web/src/app/dashboard/clients/[id]/(shell)/leads/hubspot-performance/page.tsx` com
`data.spendConfidence?.activeCampaignsNoSpend ?? 0` (achado de code-review da Task 4, commit
`70995670`). Deploy do `tracking`+`tracking-worker` (`spendconf-02c3d357`) feito antes do `web` —
smoke contra D4U (cliente real com 56 campanhas ativas sem gasto) mostrou API correta (`GET
.../crm/hubspot/campaign-performance` já retornava `spendConfidence` certo) mas banner ausente na
tela; corrigido buildando e deployando `web:spendconf-02c3d357` na sequência. Lição registrada
também no `docker-compose.swarm.yml` do projeto, no comentário do pin.
