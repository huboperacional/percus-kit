## Instrumento que erra a superfície mente nas duas direções {#instrumento-que-erra-a-superficie-mente-nas-duas-direcoes}

tags: [inspecao, browser, css, tema, falso-positivo, ferramenta]

**Sintoma.** O operador reporta um defeito visual que o código não tem — ou não reporta um que o
código tem. Nos dois casos a suíte está verde e a leitura do código não explica.

**Causa.** A ferramenta de inspeção (harness de captura, storybook, página de demonstração) não
reproduz a **superfície real** onde o componente vive: pinta outro token de fundo, omite a moldura
do shell, ou monta o componente sem o ancestral que fornece as variáveis CSS.

**Caso medido (Plexco Tasks, 2026-09-07).** O harness pintava o painel com `var(--canvas)`
(`#FBFBF8`, o fundo *atrás* da página) quando no app o conteúdo mora num cartão `bg-block`
(`#FFFFFF`). Como a zebra das linhas usa `--row-alt` `#FAF9F5`, a alternância virava bege-contra-bege
na captura e **parecia quebrada**. Estava certa: com a superfície corrigida, medido `par` =
`rgb(255,255,255)` e `impar` = `rgb(250,249,245)` em todas as seções.

**As duas direções do mesmo erro:**

| Direção | Exemplo medido | Custo |
|---|---|---|
| **Esconde** defeito que existe | classe utilitária com `color-mix` que o Tailwind v4 não gera; `bg-border-strong` ausente do `@theme` | o defeito vai pra produção |
| **Inventa** defeito que não existe | painel pintando `--canvas` onde o app usa `--block` | trabalho consertando o que está certo, e o "conserto" vira **regressão** |

🔑 **Inventar é pior.** Esconder custa o defeito, que continua lá esperando. Inventar consome
trabalho e introduz um bug num código que estava correto — e ninguém desconfia, porque havia um
relato de usuário.

**Como não cair:**
1. A ferramenta espelha a superfície real — mesmo token de fundo, mesma moldura do shell. Se o app
   usa `bg-block` dentro de `bg-canvas`, a captura faz os dois.
2. A prova é a propriedade **computada** no browser, nunca o nome da classe nem `grep` na regra:
   `grep` diz que a regra existe, `getComputedStyle` diz que ela **aplica**.
3. Prova forte para valor que varia por tema: **o mesmo elemento, nos dois temas, com valores
   diferentes**. Se os dois derem igual, a regra de tema não está pegando.
4. Ao compor contraste, componha **alpha**: fundo `rgba(255,255,255,0.045)` sobre um bloco escuro
   não é branco. Ler o `backgroundColor` do primeiro ancestral sem compor produziu 11 falhas
   fantasma numa varredura.

Relacionado: [zero so vale como prova com controle positivo](zero-so-vale-como-prova-com-controle-positivo.md)
