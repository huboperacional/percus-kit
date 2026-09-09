## `values.append` do Sheets não grava onde você manda — ele grava na primeira coluna da "tabela" que detectar {#values-append-grava-na-coluna-da-tabela-que-ele-detecta}

`tags: google sheets, values.append, INSERT_ROWS, planilha, coluna deslocada, range, tabela, integracao, R23`

**Sintoma:** a API responde `200`, o log da aplicação diz `sheet: { ok: true }`, e a linha **entra na
planilha** — só que deslocada horizontalmente. Numa planilha de 28 colunas (`A..AB`), a linha gravada
com range `A:AB` foi parar em `Z..AY`: a primeira coluna caiu na 26ª, e o resto transbordou para além
do cabeçalho. Nenhum erro em lugar nenhum. Quem só checa o status HTTP declara sucesso.

**Causa raiz:** `spreadsheets.values.append` **não** trata o range como destino. A documentação diz,
em uma linha fácil de ler rápido demais: *"the range is used to search for existing data and find a
'table' within that range. Values are appended to the next row of the table, starting with the first
column of the table."* O range é uma **dica de busca**, não um endereço. Se a detecção de tabela
ancorar numa coluna que não é a A, é dali que a escrita começa.

O que faz a detecção errar é **planilha legada com linhas esparsas**. Numa aba real, preenchida por
gente ao longo de meses, muitas linhas têm buracos: a última linha de dados tinha conteúdo só em
`A,B,C,F,H,J,Z`. Com o range largo `A:AB`, a detecção ancorou no bloco contíguo da direita (`Z`) em
vez do da esquerda. Numa aba limpa, com todas as células preenchidas, o mesmo código acerta — por
isso **isto não reproduz em planilha de teste**, e passa por toda validação que não seja na aba real.

**O teste que discrimina, e é barato:** grave uma sonda e leia o `updates.updatedRange` da própria
resposta do append. Ele diz exatamente onde a escrita caiu — não é preciso abrir a planilha nem
inspecionar célula a célula:

```
A:AB     -> 'Aba'!Z55:BA55   coluna errada
A1       -> 'Aba'!A45:AB45   coluna certa, LINHA errada
A1:AB1   -> 'Aba'!A45:AB45   idem
A:A      -> 'Aba'!A54:AB54   coluna e linha certas
```

**Cuidado com a correção óbvia.** Ancorar em `A1` ou `A1:AB1` conserta a coluna e **estraga a linha**:
a detecção para na primeira linha totalmente vazia do meio da planilha (linha 45 na medição acima, com
dados reais abaixo dela) e o append grava **por cima** de registro existente. Trocar deslocamento
horizontal por sobrescrita silenciosa é um downgrade.

**Correção:** range de **uma coluna só**, a coluna que toda linha real tem preenchida — tipicamente a
de data ou id:

```ts
const range = encodeURIComponent(`'${tab}'!A:A`);
```

Ancora em `A`, e a última linha da tabela passa a ser a última com aquela coluna preenchida. Os N
valores transbordam para `B..` sozinhos — não é preciso declarar a largura, e declarar a largura é
justamente o que causava o problema.

**Não faça:** confiar em `200` + `ok: true` como prova de que a linha entrou **certa**; validar a
integração só em aba nova (a aba limpa esconde o defeito); nem deixar o range como template string
solta no meio do `fetch` — extraída como função pura, ela vira testável, e o teste de regressão custa
duas linhas.

**Ref:** ADS4PROS `/new-partner` → planilha HOPE, 2026-09-05. Descoberto no primeiro cadastro de teste
em produção depois de a service account passar nas 5 primeiras camadas do verificador — ou seja,
**depois** de tudo o que checava credencial, permissão e cabeçalho dizer que estava tudo certo.
