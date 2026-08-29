## Inventário de tela/feature envelhece em DIAS, não semanas, numa árvore com muitas sessões concorrentes {#inventario-de-tela-envelhece-em-dias-numa-arvore-concorrida}

`tags: inventario, stale, arvore concorrida, multiplas sessoes, medicao, brainstorm, R23`

**Sintoma:** um documento de mapeamento ("estas N telas/features não existem ainda") é tratado
como fato atual num brainstorm ou planejamento, e o plano resultante superestima o trabalho
pendente — ou pior, alguém constrói de novo algo que já foi construído por outra sessão depois
que o documento foi escrito.

**Causa raiz:** numa árvore de trabalho com muitas sessões simultâneas (`ListAgents` mostrando
15+ sessões ativas no mesmo repositório), o volume de commits por dia é alto o suficiente pra um
inventário datado de "há 10 dias" já estar sistematicamente errado, não só em detalhes pontuais.
Diferente de um repositório com um único desenvolvedor, onde "o inventário de duas semanas atrás
provavelmente ainda vale porque eu sei o que mudei", numa árvore concorrida NENHUMA sessão
individual tem visão completa do que as outras fizeram — cada uma só vê o que leu no HANDOFF/
PLANO no início do próprio turno, que por sua vez pode estar atrás do commit mais recente de
outra sessão.

**Medido no Empresa Milionária (2026-08-27, brainstorm da D11):** um inventário de telas datado
de 17/08 (`docs/2026-08-17-inventario-de-telas.md`) listava 13 telas do domínio PF sem
equivalente PJ. Uma medição direta contra `find src/app/(pj) -iname page.tsx`, feita antes de
começar a desenhar o mapa de tasks, achou que **5 das 13 já tinham sido construídas** desde
17/08 (um route group `(pj)/empresas/[empresaId]/...` inteiro, com componentes reais e status
`[5-T]`/`[4-C]` já rastreado em `PLANO.md` sob OUTROS nomes — M1-3, M1-4, M1-5). O inventário
tinha 10 dias. Continuar o brainstorm sem essa medição teria produzido um mapa de 13 tasks pra um
trabalho real de 7.

**Como generalizar:** antes de brainstormar ou planejar em cima de QUALQUER inventário/mapa mais
velho que poucos dias, numa árvore com múltiplas sessões ativas, rode a medição direta que o
documento original usou (grep, find, contagem de rota) de novo — não assuma que "ainda deve
valer" só porque parece recente. O custo da medição é minutos; o custo de planejar em cima do
inventário errado é rebuild ou um mapa de tasks que erra a forma do trabalho.
