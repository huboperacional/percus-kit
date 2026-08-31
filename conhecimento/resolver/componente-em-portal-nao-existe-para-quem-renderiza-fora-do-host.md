## Componente que sai por PORTAL não existe para quem o renderiza fora do host — e o teste quebra em massa {#componente-em-portal-nao-existe-para-quem-renderiza-fora-do-host}

tags: React, createPortal, portal, getElementById, alvo do portal, shell, layout, teste RTL, Testing Library, render isolado, jsdom, ordem de montagem, useEffect, requestAnimationFrame, sumico silencioso, null

**Sintoma — duas caras, e a segunda é pior:**

1. **Barulhenta:** ao mover um bloco para um portal, **várias suítes quebram de uma vez** com
   "elemento não encontrado". Os testes renderizam o componente isolado, sem o host que provê o
   alvo; o portal devolve `null` e tudo que estava dentro dele some da árvore — inclusive
   botões que o teste clica.
2. **Silenciosa:** em produção, um portal cujo alvo **ainda não existe no momento do efeito**
   não renderiza nada. Sem erro, sem log, sem console. O controle simplesmente não aparece.

**Causa:** o padrão usual é

```tsx
useEffect(() => { setAlvo(document.getElementById("slot")); }, []);
if (!alvo) return null;
return createPortal(children, alvo);
```

`getElementById` roda **uma vez**, no efeito de montagem. Dois cenários o derrubam:

- **Fora do host** (teste, storybook, página que não usa o shell): o nó nunca existe.
- **Alvo criado por OUTRO portal**: se o slot nasce dentro do portal de um irmão (ex.: uma tab
  bar que portala o cabeçalho e, dentro dele, publica um slot de ações), no primeiro commit os
  dois efeitos rodam **juntos** e o slot só entra no DOM no re-render seguinte. A busca única
  pega `null` e desiste **para sempre**.

**Solução:**

- **Alvo em DOM ESTÁTICO** sempre que possível (renderizado pelo layout/shell, não por outro
  portal). Aí a busca única basta — é por isso que o portal "de primeira geração" funciona e o
  "de segunda geração" não.
- Quando o alvo depende de outro portal, **re-tente por alguns quadros** e desista em silêncio:

```tsx
useEffect(() => {
  let vivo = true, restantes = 12, frame = 0;
  const procurar = () => {
    if (!vivo) return;
    const achado = document.getElementById(ALVO);
    if (achado) return setAlvo(achado);
    if (--restantes > 0) frame = requestAnimationFrame(procurar);
  };
  procurar();
  return () => { vivo = false; if (frame) cancelAnimationFrame(frame); };
}, []);
```

- **No teste, proveja o alvo** — o mesmo nó que o host usa:

```ts
beforeEach(() => {
  const alvo = document.createElement("div");
  alvo.id = "slot";
  document.body.appendChild(alvo);
});
afterEach(() => document.getElementById("slot")?.remove());
```

`screen` da Testing Library varre `document.body` inteiro, então as asserções continuam achando
o conteúdo depois do portal.

⚠️ **Leve o ESCOPO DE CSS junto.** Se o estilo do bloco é escopado por um ancestral
(`.raiz .bloco { … }`, CSS Modules, `[data-tema]`), o portal joga o markup para fora desse
ancestral e **o estilo deixa de aplicar** — mesmo com as classes intactas. Reembrulhe o conteúdo
portado no wrapper de escopo. Mesma família de
[[portal-radix-sai-do-escopo-dos-tokens]].

**Why:** portal troca *posição no DOM* por *posição na árvore React*. Quem consumia o componente
assumindo que ele renderiza "onde está escrito" passa a ver nada — e o modo de falha é
**ausência**, não erro. A suíte quebrando em massa é a versão barata do aviso; a versão cara é o
controle sumir em produção sem ninguém notar.

**How to apply:** ao portar um bloco existente, procure ANTES quem o renderiza fora do host
(`grep` pelos testes que montam o componente) e decida: prover o alvo no setup, ou não portar.
E se o alvo for criado por outro portal, escreva o caso *"alvo que só aparece depois do mount"*
e **veja-o reprovando** com a re-tentativa removida.

Relacionado: [[gate-que-nunca-foi-visto-reprovando-aprova-tudo]].
