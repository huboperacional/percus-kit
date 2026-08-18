## "Antes/depois" corrigido no olho fica MAIS exagerado que o original — meça o realce especular só no objeto {#antes-depois-sem-instrumento-de-brilho}

`tags: before after, drag to compare, slider, brilho, gloss, ceramic coating, imagem gerada, gpt-image-2, images/edits, exagerado, delta medio engana, realce especular, sharp, medir so o objeto, ads4agencies-site, escalade`

**Sintoma.** Operador olha um slider antes/depois no site publicado e diz "está muito forçado". Você
regenera a imagem, ela fica visivelmente melhor, e ele responde **"continua exagerada"**. Sem número,
a conversa vira pingue-pongue de opinião.

**Contexto (ads4agencies-site, Ceramic Coating, 2026-08-13).** O "antes" era um Escalade **cinza
fosco** — lia como outro carro, não como o mesmo carro sem coating. Regenerado via `images/edits`
sobre o próprio "depois" (mesmo ângulo por construção). A nova imagem era **preta**, parecia
claramente melhor, e mesmo assim continuava exagerada.

**Causa raiz.** Corrigir "cor errada" não é a mesma coisa que corrigir "brilho errado", e o olho
confunde as duas. Medido depois: a imagem nova tinha **0,37%** de realce especular na lataria contra
**0,78%** da imagem cinza que ela ia substituir — ou seja, o "conserto" ficou **mais opaco que o
defeito**. Ela só *parecia* melhor porque a cor voltou a ser preta.

**O instrumento errado.** A primeira medição foi delta médio de pixel da imagem inteira contra o
"depois": 9,31 (cinza) → 7,39 (nova). Diferença pequena, e **enganosa** — a média é dominada pelo
fundo e pelo ruído de regeneração, não pela pintura. Ela não mede brilho; mede "quão diferentes são
as duas imagens".

**Solução — meça o especular, e só no objeto:**
1. Recorte a região do objeto (lataria: capô/lateral/teto), **fora** do fundo, das rodas e dos vidros.
2. Em greyscale, conte a fração de pixels acima de um limiar alto (`>200`) — é o realce especular, o
   que "brilho" quer dizer visualmente. `p99`/`p99.9` de luminância servem de apoio.
3. Compare sempre **contra a imagem de referência** (o "depois"), como razão, não em absoluto.

Resultado que fechou o caso: `depois` 3,45% · cinza antigo 0,78% (23%) · 1ª tentativa 0,37% (11%) ·
**instalada 1,25% (36%)**. O coating passa a triplicar o realce — diferença visível sem virar mágica.

**Sobre o prompt, porque ele é metade do problema.** Pedir "pintura descuidada/oxidada/opaca" empurra
o modelo pro extremo. O que funcionou foi travar a qualidade e mover só uma variável, com o limite
explícito: *"reproduza a mesma fotografia nítida e profissional; a pintura é limpa e bem cuidada,
apenas não tem coating; suavize um pouco os realces; NÃO deixe opaca, fosca, oxidada, riscada ou
cinza; alguém comparando deve notar uma diferença leve de brilho, nada mais."*

**Detalhe de API:** `gpt-image-2` **rejeita** o parâmetro `input_fidelity` (400
`invalid_input_fidelity_model`). A fidelidade ao original vem do próprio `images/edits` + do prompt.

**Padrão pra generalizar.** Toda rampa visual — brilho de coating, escurecimento de VLT, antes/depois
de qualquer serviço — é julgada no olho até alguém medir, e o olho é ruim justamente onde o valor
comercial está. Quando o operador reprovar duas vezes a mesma imagem, pare de gerar e **construa o
número** antes da terceira: ele custa um script de 10 linhas e transforma "acho que está forçado" em
"está em 11% da referência, precisa ir pra ~35%".

**Relacionado:** [#smoke-certo-mas-caminho-nao-rodou] (a saída parecer certa não prova nada sobre o
mecanismo) · [#mutacao-sobrevive-por-guarda-redundante] (medir antes de fabricar o conserto).

**Ref:** ads4agencies-site, `public/window-tint/shared/vehicles/ceramic/escalade-black-before.webp`
(asset compartilhado por 382 sites), 2026-08-13. Medição com `sharp` (`extract` + `greyscale` +
`raw`). R23.
