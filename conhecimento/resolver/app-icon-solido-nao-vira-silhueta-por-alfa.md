## `brightness(0) invert(1)` num app icon devolve retângulo branco liso, não a silhueta da marca {#app-icon-solido-nao-vira-silhueta-por-alfa}

`tags: css filter, brightness invert, silhueta, canal alfa, app icon, favicon, logo branca, negativo, marca dagua, watermark, asset, png, transparencia, fundo solido, next image`

**Sintoma:** o truque padrão para obter a versão branca de uma logo sobre fundo escuro —
`filter: brightness(0) invert(1)` — funciona com um asset e devolve um **retângulo (ou quadrado
arredondado) branco chapado** com outro, sem nenhum traço da marca. O build passa, o console fica
limpo, e a medição de contraste não acusa nada: para todo instrumento automático, há uma imagem ali.

**Causa raiz:** o filtro não "pinta a logo de branco" — ele **achata tudo que é opaco** e preserva
o **canal alfa**. O resultado é a silhueta do que for opaco no arquivo. Num lockup com fundo
transparente, o opaco é a marca, e sai a silhueta certa. Num **app icon**, o opaco é o **quadrado
inteiro** (a marca é vazada em branco *por dentro* de um fundo colorido sólido) — então a silhueta
correta é literalmente o quadrado.

**Como reconhecer antes de tentar:** app icon / favicon / ícone de loja são desenhados para serem
**recortados por máscara do sistema operacional**, então quase sempre têm fundo sólido de borda a
borda. Se o arquivo fica bonito sobre qualquer cor sem parecer adesivo, ele tem fundo. Dois sinais
baratos: proporção ~1:1 e nome do tipo `icon`/`app-icon`/`favicon`.

**Solução:** use o asset com transparência real — o lockup horizontal, ou o símbolo solto exportado
com fundo transparente. Se não existir no repositório, **exportar um é mais barato que qualquer
tentativa de recuperar a marca por filtro CSS**: não há combinação de `invert`, `contrast`,
`mix-blend-mode` ou `mask` que reconstrua um vazado a partir de um fundo opaco, porque a informação
"isto aqui é buraco" não está no alfa — está na cor.

⚠️ **Este é um defeito que só o olho pega.** Build, teste de tipo, console do navegador, lint de
acessibilidade e medição de contraste passam todos: o elemento existe, tem dimensão, tem alfa e não
tem texto. A verificação que fecha é **screenshot renderizado**.

**Deixe a armadilha escrita no código**, ao lado do `src`. O próximo leitor vai olhar `icon.png` e
achar que é o arquivo certo pelo nome — foi exatamente o que aconteceu.

**Relacionado:** [Varredura de marca com `rg` não acha logo do produto de origem: texto não lê binário](varredura-de-texto-nao-le-binario.md)

**Ref:** Empresa Milionária, 2026-08-18 — marca d'água do CTA final; `icon.png` (3780×4100, quadrado
azul sólido com o `≡M` vazado) tentado, renderizado e descartado em favor do símbolo com fundo
transparente.
