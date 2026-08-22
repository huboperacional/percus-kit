## Comentário não é gate — e o terceiro consumidor nasce sem ler nenhum dos dois {#comentario-nao-e-gate}

tags: gate, regressão, revisão, scanner, dívida

Um defeito de SQL foi corrigido em **dois** consumidores, e em cada um a proteção virou um
comentário de 20 linhas dizendo *"NÃO volte a juntar direto"*. Os comentários eram excelentes:
explicavam a causa, o modo de falha e as três decisões da correção.

Em 2026-08-22 troquei os dois avisos por uma varredura de árvore. **A primeira coisa que ela achou
foi um TERCEIRO consumidor** — noutro arquivo, noutra função, escrito por alguém que nunca abriu
os dois primeiros. Ele tinha o `JOIN` ingênuo intacto e estava em produção havia meses, inflando
um número que ia para o cliente (medido: **278 contra 241**, com **37 de 39** entidades afetadas).

**Por que o comentário falha exatamente onde importa:** ele só é lido por quem abre AQUELE arquivo.
O risco não é quem mexe no código corrigido — é quem escreve o próximo, do zero, sem saber que os
outros existem. O comentário protege o passado; o gate protege o futuro.

**Como converter um aviso em guarda, sem allowlist:**

- A regra é sobre a **FORMA** do código, não sobre uma lista de arquivos perdoados. Lista apodrece:
  o arquivo novo não está nela e ninguém percebe que deveria estar.
- Enuncie o gatilho pelo defeito real (*"juntar A a B recortando por data sem eleger"*), e as
  saídas seguras pelo que de fato torna seguro — não por marcadores que a prosa também tem.
- Varra a **árvore**, atravessando linguagem. O defeito estava em Python e em TypeScript; um teste
  preso a um dos dois nunca veria o outro.
- **Escreva no gate o que ele NÃO pega.** O meu não detecta alguém apagar cirurgicamente a defesa
  de dentro de um CTE que mantém o nome. Dizer isso evita que a próxima pessoa confie demais.

⚠️ Poda a varredura antes de rodar: `node_modules` e worktrees aninhadas fazem o gate levar 3
minutos em vez de meio segundo — e **gate lento é gate que alguém desliga**.

Ver também [[gate-que-nunca-foi-visto-reprovando-aprova-tudo]].
