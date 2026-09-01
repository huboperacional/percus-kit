## Review cross-provider lê o `git diff` — arquivo NOVO é untracked e vira "finding fantasma" {#review-le-o-diff-arquivo-novo-parece-ausente}

tags: finding fantasma, arquivo untracked, modulo nao existe, review nao ve arquivo novo, git add antes do review

**Sintoma:** o revisor automático abre finding de severidade `bug` dizendo que um módulo
importado "não existe", que falta uma migration, ou que um atributo de modelo não foi criado —
e nada disso é verdade. A suíte está verde, a aplicação sobe, e o finding descreve uma falha
que não acontece.

**Causa raiz:** o wrapper de review monta o contexto a partir do **`git diff`**, que por
definição só mostra arquivo **rastreado**. Arquivo novo ainda está em `??` (untracked) e não
aparece — então o revisor vê o `import` do lado do consumidor e **não vê** o arquivo importado.
A inferência dele é correta *dado o que ele viu*; o que faltou foi o arquivo.

Vale para toda mudança que o diff não carrega: coluna que já existia (o modelo não mudou, logo
não há diff), constante definida em commit anterior, migration antiga que já contempla o campo.

**Como confirmar (evidência, ~10s):**
```bash
git status --short          # os '??' sao o que o revisor NAO viu
git diff --stat             # o que ele viu
```
Se o alvo do finding está em `??`, é fantasma. Confirme que o arquivo existe e que os testes
que dependem dele passam — isso basta para rejeitar.

**Solução — duas, e a segunda é melhor:**

1. **Rejeitar com evidência**, registrando no commit *por que* o finding não procede. Custa uma
   linha e evita que a próxima pessoa reabra a mesma discussão.
2. **`git add` ANTES de rodar o review.** Com os arquivos no índice, o revisor passa a enxergar
   o conjunto completo e para de gerar o fantasma. ⚠️ Cuidado com o gate de pre-commit que exige
   artefato de review recente: `add` e `commit` continuam em chamadas separadas, e o review roda
   entre eles.

**Por que isto merece registro:** o fantasma é convincente. Ele descreve um `ModuleNotFoundError`
plausível, com caminho de arquivo certo, em severidade `bug`. Quem trata findings em série tende
a "consertar" — e o conserto de um problema inexistente é como se acrescenta código morto, ou
pior, uma migration duplicada de coluna que já existe.

**Ref:** Empresa Milionária, Fase B, 2026-08-14. O mesmo padrão gerou finding em três commits
diferentes (`listar_titulos.py`, `test_endpoints_edicao.py`, `parcelar_titulo.py`), sempre com o
mesmo texto de "não está no diff".

**A mesma causa produz o oposto do finding fantasma: "sem findings críticos" que não avaliou
nada.** Medido em 2026-08-31, mesmo projeto: rodei o review sobre um diretório novo inteiro
(9 arquivos `.ts`/`.sql` de um harness, todos `??`) SEM dar `git add` antes. O wrapper reportou
`decisao: deepseek (... 4 arquivo(s))` — os 4 eram arquivos ALHEIOS já rastreados e modificados
por outra sessão; os 9 meus, recém-criados, nunca entraram no `git diff` e o veredito
"sem findings críticos" não dizia nada sobre eles. `git add` dos meus arquivos e rodar de novo
mudou pra `13 arquivo(s)` e aí sim produziu 3 achados reais (dois confirmados por mim, um
corrigido). **A contagem de arquivos no log do wrapper é o sinal barato**: se ela não bate com
o que você espera revisar, o silêncio "sem findings" é silêncio de quem não olhou, não aprovação.
