## O ponteiro estava no PLANO e eu não o segui: improvisar spec sobre design já aprovado {#ponteiro-no-plano-nao-seguido}

`tags: plano, ponteiro nao seguido, spec duplicada, handoff de design, retrabalho, gitignore esconde artefato, ler o PLANO antes, conselho, artefato ja aprovado`

**Sintoma:** escrevi do zero uma spec de feature — com requisitos, riscos e critério de pronto — e
rodei conselho nela. Depois o operador apontou que já existia um **handoff de design em alta
fidelidade**, encomendado e aprovado por ele, cobrindo a mesma tela: README de ~200 linhas, 3
protótipos navegáveis e 6 screenshots. O estado vazio do design **era** o wizard que eu especifiquei.

**A parte incômoda:** o `PLANO.md` do projeto **já registrava** o handoff, com caminho, na linha
`[0] Plano da UI — depende do handoff do Claude Design (…já entregue e lido)`. Não foi conhecimento
perdido: foi ponteiro não seguido. A pasta estar no `.gitignore` explica por que ela não aparece em
busca de código, mas **não** explica ter ignorado a linha do plano.

**Como resolver:** antes de escrever spec de qualquer tela, **procure ativamente por artefato de
design anterior** — `grep -ri "handoff\|design" docs/PLANO.md` e um `ls` na raiz do projeto (pastas
gitignored não aparecem em busca de código nem em `git ls-files`). Se existir, a spec **implementa**
o handoff em vez de redesenhar; o papel dela vira dizer o que entra em cada fatia, o que o backend
precisa entregar e como se verifica.

⚠️ **Corolário sobre perguntar:** tendo achado o design, perguntei ao operador se ele queria o design
dele **ou** a minha improvisação. Não era decisão real, e ele reagiu a isso. Quando uma das opções é
obviamente superior por um critério que o operador já estabeleceu, escolher é seu trabalho.

Visto em: Paid Media Automation, funil da jornada (2026-07-27).
