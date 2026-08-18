## Ausência por design não é falha — e o teste sintético não distingue as duas {#ausencia-por-design-vs-falha}

`tags: teste sintetico, crawler, varredura automatizada, evento nao disparou, dedupe por sessao, sessionStorage, exclusao deliberada, validacao HTML5, GA4, conversao, dado real, falso negativo, silencio`

**Sintoma:** uma varredura automatizada clica CTAs e submete formulários de um site, e o relatório
volta dizendo que N deles "não dispararam evento". Conclusão natural, e errada: a instrumentação
está quebrada.

**O que estava acontecendo:** três comportamentos **projetados** produziam o mesmo silêncio que uma
falha produziria.
1. **Deduplicação por sessão** — `leadOnce(metodo)` grava em `sessionStorage` e o segundo disparo do
   mesmo método é pulado. Quem clica em 3 botões de WhatsApp gera **1** lead, que é o correto.
2. **Exclusão deliberada** — CTAs de captação de estoque ("anunciar/avaliar meu imóvel") são
   excluídos de propósito para não inflar o otimizador de mídia.
3. **Recusa de formulário inválido** — o código não dispara conversão em form que não passa na
   validação HTML5. E o preenchimento sintético do crawler ("PMA DIAGNOSTICO" num `<select>`
   obrigatório) produz exatamente um form inválido.

**Como resolver:** antes de declarar falha a partir de teste sintético, **procure o mesmo evento no
tráfego real**. Uma query no log de eventos com o campo `method` resolveu em 30 segundos o que a
varredura tinha deixado ambíguo: os leads reais chegavam por `form` **e** por `whatsapp`.

🔑 **A regra:** teste sintético prova que algo **funciona** (disparou = funciona). Ele **não** prova
que algo está quebrado — silêncio pode ser dedupe, exclusão de negócio ou validação. Para provar
quebra, use dado real. E se o próprio relatório traz um veredito tipo `cruzamento_nao_aplicavel`,
ele já está avisando que não dá pra concluir dali.

Visto em: Paid Media Automation, diagnóstico do funil da Imobiliária Uni (2026-07-27).
