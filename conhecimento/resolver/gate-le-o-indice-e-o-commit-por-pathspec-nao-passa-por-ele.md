## Gate que lê o índice não vê nada quando o commit usa pathspec {#gate-le-o-indice-e-o-commit-por-pathspec-nao-passa-por-ele}

`tags: pre-commit, git hook, PreToolUse, git diff --cached, pathspec, staged, gate furado, skip silencioso, mypy, types-check, arvore compartilhada, bypass`

**Sintoma:** o gate de qualidade passa e o commit entra — mas o código que ele deveria checar
**nunca foi analisado**. A saída não distingue *"checado e limpo"* de *"não checado"*, então o
verde parece cobertura.

**Causa raiz:** o hook coleta os arquivos por `git diff --cached --name-only` (só o **ÍNDICE**),
mas `git commit -m "..." -- <caminhos>` grava **direto da árvore de trabalho, sem estagiar**. No
instante do `PreToolUse` o índice está vazio para aqueles arquivos; o helper devolve lista vazia;
a análise nem roda. É o **complemento exato** de
[[gate-le-working-tree-nao-o-indice]] — lá o gate lê o disco e aprova o que não vai ser gravado;
aqui ele lê o índice e não vê o que **vai**.

🔴 **O agravante, e é o que torna isto perigoso:** em árvore compartilhada a boa prática **manda**
usar pathspec no `commit`, para não levar arquivo de outra sessão. Ou seja, **seguir a convenção
correta desliga o gate**, em silêncio. As duas práticas estão certas isoladamente e se anulam
juntas.

**Como se descobre (e como quase não se descobre):** o sinal não é o silêncio — silêncio é o que
o defeito produz. O que denuncia são **duas medições incompatíveis**: uma sessão reportou o gate
fechando em `0` sobre um arquivo que, medido isoladamente, tinha **274** erros. Um conjunto que
contém esse arquivo não pode chegar a zero; logo ele não estava no índice.

**Como resolver:**

- **Antes de confiar que o gate te checou:** `git diff --cached --name-only`. Se não listar os
  arquivos que você está gravando, o gate não vai olhar para eles.
- **Para medir de verdade**, rode a ferramenta direto nos arquivos que você tocou, sem depender do
  gate. Não confunda "o gate não reclamou" com "o código está limpo".
- **Se o hook é seu:** quando o índice estiver vazio **e** o comando for um `commit` com pathspec,
  **anuncie que pulou**. Precedente dentro do próprio ecossistema: o aviso de "sem venv encontrado"
  existe justamente porque *skip silencioso é o pior dos dois mundos, finge que protegeu*.

**Não faça:** concluir o mecanismo a partir da **ausência de sintoma**. No caso medido, a primeira
explicação para "o gate passou" foi *"esses arquivos têm grafo de import pequeno"* — plausível,
reproduzível na cabeça de quem escreveu, e **errada**. O índice é que estava vazio. Diagnóstico por
ausência de erro é o mesmo erro que o verbete descreve, cometido um nível acima.

**Ref:** Empresa Milionária, 2026-09-05. Dois commits reais de código de produção publicados sem
o type-checker ter olhado o diff. Ver também [[commit-com-pathspec-leva-o-disco-nao-o-staged]] e
[[arquivo-untracked-engana-a-ferramenta-que-le-o-indice]] (a mesma cegueira, por outra porta).
