## O índice do git é uma TERCEIRA fonte da verdade — e "o agente disse que fez `git add`" não é medição {#indice-do-git-e-uma-terceira-fonte-da-verdade}

`tags: git, indice, staging, git add, subagente, delegacao, relatorio nao e medicao, commit errado, git diff vazio, rodada de correcao, R23`

**Sintoma:** você revisa a árvore de trabalho, aprova, commita — e o commit contém uma versão
ANTERIOR do código. Nada falha, nada avisa. O `git status` até mostra os arquivos como modificados.

**Cenário exato, medido em 07/09/2026 (Paid Media Automation):**

1. Código escrito por subagentes; eu rodei `git add -A <dirs>` para o revisor enxergar (revisor é
   cego a arquivo *untracked* — ver [[review_tool_blind_spot_untracked]]).
2. Review BLOQUEOU com defeitos reais.
3. Despachei uma rodada de correção. O agente corrigiu **na árvore** e reportou *"tudo staged"*.
4. Aceitei o relatório como medição.

O que estava no índice na hora de commitar:

```
git show :.../montar.ts | grep moedaExibida
    moedaExibida: currencyView.displayCurrency     ← o defeito de 5,4x, intacto
grep moedaExibida .../montar.ts
    moedaExibida: decisaoDeMoeda.currency          ← a correção, só na árvore
```

E os 30 gates novos da rodada estavam **untracked**: não entrariam no commit. Se eu tivesse
commitado, teria publicado exatamente o defeito que dois reviews haviam pego, com os testes que o
provariam ausentes.

**Causa raiz — três estados, não dois.** A intuição trata "o código" como uma coisa. São três:
**árvore**, **índice** e **HEAD**. `git commit` publica o **índice**; quase todo o resto que você
lê (editor, `grep`, testes, `tsc`, linters, revisores) lê a **árvore**. Enquanto ninguém escreve no
meio, os dois coincidem e a distinção fica invisível. Um `git add` seguido de mais edições
descoincide os dois — e é exatamente o formato de uma rodada de correção pós-review.

**A checagem, e ela é barata (`git diff` sem argumentos compara ÁRVORE × ÍNDICE):**

```bash
git add -A <paths>
git diff --stat -- <paths>                       # tem de sair VAZIO
git ls-files --others --exclude-standard <paths> # tem de sair VAZIO (nada untracked de fora)
git show :<arquivo> | grep '<a linha do fix>'    # a prova positiva, no índice
```

🔑 **Prova positiva, não só ausência de diff.** Confirme que **a linha corrigida está no índice**,
citando o fix pelo nome. "Nada difere" também é verdade quando você adicionou a versão errada duas
vezes.

⚠️ **Regra sobre relatório de subagente:** um agente dizer "staged/commitado/testado" é uma
afirmação sobre a intenção dele, não sobre o repositório. Delegue a edição, **nunca a verificação**
— e prefira instruir *"NÃO rode `git add` nem `git commit`; eu faço o staging"*, que remove a
ambiguidade na origem.

⚠️ **Um guard de commit tem de ler o índice.** Um gate que valide a árvore aprova um índice sujo —
ele estaria medindo o arquivo que não vai ser publicado. Use `git show :<path>`, com queda para a
árvore quando não houver versão staged (e diga de qual das duas leu).

Relacionado: [[duas-fontes-para-a-mesma-verdade]] (é a mesma família),
[[git-archive-leva-o-commit-nao-a-arvore]] (a mesma confusão pelo outro lado),
[[review_tool_blind_spot_untracked]].
