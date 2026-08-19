## Tirar a referência não despublica o arquivo — `public/` é servido na raiz {#referencia-removida-nao-despublica-arquivo}

tags: PII em site publico, remover imagem, public servido na raiz, next public, arquivo estatico
continua 200, despublicar, borrao insuficiente, mosaico vaza, redacao de screenshot

**Sintoma:** pedem para tirar do ar uma imagem com PII. Você remove a referência do componente
(esvazia o array, apaga o `<Image>`), a página deixa de mostrar o card, o build passa — e **o arquivo
continua respondendo 200 por URL direta**. Em Next, `public/` é servido na **raiz**: apagar
`ScreenshotGallery` não impede `https://dominio/platform/contributions.png` de existir.

**Causa raiz:** referência e publicação são coisas diferentes. Remover a referência **esconde**;
apagar o arquivo **despublica**. Um gate que confira só "a página está 200 e não mostra mais a
imagem" aprova com a PII no ar.

**Solução:**
- `git rm` no arquivo, não só a edição do componente.
- **Baseline ANTES:** confirme que as URLs respondem 200 *hoje* (com tamanho em bytes). Sem baseline,
  um 404 depois do deploy não prova nada — elas podiam já estar 404.
- **Gate DEPOIS:** exija **404 na URL direta** de cada arquivo, mais o otimizador de imagem se
  houver (`/_next/image?url=...`), mais a ausência da seção no HTML servido. Página em 200 não é
  evidência.
- Se o site tiver CDN/cache na frente, invalide — o arquivo sai do container e ainda pode viver no
  cache de borda.
- O arquivo continua no **histórico do git**. Se o repo for compartilhado ou público, isso é decisão
  à parte (reescrita de histórico), não consequência automática.

**Armadilha maior, e a que de fato vazou (2026-08-19):** havia DOIS borrões de forças opostas na
mesma imagem. O forte (`GaussianBlur`) foi aplicado por nós e cobria **só valor financeiro**; a
identidade dependia de um mosaico **herdado** do screenshot original, assumido como suficiente e
nunca conferido ao pixel. As caixas de mosaico eram **mais estreitas que o texto**, deixando o fim
de cada linha nítido — sufixo de logradouro, final de CEP, últimas letras de razão social. Em uma
das telas, uma coluna inteira **nunca teve borrão nenhum**.

**Regra que sai disso:** redação de tela real é frágil por natureza. Use **retângulo sólido** com
folga além do texto, nunca mosaico ou gaussiano sobre texto pequeno — e prefira **regerar a tela com
dados fictícios**, que é mais barato e mais seguro que redigir. E confira **no pixel, ampliando**:
"cheque o pixel, não a intenção" só vale se a conferência olhar o **nome**, não só o número.

Ver também `#arquivo-em-public-sombreia-rota-do-next` (outro efeito de `public/` na raiz) e
`#verificar-runtime-nao-estrutura` (conferir o que é servido, não o que o código parece dizer).
