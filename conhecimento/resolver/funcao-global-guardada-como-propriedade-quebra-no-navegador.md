## Função global guardada como propriedade quebra em navegador real — e o seam de teste é justamente o que esconde {#funcao-global-guardada-como-propriedade-quebra-no-navegador}

`tags: web idl, illegal invocation, this, createImageBitmap, OffscreenCanvas, injecao de dependencia, seam de teste, catch que engole, fallback silencioso, cobertura falsa, compressao no navegador, upload`

**Sintoma:** uma feature que depende de API do navegador **não faz nada em produção** — sem erro na tela, sem log, com a suíte 100% verde. O código tem um `try/catch` com fallback razoável, e o fallback roda **sempre**.

**Causa raiz:** para tornar a feature testável fora do navegador, as APIs foram injetadas por um objeto de capacidades:

```ts
const caps = { createImageBitmap: typeof globalThis.createImageBitmap === 'function' ? createImageBitmap : undefined };
...
bitmap = await caps.createImageBitmap(arquivo, { resizeQuality: 'high' });   // <- chamada como MÉTODO
```

Assim o `this` deixa de ser `Window` e passa a ser `caps`. A Web IDL exige o receptor certo e responde `TypeError: Failed to execute 'createImageBitmap' on 'Window': Illegal invocation`. O `catch` — escrito para "formato que o navegador não decodifica" — engole o TypeError e devolve o fallback.

🔑 **O seam que tornou o código testável foi o que escondeu o defeito.** O fake injetado nos testes é função JS comum, que não liga para `this`; os três degraus de fallback testavam verdes enquanto **nenhum** era o que rodava de verdade. Cobertura alta, comportamento zero.

**Medido em 2026-08-18, as três formas, mesmo navegador e mesmo arquivo:**

```
caps.createImageBitmap(file, {...})              -> TypeError: Illegal invocation
const f = caps.createImageBitmap; f(file, {...}) -> OK  3024x4032
createImageBitmap.bind(globalThis)               -> OK  3024x4032
```

**Solução:** `bind` no ponto de **detecção**, não no de chamada — sobrevive a qualquer estilo de invocação que venha depois:

```ts
createImageBitmap: typeof g.createImageBitmap === 'function'
  ? (createImageBitmap.bind(globalThis) as typeof createImageBitmap)
  : undefined,
```

**Teste que pega, e que nenhum outro do arquivo pegava** — exercita o caminho **sem injeção**, com stub que imita a exigência da Web IDL:

```ts
const estrito = function (this: unknown) {
  if (this !== undefined && this !== globalThis) throw new TypeError('Illegal invocation');
  return Promise.resolve(bitmapFalso);
};
vi.stubGlobal('createImageBitmap', estrito);   // + vi.unstubAllGlobals() no afterEach
const r = await comprimir(arquivo);            // SEM passar caps
expect(r.comprimido).toBe(true);
```

⚠️ **Generalização:** toda vez que uma função global de plataforma (`createImageBitmap`, `fetch`, `atob`, `postMessage`, `matchMedia`, `getComputedStyle`…) é guardada em propriedade de objeto para injeção, a chamada vira método e o `this` muda. Ou `bind` na captura, ou extraia para variável local antes de chamar. E **um `catch` que devolve fallback precisa distinguir a falha esperada da inesperada** — engolir `TypeError` no mesmo ramo de "formato não suportado" transforma bug em comportamento silencioso.

🔴 **Como isto foi achado:** não por teste nem por review — **subindo um arquivo de verdade pela interface, em produção, e conferindo os bytes que o site passou a servir**. JPEG de 3024x4032 e 1,00 MB entrou e saiu igual, `image/jpeg`, quando deveria sair com 183.908 B em WebP 1800x2400. Verificação que só pergunta "o upload respondeu 200?" aprova este defeito.

Relacionado: [sondagem-em-storage-compartilhado-vira-defeito-em-producao](sondagem-em-storage-compartilhado-vira-defeito-em-producao.md) · [teste-entra-no-repo-e-nao-roda-por-include](teste-entra-no-repo-e-nao-roda-por-include.md)
