## O heredoc citado do Bash come uma barra invertida, e o estrago sai na cara do cliente {#heredoc-citado-do-bash-come-barra-invertida}

`tags: bash, heredoc, barra invertida, escape, patch programatico, python, gerar codigo, SyntaxError, fala do bot, chr(92), ferramenta que corrompe`

**Sintoma:** três formas, todas na mesma sessão, e nenhuma parece ter a mesma causa:

1. um patch programático **não acha o alvo** (`0 ocorrências`) num arquivo onde o trecho está lá,
   visível, idêntico;
2. o arquivo gerado quebra com `SyntaxError: invalid character '—' (U+2014)` numa linha que você
   escreveu correta;
3. pior de todas — o código gerado **roda**, os testes passam, e o **cliente vê `\n` literal** no
   meio da mensagem.

**Causa raiz:** o heredoc *citado* (`<<'EOF'`) desta ferramenta de Bash **remove um nível de barra
invertida** do conteúdo. Você escreve `\\n` no heredoc esperando que o Python receba `\\n` (barra +
n) e ele recebe `\n` (quebra de linha real). O contrário também acontece: um `\n` que você queria
literal vira quebra de linha e parte a string ao meio — daí o `SyntaxError` numa linha que parecia
inocente, e daí o alvo que "não existe" (o padrão de busca tem uma quebra onde o arquivo tem duas
letras).

**Por que passa despercebido:** as três manifestações ocorrem em *momentos* diferentes. A (1) e a
(2) falham alto e você conserta na hora. A (3) **não falha**: o `+ chr(92) + "n"` que você escreveu
como contorno vai para o fonte **como texto**, e em runtime vira dois caracteres. O teste que
checava "a palavra *pagar* está na resposta" passa feliz. Só quem lê a mensagem no WhatsApp vê a
barra.

**O caso (tiatendo, 2026-08-19):** ao ligar um escape novo no passo de pagamento, a fala de
confirmação saiu como `Como você vai pagar?\n- Dinheiro?` — com a barra visível. O defeito
atravessou o meu teste, a suíte inteira (3.163 testes) e só morreu porque a **review cross-provider
leu o diff** e apontou o `chr(92)` no fonte.

**Como resolver:**

- **Patch de código com escape não vai por heredoc.** Escreva o script com a ferramenta de escrita
  de arquivo (Write/Edit) e execute-o depois. Foi o que fechou o caso.
- Se tiver de usar heredoc, **evite a barra**: monte o caractere por código (`chr(10)` para quebra
  de linha, `chr(92)` para a barra) **na expressão**, nunca dentro de um literal que será COPIADO
  para o fonte gerado — a diferença entre "avaliado aqui" e "copiado para lá" é exatamente o que
  produz o defeito 3.
- **Cheque o produto, não o script:** depois de gerar código, `grep` no arquivo alvo por `chr(92)`,
  `\\n` e por `chr(` — se algum apareceu no fonte, o escape vazou.
- **Prove a linha nova por assert**, não pela palavra: `assert chr(10) + "-" in txt` mata o defeito
  3; `assert "pagar" in txt` não mata nada.

**Ver também:** [[mutacao-sobrevive-por-guarda-redundante]] — a mesma família: o teste que observa
a coisa errada fica verde em cima do defeito.
