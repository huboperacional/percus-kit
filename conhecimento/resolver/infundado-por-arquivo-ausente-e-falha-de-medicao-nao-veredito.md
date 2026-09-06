## `INFUNDADO — arquivo ausente` no fact-check é falha de MEDIÇÃO, não veredito {#infundado-por-arquivo-ausente-e-falha-de-medicao-nao-veredito}

`tags: r11, review, fact-check, git add -N, intent-to-add, indice, falso negativo, arquivo novo, deepseek, cross-claude`

**Sintoma:** você roda o R11 sobre um arquivo **novo**, o revisor devolve achados, e o estágio de
fact-check carimba todos como `INFUNDADO (filtrado) — não foi possível verificar (sem path
verificável ou arquivo ausente)`. O bloco principal fica com **"Sem findings críticos"**, que é
**indistinguível de aprovação**. Você commita achando que passou.

**Causa raiz:** para o revisor enxergar arquivo novo é preciso `git add -N` (intent-to-add) — sem
isso ele não aparece no diff e passa verde sem ser lido. Mas `add -N` **registra o caminho no
índice sem o conteúdo**: o git grava ali o **blob vazio**. O verificador tenta abrir o arquivo pelo
índice, recebe zero bytes, e conclui "não consigo verificar" para **todo** achado daquele arquivo.
Os dois mecanismos que você precisa se anulam.

**Como discriminar em que estado o arquivo está** (medido em repo descartável, 2026-09-05):

| | `git diff --cached --numstat <arq>` | `git cat-file -p :<arq>` | `git ls-files -s <arq>` |
|---|---|---|---|
| `add -N` | **saída vazia** (0 linhas) | **exit 0**, 0 bytes | hash `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` |
| `add` normal | `3\t0\t<arq>` | exit 0, N bytes | hash do conteúdo |

O sinal **positivo** é o hash: `git ls-files -s <arq> | grep -q e69de29` afirma que o índice tem o
blob vazio — a constante universal do git para conteúdo zero. As outras duas colunas respondem com
**ausência** (vazio, zero), e ausência é a família de armadilha que este canon mais registra.

⚠️ **`cat-file -p` NÃO discrimina, embora pareça o teste óbvio:** o objeto existe nos dois casos e o
comando sai com sucesso. Um check por exit code passaria sempre — controle positivo decorativo,
exatamente o defeito que ele existiria para pegar.

**Conserto:**

1. Depois de qualquer review com `add -N`, se a linha do fact-check trouxer `infundado > 0`, **leia
   os achados no `.deepseek/reviews/d-*.jsonl` (campo `findings`) NA HORA** — a pasta é podada a
   cada review de qualquer sessão, então o conteúdo some em minutos.
2. Ou faça o `git add` real e **rode o review de novo** imediatamente antes do commit.
3. Trate `INFUNDADO por ausência` como **pendente de leitura sua**. Só é infundado de verdade
   quando o motivo é contradição medida (ex.: *"o próprio finding conclui que não há problema"*).

**Por que isso custa caro:** numa feature de 2026-09-05, uma única task acumulou **10 achados**
carimbados assim sobre o mesmo arquivo, e só 1 foi lido. A releitura dos arquivos cegados devolveu
**3 riscos legítimos** (contexto de RLS restaurado pela metade, `finally` mascarando a causa raiz
com `PendingRollbackError`, e corrida de escrita duplicada) — e, ao consertá-los, mais **3 achados
reais** vieram com o mesmo carimbo, incluindo um bug recém-introduzido e um teste que não
exercitava a lógica que dizia guardar. Seis defeitos reais atrás de um "sem findings críticos".

**Mitigação estrutural que não custa nada:** quando o router escala para `dual`/`council`, o
Cross-Claude **lê os arquivos do disco** e não depende do índice — ele acha o que o fact-check
descartou. Em pasta não-sensível, onde a decisão é só `deepseek`, essa rede não existe: é lá que a
leitura manual do jsonl é obrigatória.

Ver também: [[arquivo-untracked-engana-a-ferramenta-que-le-o-indice]] (a metade oposta: sem
`-N` o revisor nem vê o arquivo), [[fact-check-infundado-e-nao-verificado]] (a classe geral,
de 31/07) e [[fact-check-trunca-path-e-descarta-finding-valido]].
