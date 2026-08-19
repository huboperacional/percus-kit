## Dois ícones idênticos na tela e opostos no arquivo: o alfa não se vê no visualizador {#alfa-invisivel-mesmo-icone-parece-igual}

`tags: brand kit, canal alfa, RGBA, favicon, apple-touch-icon, iOS, PWA, identidade visual, screenshot, contraste WCAG, tema escuro, PNG, silhueta, negativo`

**Contexto:** troca do kit de identidade de um produto. O operador entrega os arquivos novos e pede
"troca as antigas". Dois arquivos vêm na mesma pasta com nomes quase iguais — `Icone transp.png` e
`Icone transp wh.png` —, ambos 512×512 RGBA, e **indistinguíveis em qualquer visualizador de imagem,
no explorador de arquivos e no preview do editor**.

**Causa raiz:** num deles a marca é **pixel branco opaco**; no outro é um **furo transparente** no
fundo colorido. Sobre fundo claro — que é o de todo visualizador, todo explorador e toda página — o
furo mostra o branco da página e os dois parecem idênticos. A diferença só aparece onde há fundo
escuro atrás.

**Por que isso é grave e não cosmético:** o **iOS ignora canal alfa** em `apple-touch-icon` e compõe
sobre **preto**. A marca vazada vira uma marca **preta** na tela inicial do celular. O mesmo vale para
qualquer contexto de fundo escuro: tema escuro do navegador, papel de parede escuro, PWA splash.

**Diagnóstico (a ordem que funciona):**
1. **Amostre o alfa de um pixel dentro da marca**, não olhe a imagem:
   ```python
   from PIL import Image
   px = Image.open(caminho).convert('RGBA').load()
   w, h = Image.open(caminho).size
   print(px[int(w*0.28), int(h*0.36)])   # (255,255,255,255) = opaco · (0,0,0,0) = FURO
   ```
2. **Componha sobre branco E sobre preto, lado a lado.** É a única imagem que mostra o problema —
   e é o que convence o operador em dois segundos.
3. Para ícone de app, meça **quanto pixel não-opaco sobra dentro da máscara do iOS**
   (retângulo arredondado de 22,4%). Compare com o ícone que já está em produção: o número absoluto
   não diz nada, a **regressão** diz tudo.

**Fix:** o arquivo-fonte é reexportado com a marca em branco opaco — **não** se preenche o furo no
pipeline. Preencher é "alterar a arte", esconde o defeito na fonte e o próximo uso (papelaria, slide,
camiseta) volta a errar. Quem é dono da marca corrige a marca.

**Armadilha vizinha, mesma família:** ícone de interface com **gradiente escuro** some no tema escuro.
Meça em vez de olhar — contraste WCAG do pixel mais escuro contra o `--surface` do tema. Um gradiente
de azul a navy deu **1,16:1** contra um fundo `#1a2740`; o mínimo para elemento gráfico é **3:1**. A
correção é a **silhueta tirada do canal alfa**, nunca `filter: invert()` — inverter vira o azul da
marca em laranja e o dourado em azul.

**Sinal de alerta que vale automatizar:** um script gerador que **imprime a medição a cada rodada**
(raio do canto vs máscara do iOS, tamanho dos derivados) pega a próxima troca de arte sem depender
de alguém lembrar. E um **lock com sha256 das fontes e dos servidos**, cobrado por teste, é o que
impede a arte antiga de voltar por cópia manual — o filtro por **nome de arquivo** não basta: um
`simbolo.png` não casa com "logo|icon|favicon" e entra sem selo. Capture por **pasta**.

**Onde isto foi medido:** Empresa Milionária, 2026-08-19 —
`D:\Claud Automations\Empresa-Milionaria\images\README.md`,
`scripts/gerar-icones.py`, `scripts/gerar-icones-menu.py` e
`empresa-api/tests/test_identidade_binaria.py`.
