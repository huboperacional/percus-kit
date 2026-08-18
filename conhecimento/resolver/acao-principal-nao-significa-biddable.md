## "Ação principal" no painel de anúncios NÃO significa que guia o lance — são 3 camadas, não 1 {#acao-principal-nao-significa-biddable}

tags: google ads, conversao, primary_for_goal, biddable, conversion goal, todas as conversoes, all_conversions, smart bidding, relatorio inflado, perfil da empresa, local actions

**Sintoma.** O painel mostra uma ação de conversão como **"Ação principal"**, e você conclui que ela
está guiando o lance / poluindo o Smart Bidding. Ou o contrário: a coluna "Todas as conversões"
mostra 199/mês e a "Conversões" mostra 7, e você não sabe qual é a real.

**Causa raiz.** "Principal" é um rótulo com **escopo de meta**, não de conta. Uma ação só influencia
o lance se **três** condições valerem juntas — e o painel só mostra a primeira:

```
1. conversion_action.primary_for_goal              <- o rotulo "Acao principal"
2. conversion_action.include_in_conversions_metric <- entra na coluna "Conversoes"?
3. customer_conversion_goal.biddable               <- a META dela otimiza?  (a que decide)
   + campaign_conversion_goal.biddable             <- ...e nesta campanha?
```

As ações do **Perfil da Empresa** (`Local actions - Directions`, `- Other engagements`,
`Store visits`, `Clicks to call`…) vêm com `primary_for_goal = true` e
`include_in_conversions_metric = false`, e as metas delas (`Ver rota`, `Engajamentos`,
`Visita à loja`) vêm com `biddable = false`. **Ler só a camada 1 leva à conclusão oposta da
verdade.** Elas também **não são editáveis** — quem gere é o Google.

O inverso também morde: ação de **upload** (`type = UPLOAD_CLICKS`, típica de integração própria de
CRM) nasce com `primary_for_goal = false` **e** `include_in_conversions_metric = false`. Ela recebe
o dado, responde 200, aparece em "Todas as conversões" — **e não conta nem guia lance**. Na conta
onde isso foi visto, ficou assim **4 meses** com o Smart Bidding cego enquanto tudo respondia OK.

**Solução.** Consulte as três camadas antes de afirmar qualquer coisa:

```sql
-- camadas 1 e 2
SELECT conversion_action.name, conversion_action.primary_for_goal,
       conversion_action.include_in_conversions_metric, conversion_action.origin
FROM conversion_action WHERE conversion_action.status = 'ENABLED'

-- camada 3 (a que decide)
SELECT customer_conversion_goal.category, customer_conversion_goal.origin,
       customer_conversion_goal.biddable
FROM customer_conversion_goal

-- e se a campanha usa metas proprias
SELECT campaign.name, campaign_conversion_goal.category,
       campaign_conversion_goal.origin, campaign_conversion_goal.biddable
FROM campaign_conversion_goal WHERE campaign.status = 'ENABLED'
```

Para **relatório ao cliente**, use sempre a coluna **`Conversões`** (`metrics.conversions`), nunca
`Todas as conversões` (`metrics.all_conversions`) — a segunda mistura rota no mapa e visita à loja
com lead, e apresentada como resultado de mídia promete o que a campanha não entregou.

**Dois alertas do painel que são falso positivo** nesse cenário, e cujo botão é perigoso:
- *"Não está recebendo dados porque não há conexões associadas"* → olha o registro de conexões do
  Gerenciador de Dados; upload por API com conta de serviço não aparece lá. **Clicar em "Conectar
  fonte de dados" cria um 2º caminho de importação** → duplica conversão ou sobrescreve o destino.
- *Conversões otimizadas: "nenhuma tentativa com dados fornecidos pelo usuário"* → pede PII com
  hash; quem manda identificador de clique nunca vai satisfazer.
Em ambos, **a prova de que chega dado são as conversões registradas**, não o alerta.

**Ref:** Paid Media Automation, Imobiliária UNI (customer 5977410135), 2026-08-10. Padrão completo
do produto, com checklist pra tela nova: `docs/PADRAO_METRICA_CONVERSOES.md`. Errei essa leitura
duas vezes na mesma sessão (rótulo do nome da conversão, depois rótulo "principal") antes de ir
olhar a camada da meta.
