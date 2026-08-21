## Fallback de env não dispara com string vazia — `??` some com o default, e o erro é silencioso {#fallback-de-env-nao-dispara-com-string-vazia}

`tags: env, NEXT_PUBLIC, build-arg, docker, vite, next, nullish coalescing, string vazia, fallback, 404 silencioso, inline, bundle`

**Sintoma:** o código tem `process.env.X ?? 'default-de-producao'` e um comentário
afirmando que esquecer o build-arg é seguro. Não é. Se o `ARG X=` do Dockerfile tem
**default vazio**, o bundler inlina a variável como `""` — **string vazia, não
`undefined`** — e `??` só dispara em `null`/`undefined`.

**O que acontece na prática** (caso real, formulário de captação de lead):

```js
const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "https://api.exemplo.com"
// build sem o arg  ->  API_BASE === ""
fetch(`${API_BASE}/api/v1/public/leads`, …)   // vira caminho RELATIVO ao host do site
```

O POST vai para `/api/v1/public/leads` **no host do próprio site**, recebe 404, e o
`catch` do formulário engole como "erro genérico". Nem o visitante nem o operador veem
nada. Todo lead some.

### Conserto — as duas defesas, porque o custo é zero

1. **`||` em vez de `??`.** Aqui a distinção que o `??` protege (preservar `""` como valor
   legítimo) não existe: string vazia nunca é uma base de URL válida.
2. **Default REAL no `ARG`**, não vazio:
   ```dockerfile
   ARG NEXT_PUBLIC_API_URL=https://api.exemplo.com
   ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
   ```

### O portão tem que olhar o BUNDLE, não o fonte

`NEXT_PUBLIC_*`/`VITE_*` são **inlinadas no build**. O fonte estar certo não prova que a
var foi inlinada certo — só o artefato servido responde isso:

```bash
curl -s https://site/rota | grep -oE '/_next/static/chunks/[A-Za-z0-9_.-]+[.]js' | sort -u \
  | while read c; do curl -s "https://site$c" | grep -oF 'https://api.exemplo.com'; done | wc -l
```

⚠️ **Não conte nome de função nesse portão.** O bundler renomeia: calibrar contra
`legendaTexto`/`useMinhaCoisa` devolve **zero** com o código certo. Use string literal que
sobrevive à minificação — URL, texto de `aria-label`, rótulo de UI.

### A raiz é a mesma de outra classe conhecida

O comentário que eu tinha escrito **afirmava a segurança sem ter testado**. Um comentário
que garante uma propriedade (`"esquecer isto não degrada em silêncio"`) é uma afirmação
testável, e enquanto não houver o teste ela é só uma intenção. Ver
[[comentario-afirma-garantia-que-o-codigo-nao-entrega]].

Ver também: [[env-var-vence-dotenv]].
