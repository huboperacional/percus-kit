## Teste que reimplementa a expressão não prova nada {#teste-que-reimplementa-a-expressao-nao-prova-nada}

tags: teste, mock, vitest, plantio-negativo, esm

**Sintoma.** O teste está verde, o código está quebrado, e ninguém percebe.

**As três formas de escrever o teste errado**, todas encontradas na mesma tarde (Micro Investors,
2026-08-19), enquanto se tentava cobrir um fallback de string vazia:

**1. Reimplementar a expressão no teste.**

```js
// ERRADO: isto testa a própria linha do teste, não o componente.
const nome = (valor?.trim() || 'Fallback')
expect(nome).toBe('Fallback')
```

Se alguém trocar `||` por `??` no componente, o teste continua verde. É a mesma família do teste que
"passava com o código quebrado" no `sqlstate` de `deletion_requests`.

**2. Mockar o hook inteiro.** Aí o teste valida o mock, não a lógica.

**3. Mock parcial em ESM que não intercepta.** `vi.mock('@/hooks/x', importActual)` substituindo só
`useBranding` **não** afeta `useFundName`, porque dentro do mesmo módulo a chamada é por
**referência interna**, não pelo objeto do módulo. O teste passa a exercitar o hook real com dado
vazio — verde por acidente.

**O que funciona: falsear apenas a camada de rede**, chaveando pela query key, e deixar a cadeia de
hooks rodar real.

```js
vi.mock('@tanstack/react-query', () => ({
  useQuery: (opts) =>
    opts?.queryKey?.[0] === 'public-branding' ? mockBranding() : { data: [], isLoading: false },
  useQueryClient: () => ({ invalidateQueries: vi.fn() }),
}))
```

**Gate obrigatório: plantio negativo.** Nenhuma dessas três versões erradas seria descoberta sem
reverter o conserto e ver o teste reprovar. Teste que nunca foi visto vermelho não é prova, é
decoração. Ao restaurar `??` no lugar de `||`, 4 dos 12 casos reprovaram — só então o teste valia.

**Variante do mesmo vício, em teste de UI: assertar só o estado FINAL.**

```js
// ERRADO: um botão sempre habilitado passa igual, e o gate parece provado.
await razao.fill('motivo')
expect(await confirma.isEnabled()).toBe(true)

// CERTO: o PAR (bloqueado -> liberado) é que prova o gate.
const antes = await confirma.isEnabled()
await razao.fill('motivo')
const depois = await confirma.isEnabled()
expect(!antes && depois).toBe(true)
```

**Regra.** Se o teste não renderiza/executa o alvo, ou se ele passaria com o alvo revertido, ele não
existe. Prove os dois: verde com o conserto, vermelho sem.
