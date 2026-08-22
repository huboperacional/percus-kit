## Gate que nunca foi visto REPROVANDO aprova tudo {#gate-que-nunca-foi-visto-reprovando-aprova-tudo}

tags: teste, gate, scanner, regressão, falso-negativo

Escrevi uma guarda de varredura de árvore em 2026-08-22 e ela teve **quatro buracos** antes de
valer alguma coisa. **Três das quatro versões passavam tanto no estado correto quanto no estado
quebrado** — ou seja, ficavam verdes provando nada. Nenhum dos quatro apareceu ao rodar o teste;
todos apareceram ao **reintroduzir o defeito de propósito**.

Os quatro, porque cada um é uma família:

1. **O escape morreu no caminho.** O `\b` do regex virou byte de *backspace* (`\x08`) ao passar
   pelo shell. A varredura parou de casar arquivo nenhum e o teste ficou verde **por não achar
   nada**. ⇒ Nunca escreva regex através de heredoc/`sed`; use a ferramenta de edição de arquivo.
   E `grep` não denuncia: `\x08` é invisível. `repr()` denuncia.

2. **A defesa casava a si mesma.** A guarda aceitava o arquivo que mencionasse `report_id`; só que
   a consulta insegura contém `ON ai.report_id = u.id` — o próprio JOIN. Passava com a correção
   REMOVIDA. ⇒ Defesa tem que casar a FORMA que só existe quando a proteção existe (aqui: o id
   ligado a um **parâmetro**, não a outra coluna).

3. **O comentário que descreve a defesa satisfazia a defesa.** Os arquivos já corrigidos explicavam
   o defeito em comentários de 20 linhas que citavam `DISTINCT ON (` por extenso. A varredura lia o
   arquivo inteiro. ⇒ Tire comentários antes de conferir — `#`, `//` e também `-- ...` até o fim da
   linha, que eu fechei pela metade na primeira vez.

4. **O escopo era o ARQUIVO, e a defesa era de outra consulta.** O arquivo tinha um segundo
   `DISTINCT ON` de uma query sem relação nenhuma, e ele protegia a query quebrada. ⇒ Escopo a
   consulta (fatie por delimitador de string), não o arquivo.

**O procedimento que teria pegado os quatro em minutos:** para cada consumidor que o gate protege,
**reintroduza o defeito naquele consumidor** e confirme que o gate o nomeia. Um por um — não todos
de uma vez, porque um só falhando esconde os outros passando (foi assim que o buraco 4 sobreviveu à
minha primeira verificação: `reporter.py` falhava e eu li aquilo como "o gate funciona").

⚠️ **E gate que não acha nada precisa gritar.** `assert conferidos` (a lista de arquivos APROVADOS
não pode estar vazia) foi o que pegou o buraco 1. Sem ele, "zero desprotegidos" e "zero
analisados" são indistinguíveis.

Ver também [[comentario-nao-e-gate]].
