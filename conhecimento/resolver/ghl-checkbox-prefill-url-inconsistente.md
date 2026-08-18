## Prefill de checkbox-group via URL param em form embutido de terceiro (GHL) marca a opção ERRADA, não "não funciona" {#ghl-checkbox-prefill-url-inconsistente}

`tags: GoHighLevel, GHL, iframe, form embutido, prefill, URL param, checkbox-group, terceiro`

**Contexto:** ads4agencies-site, sessão 2026-08-04, AutoWorx v2 — o CTA de fechamento de cada
subpágina de serviço deveria levar pro form de quote (`/quote`, iframe GHL
`link.ads4pros.com/widget/form/<id>`) já com o serviço marcado. GHL documenta prefill de campo
simples via URL param (`?first_name=John`) — a suposição natural foi que o mesmo mecanismo
funciona pra um campo checkbox-group (múltipla escolha), passando `?<field_key>=<valor>`.

**Causa raiz:** testado ao vivo (`browser_navigate` direto na URL do widget + `browser_evaluate`
lendo `checked`/`value` de cada `input[type="checkbox"]` real do DOM), o prefill por URL num
checkbox-group do GHL é **inconsistente**: um valor marcou a PRIMEIRA opção da lista (não a
pedida), outro valor não marcou nenhuma. Sem param, nada vem marcado (comportamento base correto).
Não é "não funciona" nem "funciona certo" — é **funciona errado às vezes**, o pior dos três, porque
empurra o lead pro serviço errado em silêncio.

**Sinal de alerta pra generalizar:** qualquer prefill de campo MÚLTIPLA-ESCOLHA (checkbox-group,
multi-select) via URL param em form embutido de terceiro é candidato — a documentação genérica do
provider costuma cobrir só campo de texto/single-value; nunca assumir que o mesmo mecanismo
generaliza pra múltipla escolha sem testar.

**Solução:** não tente pré-marcar campo múltiplo-escolha dentro do iframe de terceiro. Controle o
que dá pra controlar de verdade — a página que hospeda o iframe: mostrar aviso em texto claro
("Interessado em: **X** — selecione abaixo pra confirmar") acima do form, deixar o visitante marcar
manualmente. Pra testar antes de prometer qualquer prefill de form de terceiro: `browser_navigate`
direto na URL do widget/iframe (fora do site) com e sem o param candidato, `browser_evaluate`
lendo `checked`/`value` de cada input real — nunca confiar na documentação genérica do provider.

**Ref:** ads4agencies-site, `WTV2ServiceDetailPage.tsx` + `/quote`, sessão 2026-08-04, form GHL
`gNR1no6QKMlI369FN80d`.
