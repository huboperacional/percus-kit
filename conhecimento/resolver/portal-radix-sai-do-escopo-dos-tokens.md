## Popover/menu/diálogo saem TRANSPARENTES: o `Portal` do Radix monta no `<body>`, fora do escopo onde os tokens da paleta existem {#portal-radix-sai-do-escopo-dos-tokens}

tags: Radix, shadcn, Portal, Popover, DropdownMenu, Dialog, Tooltip, design system, tokens, CSS variables, custom properties, escopo, :root, bg-transparent, fundo transparente, conteudo aparece atras, borda preta, z-index nao resolve, Tailwind, var() indefinido

**Sintoma:** o popover/menu/diálogo abre e **o conteúdo da página aparece através dele**. A
borda, quando aparece, vem preta e dura em vez do cinza do design. Parece z-index ou
`overflow`, e mexer nos dois não resolve — porque o painel não está atrás de nada: ele está
**sem fundo**.

**Causa:** o Radix monta todo `Portal` no `document.body` por padrão. Se os tokens do design
system são declarados num **escopo** (`.app`, `.painel`, `[data-tema]`…) em vez de `:root`, o
nó portalado nasce **fora** desse escopo. Aí:

- `bg-surface` → `background-color: var(--surface)` → variável indefinida → **transparente**;
- `border-borderCard` → `border-color: var(--borderCard)` → indefinida → o CSS cai para o
  valor inicial, que é `currentColor` — daí a borda preta, que é o texto herdado.

O detalhe cruel é que **nada quebra visivelmente no build, no `tsc` ou no teste de DOM**: a
classe está aplicada, o elemento está no lugar, a árvore de acessibilidade está correta. Só a
cor some. E não aparece em `curl`/`grep`, porque a string do `class` está lá.

**Solução — monte o portal DENTRO do escopo**, e não copie os tokens para `:root`:

```tsx
function useRecipienteFlutuante(): HTMLElement | undefined {
  const [no, setNo] = React.useState<HTMLElement | null>(null)
  React.useEffect(() => { setNo(document.querySelector<HTMLElement>('.app')) }, [])
  return no ?? undefined      // `undefined` = "use o padrão", para o Radix
}

// e em CADA primitivo portalado:
<PopoverPrimitive.Portal container={useRecipienteFlutuante_hoistado}>
```

**Por que não copiar os tokens para `:root`:** (a) se o escopo existe, é porque outra parte do
produto (landing, blog, área pública) não deve receber aquelas cores — foi para isso que ele
foi criado; (b) uma cópia no `:root` congela **uma** paleta e **um** tema, então troca de tema
ou de paleta em runtime deixa de alcançar os painéis flutuantes, e o defeito volta na metade
dos casos, que é pior que voltar em todos.

⚠️ **Confira DUAS propriedades no elemento-recipiente antes de adotar isto**, porque elas
mudam o resultado em silêncio:

| Propriedade no recipiente | O que quebra |
|---|---|
| `transform`, `filter`, `perspective`, `contain`, `backdrop-filter`, `will-change` | vira **bloco de contenção**: o `position: fixed` do diálogo passa a se ancorar nele, não na viewport — modal sai do centro da tela |
| `overflow` diferente de `visible` | **corta** o popover no limite do recipiente |

Se o recipiente tiver qualquer uma, use um nó irmão dedicado (um `<div class="app-portais">`
vazio no mesmo escopo de tokens) em vez do próprio contêiner do app.

**Cubra os QUATRO, não só o que apareceu.** O sintoma normalmente é relatado num só (o filtro,
o combobox), mas todos os primitivos portalados do shadcn/Radix têm o mesmo defeito:
`Popover`, `DropdownMenu`, `Dialog` e `Tooltip`. Corrigir só o relatado deixa três esperando.

**Por que `querySelector` em `useEffect` e não contexto com `ref`:** em Next.js App Router o
layout que carrega a classe de escopo costuma ser **Server Component**, e Server Component não
segura `ref`. Transformá-lo em cliente só por causa do portal arrasta a árvore inteira para o
cliente. Há um recipiente por página, e o efeito roda antes de qualquer interação conseguir
abrir um painel.

**Ref:** Empresa Milionária, 2026-08-17 — achado pelo operador usando o produto em produção,
não por teste: o filtro "Situação" abria com os cartões de saldo aparecendo através dele. Os
tokens PJ vivem em `.pj-app[data-paleta]` de propósito, porque `:root` repintaria a landing.
`empresa-frontend/src/components/pj/primitivos.tsx`.
