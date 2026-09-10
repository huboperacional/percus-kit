## `TableCell` do shadcn tem `whitespace-nowrap` por padrão — texto livre vaza por cima da coluna vizinha {#shadcn-table-cell-whitespace-nowrap-vaza-texto-livre}

tags: shadcn, tailwind, css, tabela, overflow, ui

**Sintoma.** Uma coluna de tabela com frase longa (não um número/status curto)
aparece visualmente **sobreposta** às colunas seguintes — texto de uma célula
"vazando" por cima do conteúdo da próxima, como duas camadas de texto
empilhadas. Print de operador real: coluna "O que é" (frase de plano de ação)
sobrepondo os badges de status da coluna ao lado.

**Por que morde.** O componente `TableCell` do shadcn (`components/ui/table.tsx`)
vem com `"p-2 align-middle whitespace-nowrap ..."` por padrão — pensado pra
dado tabular curto (número, data, status). Um `className` extra tipo
`max-w-md` na célula **não basta**: `max-width` limita o box de LAYOUT, mas com
`white-space: nowrap` e overflow padrão (`visible`), o TEXTO ignora esse limite
e continua numa linha só, desenhando por cima do que vem depois na mesma linha
da tabela — não é erro de z-index, é o comportamento correto de
`overflow: visible` com conteúdo que se recusa a quebrar.

**O fix:** adicionar `whitespace-normal` (ou `break-words`) explicitamente na
`className` de toda `TableCell` que carrega frase livre. Com `cn()` usando
`tailwind-merge`, a classe depois na string vence a do componente — não precisa
tocar no `table.tsx` compartilhado, só declarar a exceção onde o conteúdo é
diferente do padrão tabular.

```tsx
<TableCell className="max-w-md whitespace-normal break-words text-xs">
  {textoLivreLongo}
</TableCell>
```

**Caso real** (Paid Media Automation, D4U, 2026-09-10). Tabela "o que foi
solicitado" com coluna de descrição de frente (frase de ~150 caracteres) e
coluna de status (badge + frase de ~70 caracteres) — as duas herdavam
`whitespace-nowrap` do componente, vazando uma sobre a outra. Achado só depois
do deploy, por print do operador — nenhum teste de unit/snapshot pegaria isso
porque o DOM está "correto", é só o CSS computado que produz a sobreposição
visual.
