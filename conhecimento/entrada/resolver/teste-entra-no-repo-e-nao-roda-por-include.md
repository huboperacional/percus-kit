## Arquivo de teste entra no repo e NÃO RODA — o `include` do runner não cobre a extensão {#teste-entra-no-repo-e-nao-roda-por-include}

`tags: vitest, jest, include, glob, .test.tsx, falso verde, cobertura fantasma, porte de componentes, esbuild jsx automatic, React is not defined`

**Sintoma:** você porta/copia um conjunto de componentes com os testes deles, roda a suíte, tudo verde — e os testes novos **nunca executaram**. Nada avisa: não há erro, não há aviso, e o relatório diz "passed".

**Causa raiz:** o `include` do runner enumera extensões, e a que chegou não está lá. Medido em 2026-08-18: `include: ['**/__tests__/**/*.test.ts', '**/*.test.ts']` — sete arquivos `.test.tsx` entraram no repo e ficaram fora da suíte, calados.

🔑 **O que denuncia é a CONTAGEM, não o status.** A suíte foi de 130 para 143 quando deveria subir muito mais; foi só por isso que dei por falta. Depois de importar testes de fora, compare o número de **arquivos** de teste que o runner reporta com o número de arquivos que existem no disco:

```
find . -name "*.test.*" -not -path "*/node_modules/*" | wc -l   # o que existe
# vs. "Test Files N passed" do runner
```

Divergência aí é teste que não roda. Confiar em "tudo verde" logo depois de trazer testes de outro repo é confiar num número que ainda não incluiu o que você acabou de trazer.

**Solução:** `include: ['**/__tests__/**/*.test.{ts,tsx}', '**/*.test.{ts,tsx}']`.

⚠️ **E vem um segundo tranco junto, no mesmo porte:** com os `.tsx` finalmente rodando, todos falham com **`ReferenceError: React is not defined`**. O `tsconfig.json` usa `"jsx": "preserve"` porque em produção quem transpila é o Next — mas o runner não passa pelo Next e cai no runtime clássico (`React.createElement`). Conserto: `esbuild: { jsx: 'automatic' }` na config do vitest. Os dois problemas são independentes e aparecem em sequência: consertar só o `include` troca "verde falso" por "vermelho total".

⚠️ **Cuidado ao adicionar `useRouter`/hooks de framework a componente testado com `renderToStaticMarkup`:** não há contexto de router e os testes quebram em bloco. Se o componente precisa navegar, receba **callback do pai** — o pai já tem o router, e a folha continua pura e testável.
