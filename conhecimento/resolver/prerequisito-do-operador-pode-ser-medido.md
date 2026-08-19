## O pré-requisito "ação do operador" pode já estar satisfeito — meça antes de esperar {#prerequisito-do-operador-pode-ser-medido}

`tags: pre-requisito, bloqueio, spec bloqueada, enhanced conversions, google ads api, conversion_tracking_setting, medir antes de esperar, espera desnecessaria, conselho, handoff`

**Contexto:** uma spec fechou com `⛔ BLOQUEADA` em dois pré-requisitos declarados como "ação do
operador", e o HANDOFF repetiu o bloqueio por três sessões. A frente ficou parada esperando.

**Causa raiz:** ninguém tinha **medido** o pré-requisito. Ele era uma **propriedade legível da
plataforma**, não um ato humano pendente: `customer.conversion_tracking_setting.enhanced_conversions_for_leads_enabled`
é um campo GAQL de leitura. Uma consulta de 10 linhas mostrou `True` — já estava ligado, e o
`currency_code` da conta (`USD`) confirmou de quebra uma premissa que a spec só supunha.

**Por que ninguém viu antes:** "pré-requisito do operador" foi escrito uma vez e depois **copiado**
de artefato em artefato (spec → HANDOFF → plano). A frase carrega uma pressuposição — *isto depende
de um humano* — que nunca foi reexaminada. E o bloqueio parecia responsável: esperar é o
comportamento seguro, então ninguém o questiona.

**Como resolver:**
1. Antes de aceitar um bloqueio herdado, pergunte: **isto é um ATO pendente ou um ESTADO legível?**
   Estado se consulta. Configuração de conta, flag de plataforma, permissão, cota, versão — quase
   sempre há um endpoint que responde.
2. Meça com leitura pura (GAQL, `GET`, `information_schema`) e registre o valor **com data**.
3. Se o pré-requisito for composto, meça **cada metade**. No caso real, a flag estava ligada mas a
   *ação de conversão* do evento não existia — metade satisfeita, metade não, e tratar como bloco
   único escondia as duas.
4. Só então reescreva o bloqueio no HANDOFF, dizendo o que foi medido e o que sobrou.

**Sinais de que você está neste caso:** o bloqueio aparece com texto idêntico em 2+ documentos;
ninguém cita um número ou uma data de medição; o "responsável" nunca foi notificado formalmente.

⚠️ **A recíproca:** medir e achar satisfeito **não** libera a frente sozinho — no caso real o
pré-requisito irmão (retenção de PII de terceiro) era decisão genuína de humano e continuou aberto.
Meça para separar o que é estado do que é decisão, não para declarar tudo desbloqueado.
