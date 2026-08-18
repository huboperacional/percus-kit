## `preventDefault` no evento `submit` NÃO impede envio de form disparado por `form.submit()` — você cria um lead real em produção {#form-submit-programatico-ignora-listeners}

tags: playwright, form submit, preventDefault, addEventListener capture, auditoria de tracking, poluicao de producao, lead falso, teste em site de cliente

**Sintoma.** Você quer auditar se um formulário de site dispara conversão, então instala um
bloqueio antes de testar:

```js
document.addEventListener('submit', e => e.preventDefault(), true);  // captura
```

Dispara o submit, e o navegador **navega assim mesmo** para a página de obrigado. Resultado:
**lead falso criado no CRM e no e-mail do cliente.**

**Causa raiz.** O método `HTMLFormElement.prototype.submit()` — que a maioria dos temas de site
chama a partir do handler do botão — **não dispara o evento `submit`**. Ele vai direto pro
envio. Nenhum listener roda, em captura ou em bolha, e `preventDefault` não tem o que cancelar.
(É diferente de `form.requestSubmit()`, que dispara o evento normalmente.)

**Solução — bloqueie na camada de rede, não na de evento.** Antes de qualquer clique:

```js
// 1. neutralizar o submit programatico
HTMLFormElement.prototype.submit = function () {
  window.__submitsBloqueados.push(this.getAttribute('action'));
};
// 2. e ainda assim interceptar fetch / sendBeacon / XHR, que e por onde
//    o tracking sai (ver o mesmo padrao usado pra medir cobertura de CTA)
```

Com Playwright dá pra ser mais forte ainda: `page.route()` abortando o POST do endpoint do
formulário — isso pega qualquer caminho, inclusive navegação nativa.

**Duas regras que vêm junto:**
- **Prove o interceptador antes de confiar no silêncio dele.** Dispare um canário conhecido
  (`fetch` pro próprio endpoint de tracking) e confirme que foi capturado. Sem isso, você não
  distingue "nada disparou" de "meu instrumento está quebrado" — mesma família de
  `#gate-must-be-seen-failing`.
- **Em site de cliente, prefira inspecionar a submeter.** Ler `form.action`, os campos e os
  listeners já responde a maior parte das perguntas de cobertura sem tocar em produção.

**Ref:** Paid Media Automation, auditoria da Imobiliária UNI, 2026-08-10 — criei 1 ou 2 leads
falsos no imóvel 198 do cliente testando o formulário "Quero mais informações". O interceptador
de rede (fetch/beacon/XHR) funcionou e foi validado por canário; o que falhou foi só o bloqueio
do submit.
