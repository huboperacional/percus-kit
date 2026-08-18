## Elemento preso dentro de card `overflow-hidden`+`rounded-*` não escapa com margin negativo — usa `createPortal` {#portal-escape-overflow-hidden-card}

`tags: React, createPortal, overflow-hidden, rounded corners, negative margin, full-bleed, card layout, shell redesign, clip, z-index, Next.js`

**Contexto:** redesenho de shell/layout onde a página vira um "card" flutuante (borda + `border-radius`
+ `overflow-hidden`, comum em padrões tipo "bento box" ou "cards flutuando sobre canvas escuro") — e
UM elemento específico (um título/breadcrumb isolado, um FAB, um banner) precisa aparecer visualmente
FORA desse card, sobre o fundo, não dentro dele.

**Sintoma:** a tentativa óbvia — `margin` negativo no elemento (a mesma técnica que já funciona pra
sangria full-bleed contra o padding de um container SEM `overflow-hidden`) — não move o elemento pra
fora visualmente. Ou o elemento fica cortado na borda arredondada do card (a parte que "escaparia" some),
ou continua dentro do card com um respiro estranho, dependendo de quanto negative margin foi aplicado.

**Causa raiz:** `overflow: hidden` recorta qualquer conteúdo do FILHO que ultrapasse a caixa do PAI,
independente de margin. `border-radius` faz esse recorte seguir a curva do canto, não um retângulo —
então mesmo se `overflow` fosse `visible`, o conteúdo "vazando" ficaria com uma esquina cortada de
forma visualmente óbvia e feia. Margin negativo desloca a posição do elemento DENTRO do fluxo do pai;
não desanexa o elemento da árvore DOM do pai. Pra um elemento aparecer genuinamente FORA da caixa
visual do card, ele precisa deixar de ser descendente DOM daquele card — não é um problema de
posicionamento, é um problema de ONDE o nó vive na árvore.

**Solução:** `ReactDOM.createPortal`. Renderize um slot vazio (`<div id="slot-id" />`) como IRMÃO do
card (fora da árvore que tem `overflow-hidden`), na posição visual correta (ex.: antes do card, com
gap). O componente que precisa "escapar" passa a portar seu conteúdo pra esse slot:

```tsx
// No componente-pai (o shell/layout), FORA do card com overflow-hidden:
<div id="page-header-slot" className="shrink-0" />
<div className="rounded-2xl overflow-hidden border ...">
  {children}
</div>

// No componente que precisa escapar (já client component):
const [portalTarget, setPortalTarget] = useState<HTMLElement | null>(null);
useEffect(() => {
  setPortalTarget(document.getElementById("page-header-slot"));
}, []);

if (!portalTarget) return null; // SSR-safe: sem alvo, sem render (evita mismatch)
return createPortal(<div>...</div>, portalTarget);
```

Pontos que mordem se esquecidos:
- **SSR-safe:** `document` só existe no client. Sempre `useEffect` + `useState` pra achar o alvo — nunca
  chame `createPortal` direto no corpo do componente com `document.getElementById` (quebra SSR).
- **Ordem de render:** o alvo (slot no pai/ancestral) precisa existir no DOM ANTES do componente que
  porta rodar seu efeito. Como React commita pais antes dos efeitos dos filhos dispararem, isso é
  garantido automaticamente se o slot é renderizado por um ANCESTRAL — não funciona se dois componentes
  irmãos tentam coordenar a ordem sozinhos.
- **Teste que renderiza o componente ISOLADO** (fora da árvore real do app, comum em testes de unidade
  com Testing Library) precisa criar o elemento-alvo manualmente no DOM de teste (`document.body`)
  antes de renderizar — senão o componente não encontra o alvo e não renderiza nada, o que PARECE
  regressão mas é o contrato novo funcionando (retornando `null` por design).
- Sem alvo nenhum e sem tratar isso, o componente quebra tentando `createPortal(content, null)`
  (React lança erro) — sempre faça o `if (!portalTarget) return null` guard.

**Relacionado:** técnica gêmea — quando o problema é só "página precisa ocupar a largura toda ignorando
o padding do shell" (sem precisar sair da árvore DOM), a solução certa costuma ser margin negativo
mesmo, cancelando o padding do ancestral — MAS só funciona se esse ancestral não tem `overflow-hidden`.
Antes de escolher entre as duas técnicas, confira se o ancestral que você quer atravessar tem
`overflow-hidden`/`clip-path`: se tem, é portal; se não tem, margin negativo resolve mais simples.

**Ref:** Paid Media Automation, sessão 2026-08-06/07 (cont.156) — redesenho de shell (sidebar+`<main>`
viram cards flutuando sobre canvas escuro, pedido inspirado em outro produto). `ClientTabBar`
(`web/src/components/client-tab-bar.tsx`) precisava aparecer isolado, fora do card branco do
conteúdo — `web/src/app/dashboard/shell.tsx` ganhou o slot `#dashboard-page-header`.
