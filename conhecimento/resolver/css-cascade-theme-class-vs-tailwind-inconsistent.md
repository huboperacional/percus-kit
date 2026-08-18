## Classe CSS de tema novo perde (ou não) uma queda de especificidade contra Tailwind, dependendo se ela declara a propriedade {#css-cascade-theme-class-vs-tailwind-inconsistent}

`tags: CSS especificidade, Tailwind, cascata, cascade order, classe custom, padding, admin-theme, stylesheet load order, inline style, object-fit`

**Contexto:** um tema CSS novo, escopado (`.admin-theme .admin-btn`, `.admin-theme .admin-input`),
importado por um layout Next.js aninhado, coexistindo no mesmo elemento com classes utilitárias
Tailwind (`pl-[32px]`, `px-[20px]`) pro mesmo elemento — padrão comum quando um design system novo
usa classes próprias pra cor/sombra/borda mas ainda quer Tailwind pra spacing/layout pontual.

**Sintoma:** um input de busca com `pl-[32px]` (Tailwind) tinha o `padding-left` REAL computado em
`12px` — o texto nascia embaixo do ícone. Corrigido via inline style. Aplicando o MESMO raciocínio
("Tailwind perde pra classe do tema, sempre use inline style") em 3 botões diferentes que também
pareciam quebrados (um deles renderizando como círculo perfeito em vez de pill) — só que aí o
review cross-provider (DeepSeek) apontou que inline style ali violava a convenção do projeto
(preferir Tailwind), e um teste ao vivo (computed styles via Playwright, antes/depois) provou que
a classe Tailwind `px-[20px]` funcionava perfeitamente nos botões — sem conflito nenhum.

**Causa raiz:** as duas situações PARECEM iguais mas não são. `.admin-input` DECLARAVA sua própria
`padding: 0 12px` — havia uma guerra de especificidade de verdade (mesma especificidade, 0-1-0,
entre a classe do tema e a classe Tailwind; quem carrega por último no stylesheet vence, e nesse
setup era o tema). `.admin-btn` NÃO declarava `padding` nenhum — não havia guerra nenhuma pra
Tailwind perder, o padding zero vinha simplesmente de ninguém ter setado nada. O sintoma visual
(padding efetivo = 0/errado) era idêntico nos dois casos; a causa era oposta.

**Solução:** antes de aplicar "usa inline style pra vencer a cascata" como padrão geral a partir de
UM caso confirmado, checar se a classe do tema REALMENTE declara a mesma propriedade que a classe
Tailwind está tentando setar (`grep` a prop no arquivo CSS do tema). Se declara → conflito real,
inline style é o fix certo (ou renomear pra não colidir). Se não declara → não há conflito, o bug é
só "ninguém setou nada", e a classe Tailwind normal resolve sem abrir mão da convenção do projeto.
Generalizar de um caso pro outro sem checar gera diagnóstico certo pro sintoma errado.

**Ref:** ads4agencies-site, redesign do painel de admin AutoWorx, sessão 2026-08-06 — `app/admin/
admin-theme.css`, achado no feedback visual ao vivo do operador, commits que corrigem e depois
corrigem-a-correção quando o review apontou a generalização precipitada.
