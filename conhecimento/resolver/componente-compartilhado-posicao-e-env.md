## Padronizar componente compartilhado: regra por POSIÇÃO vaza + env Jinja é por-rota (tiatendo I6) {#componente-compartilhado-posicao-e-env}

`tags: design system, componente compartilhado, css nth-child, regra por posicao, blast radius, Jinja2Templates, env globals, por-rota, macro, mock, widget de estoque`

Ao padronizar `.ti-table` (design system, 27 usos) e migrar o Caixa pro componente, dois vazamentos silenciosos:

- **Regra CSS keyed por posição vaza pra todos os usos do componente.** Uma regra `.ti-table td:nth-child(7){display:none}` escrita pro 7º col "No status" do **Orders** (≤1024px) aplicava a TODA `.ti-table`. No Caixa a 7ª `<td>` é o botão de AÇÃO → sumia no tablet/mobile. **Lição:** regra de componente ancorada em `nth-child(N)`/posição assume que toda instância tem o mesmo significado de coluna — quase nunca verdade. Escopar por classe do CONTEXTO (`#pagina .ti-table ...`) ou por classe semântica da célula, nunca por índice global. Fix seguro = override no escopo da página afetada, sem tocar a regra do outro consumidor (blast radius).

- **Cada módulo de rota do dashboard tem seu PRÓPRIO `Jinja2Templates`.** Um global registrado num (`statusLabelPt` em `ordersRoutes.env.globals`) NÃO existe no env de outra rota (caixa) → `{{ statusLabelPt() }}` renderiza vazio em PROD, mesmo com o teste "verde" (o teste registra o global à mão num Environment bare). **Reusar macro/partial que depende de global Jinja → registrar o global no env da rota que renderiza.** Macros importadas via `{% from %}` não sofrem (loader, não env.globals). Memória `feedback-per-route-jinja-env-globals-dont-share`.

**Regra de mock em widget de estoque (I5):** só mostrar "N restantes" onde `stock_qty` é coluna REAL e controlada (NULL = ilimitado, não aparece). Não inventar contagem — mesma decisão do rating-fora do E6.

**Ref:** tiatendo I6/I5 (2026-07-18), PROD `0.224.0`/`0.225.0`. Memória `project-vitrine-e3-e6-loja-2026-07-17`.
