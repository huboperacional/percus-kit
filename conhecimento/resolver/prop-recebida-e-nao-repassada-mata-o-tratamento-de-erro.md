## Prop recebida e não repassada mata o tratamento de erro — e nem o TypeScript nem o teste de render enxergam {#prop-recebida-e-nao-repassada-mata-o-tratamento-de-erro}

`tags: react, prop drilling, onUnauthorized, 401, sessao expirada, callback, renderToStaticMarkup, teste de render, noUnusedLocals, comentario que promete, painel de admin`

**Sintoma:** o usuário clica, o servidor responde erro (tipicamente **401** por sessão expirada), e a tela **não muda nada** — sem mensagem, sem redirect, sem spinner travado. A leitura natural de quem está do outro lado é "o sistema travou". O commit que entregou aquela tela afirma, em texto, que o erro é tratado.

**Causa raiz:** um componente intermediário **recebe** o callback e **não o repassa** aos filhos:

```tsx
export function FieldGroupPanel({ fields, onFieldSaved, onUnauthorized }) {   // <- recebe
  return fields.map((f) => <PhotoFieldCard field={f} onSaved={...} />);       // <- nao repassa
}
```

A página fornece (`onUnauthorized={() => router.replace('/login')}`), o filho chama (`onUnauthorized?.()`), e no meio a prop morre. Como o filho a declara **opcional**, o `?.()` vira no-op silencioso: o caminho de erro executa até o fim e não faz nada.

🔑 **Por que as três redes de proteção falham juntas:**
1. **TypeScript não pega.** Prop opcional não repassada é código válido. `noUnusedLocals` não cobre desestruturação de parâmetro — a variável "é usada" no sentido do compilador porque foi desestruturada.
2. **Teste de render não pega.** Suíte que usa `renderToStaticMarkup`/snapshot compara **HTML**, e callback não vira marcação. No caso medido, 4 testes do próprio componente passavam.
3. **Review e leitura do diff não pegam.** O trecho lido isoladamente parece completo: a prop está no tipo, está na desestruturação, e o filho sabe usá-la.

**Solução — o teste que pega inspeciona a ÁRVORE DE ELEMENTOS, não o HTML:**

```tsx
const arvore = FieldGroupPanel({ fields: [...], onFieldSaved: () => {}, onUnauthorized: aoDeslogar });
const cartoes = acharFilhos(arvore, [PhotoFieldCard, VideoFieldRow]);   // percorre props.children
for (const c of cartoes) expect(c.props.onUnauthorized).toBe(aoDeslogar);
```

Elemento React é objeto simples: dá para percorrer `props.children` e afirmar sobre props que nunca aparecem no DOM. **Prove vermelho antes de verde** — foi assim que se confirmou que ele discrimina (`expected undefined to be [Function]`).

⚠️ **Generalização:** vale para qualquer prop de comportamento que atravessa camadas — `onUnauthorized`, `onError`, `onRetry`, `disabled`, `analytics`. Regra prática: **se a prop não muda o HTML, nenhum teste de render vai defendê-la.** Ou ela é testada estruturalmente, ou é testada por E2E com o erro real acontecendo, ou não está testada — e "não está testada" foi o estado real por 4 dias num painel entregue a um cliente.

🔴 **E o pior detalhe:** a mensagem de commit afirmava a garantia ("o mesmo 401 nos dois pontos de escrita"), e ela era verdadeira **no componente que a implementa**. O elo que faltava estava um nível acima. Mesma família de [comentario-afirma-garantia-que-o-codigo-nao-entrega](comentario-afirma-garantia-que-o-codigo-nao-entrega.md), com um agravante: aqui não havia comentário errado nenhum para desconfiar — cada arquivo, lido sozinho, estava certo.

Relacionado: [guarda-morta-entrypoint](guarda-morta-entrypoint.md) · [funcao-global-guardada-como-propriedade-quebra-no-navegador](funcao-global-guardada-como-propriedade-quebra-no-navegador.md)
