## `sharp` ausente: o log grita, a resposta é 200 e a imagem vai ao ar sem otimizar {#sharp-ausente-serve-imagem-sem-otimizar}

`tags: next, sharp, next/image, standalone, docker, otimizacao de imagem, degradacao silenciosa, erro no log sem falha na resposta, lighthouse, peso de pagina, evidencia medida`

**Sintoma:** o servidor de produção repete no log
*"'sharp' is required to be installed in standalone mode for the image optimization to function
correctly"*, e **nada aparece quebrado na tela**. As imagens carregam normalmente.

**O que está acontecendo:** com `output: 'standalone'` e sem `sharp` instalado, o Next **não
falha** — ele cai para servir o **arquivo original**, ignorando `w` e `q` da URL. Sem
redimensionar, sem WebP. É degradação, não erro.

**Como medir em 30 segundos** (e por que medir, não deduzir):

```sh
# pegue a URL que a página REALMENTE pede, não uma que você inventou
URL=$(curl -s http://localhost:PORTA/ | grep -o '/_next/image?url=[^"]*' | head -1)
curl -s -o /dev/null -w "otimizada: %{http_code} %{size_download}\n" "http://localhost:PORTA$URL"
curl -s -o /dev/null -w "crua:      %{http_code} %{size_download}\n" "http://localhost:PORTA/caminho/do/arquivo"
```

**Os dois números iguais são o diagnóstico.** No caso real: `w=384&q=75` devolveu **200** com
**30.435 bytes** — exatamente o tamanho do PNG cru. Se o `sharp` estivesse lá, o otimizado seria
menor.

⚠️ **URL de sonda não é evidência de defeito.** A primeira medição deste caso usou
`/_next/image?url=%2Flogo.png`, um caminho **inventado na hora**, e devolveu **400** — o que quase
virou "imagens quebradas em produção" num relatório. O 400 dizia apenas que `/logo.png` não existe
no `public/`. Sempre extraia a URL do HTML servido.

**Por que importa mesmo sem quebrar:** toda página que usa `next/image` sem `unoptimized` passa a
trafegar o original. Num produto com orçamento de performance declarado (`lighthouserc.js`, Core
Web Vitals, LCP de landing), isso consome o orçamento inteiro sem nenhum alarme — o tipo de
regressão que só aparece na fatura de banda ou no relatório mensal.

**Como resolver:**
1. `npm i sharp`.
2. **Confira que ele sobrevive ao Dockerfile.** No padrão standalone, o runner copia
   `/app/.next/standalone` (que embute `node_modules`) — verifique que `sharp` entra ali **com o
   binário da plataforma do container**, não o da máquina que buildou. `sharp` tem binário
   nativo por plataforma, e é o modo clássico de "funciona local, degrada no cluster".
3. Rode o `curl` acima **contra o ambiente real** depois do deploy: o log some no meio de outros,
   mas os dois tamanhos não mentem.

**A regra que sobra:** *log de erro com resposta 200 é degradação, e degradação não dispara
incidente.* Quando um serviço anuncia que uma capacidade está faltando e mesmo assim responde
sucesso, ninguém investiga — procure o que ele deixou de fazer, não o que ele quebrou.

**Relacionado:** [O snapshot do erro mostra o elemento PRESENTE](snapshot-do-erro-mostra-o-elemento-presente.md)

**Ref:** Empresa Milionária, 2026-08-20 — apareceu ao migrar a suíte e2e de `next dev` para
`next build && next start` (P23). Contra o dev server o aviso nunca surgia, e o problema existia
em produção o tempo todo.
