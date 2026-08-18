## Grade com contagem de colunas fixa promete "sem fileira órfã" e só cumpre para um total {#colunas-fixas-prometem-fileira-inteira-para-um-total-so}

tags: grid colunas fixas, fileira orfa, layout quebra com total diferente, grade responsiva, ultima linha incompleta

**Sintoma.** Uma grade some com um tile, ou termina numa fileira incompleta, depois de alguém
adicionar itens — apesar de um comentário no CSS afirmando que fileiras órfãs não acontecem.

**Causa.** `grid-template-columns: repeat(5,1fr)` com um comentário do tipo "5 colunas fixas (não
`auto-fill`) para que os 10 tiles caiam em 2 fileiras inteiras". A promessa depende do **total nunca
mudar**. Ao virar 12, renderiza 5+5+2. O comentário continua lá, agora mentindo.

**Correção.** Derivar a contagem do total e testar a PROPRIEDADE, não os casos:
```ts
export function columnCount(n: number): number {
  for (const c of [5, 4, 3]) if (n > 0 && n % c === 0) return c;
  return 5; // sem divisor no conjunto: fileira curta, declarada
}
```
Teste a invariante (`n % columnCount(n) === 0` para todo n que fatora), não só 10/12/15.

**Duas armadilhas na hora de documentar a limitação:**
- Dizer "só falha em total primo" é **errado**: 14 = 2×7 fatora e também não tem divisor em {5,4,3}.
  A condição real é "sem divisor no conjunto de candidatos".
- Incluir `2` no conjunto para "cobrir 14" troca uma fileira curta por 7 fileiras de dois — pior
  página. A limitação certa é **assumida e escrita**, e o conserto pertence à decisão de curadoria
  (escolher um total que fatore), não à função.
