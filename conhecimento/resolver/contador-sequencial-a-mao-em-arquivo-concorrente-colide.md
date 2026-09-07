## Contador sequencial atribuído à mão num arquivo que várias sessões editam COLIDE por construção — e o dano é a referência que deixa de resolver {#contador-sequencial-a-mao-em-arquivo-concorrente-colide}

`tags: numeracao, contador sequencial, sessoes concorrentes, colisao de id, ADENDO, referencia cruzada, gate, id sem trava, R23`

**Sintoma:** dois documentos com o mesmo número/ID dentro do mesmo arquivo. Parece descuido de
alguém, e a correção "óbvia" é pedir atenção.

**Não é descuido.** Se o ID é um contador sequencial que um humano (ou agente) escolhe lendo o
maior valor existente, e o arquivo é editado por N sessões em paralelo, a colisão é o resultado
**esperado**: duas sessões leem "o último é 213", as duas escrevem 214, e as duas estão corretas em
relação ao que leram. É um `read-modify-write` sem trava.

**Medido (Paid Media Automation, 07/09/2026):** o operador apontou uma colisão. Ao contar, havia
**quatro** (`92`, `118`, `188`, `210`) — três nunca tinham sido percebidas. Três sessões dividem o
repositório.

🔑 **O dano não é estético: é a referência que deixa de resolver.** Havia **6 referências cruzadas**
apontando para um número que designava dois documentos diferentes. "Ver ADENDO 210" virou uma
pergunta sem resposta — e quem lê não tem como saber que está diante de uma ambiguidade.

**A regra de desempate, quando já colidiu:**

> **Quem chegou DEPOIS cede o número**, porque toda referência escrita antes dele só podia
> significar o primeiro.

Como o segundo cede depende de quando ele é:

| caso | o que fazer | por quê |
|---|---|---|
| ID **recente** | recebe o próximo livre | é o mais novo mesmo; o número novo continua batendo com a posição |
| ID **histórico** | ganha sufixo (`-b`) | dar-lhe o próximo livre poria um documento de agosto com número de setembro, e a numeração perde o único sentido que tem, que é a ordem |

Depois de renumerar, **corrija as referências cruzadas** — é a metade do trabalho que costuma
faltar (`grep -n 'ADENDO <n>' docs/*.md | grep -v '<marcador de cabeçalho>'`).

**A correção estrutural.** Se pedir atenção resolvesse, as três colisões anteriores não existiriam.
Duas saídas reais:
1. **Tirar a escolha do humano** — ID derivado (data + sufixo curto, hash), que não precisa de leitura
   prévia e não colide por construção. Custa uma migração e quebra referências existentes.
2. **Gate no commit** — barra o commit quando há ID repetido e informa o próximo livre. Não impede
   duas sessões de escolherem o mesmo, mas impede que isso **aterrisse**, que é o que importa.

Com muitas referências já escritas (213 documentos, no caso), (2) é o custo-benefício. Duas
decisões de desenho que valem copiar:
- **o gate lê o ÍNDICE, não a árvore** — `git commit` publica o índice
  (ver [[indice-do-git-e-uma-terceira-fonte-da-verdade]]);
- **fail-OPEN e barulhento** quando não consegue parsear, ao contrário de um guard de produção que
  é fail-closed: aqui o que está em jogo é clareza de documento, e travar commit de código por causa
  de um `.md` seria desproporcional — mas fail-open silencioso seria guarda que não mede nada.

⚠️ **Prove o gate contra o dado REAL de antes da correção**, não só contra caso sintético. O
`STATUS.md` pré-fix foi passado pelo guard e ele acusou as 4 duplicatas e sugeriu o número certo —
é isso que prova que ele mede, e não que ele passa.

Relacionado: [[indice-do-git-e-uma-terceira-fonte-da-verdade]],
[[concurrent_sessions_share_one_worktree]], [[gate_must_seen_failing]].
