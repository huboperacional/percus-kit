## Gate que varre o texto dos imports acaba casando a PRÓPRIA DEFINIÇÃO e se auto-satisfaz {#gate-que-segue-import-casa-a-propria-definicao}

tags: gate, teste de arquitetura, varredura estatica, import, resolucao de modulo, falso verde, self-satisfying, mutante, visto reprovando, convencao, lint caseiro, AST, regex sobre fonte

**Sintoma:** um gate que exige "toda página declara X" fica **verde com a chamada de X removida**.
Ele nunca reprova, então parece que a convenção está sendo seguida em todo lugar — quando na
verdade ele aprovaria qualquer coisa.

**Causa — dois erros que costumam vir juntos:**

**1. Casar o IMPORT em vez da CHAMADA.**

```ts
const declara = (txt: string) => txt.includes("usePageHeader");   // ❌
```

`import { usePageHeader } from "@/hooks/usePageHeader"` já satisfaz a busca. O arquivo que
importou e **parou de usar** — que é exatamente a regressão a vigiar — continua passando.

**2. Seguir os imports e engolir o SÍTIO DE DEFINIÇÃO.**

Gates de convenção quase sempre precisam seguir imports (a página delega o trabalho a um
componente). Só que, ao concatenar o texto dos módulos importados, entra também
`export function usePageHeader(...)` — a **definição** do próprio mecanismo. Aí:

```ts
const declara = (txt) => /\busePageHeader\s*\(/.test(txt);   // ❌ ainda falso-verde
```

casa a assinatura da função e o gate **se auto-satisfaz**: basta a página importar (direta ou
transitivamente) o módulo do mecanismo para ser aprovada. Quanto mais fundo o gate segue os
imports, mais fácil ele encostar na definição — a profundidade que o torna útil é a mesma que o
cega.

**Solução:**

```ts
const declara = (txt: string) => {
  const semDefinicoes = txt
    .replace(/export\s+function\s+usePageHeader\s*\(/g, "")
    .replace(/export\s+function\s+PageHeaderPortal\s*\(/g, "");
  return /<PageHeaderPortal[\s>]/.test(semDefinicoes)
      || /\busePageHeader\s*\(/.test(semDefinicoes);
};
```

Regras que evitam a família toda:

- Case o **uso**, não o identificador: `X(` para função, `<X` para componente.
- **Remova os sítios de declaração** antes de testar (`export function X(`, `export const X =`,
  `function X(`), ou não inclua no contexto os módulos que DEFINEM o mecanismo.
- Melhor ainda: percorra **AST** em vez de texto, quando o custo permitir.

**Why:** a única prova de que um gate de convenção funciona é **vê-lo reprovando com o defeito
reintroduzido** — e o defeito certo é *"a página parou de chamar"*, não *"a página não tem a
palavra"*. Nos dois erros acima o gate rodou, ficou verde e não vigiava nada; medido em duas
versões seguidas antes de a terceira finalmente acusar — e acusar **só** a página mutilada.

**How to apply:** ao escrever gate de convenção, faça o mutante ANTES de comemorar: apague a
chamada de UMA página e exija ver o nome dela na mensagem de falha. Se o gate seguir verde, ele
está casando import, definição, ou prosa de comentário.

Relacionado: [[gate-que-nunca-foi-visto-reprovando-aprova-tudo]],
[[gate-que-le-estado-pos-mudanca-e-cego]].
