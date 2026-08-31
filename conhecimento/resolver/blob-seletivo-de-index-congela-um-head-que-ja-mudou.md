## Blob seletivo de index congela um HEAD que já mudou — re-confira o HEAD imediatamente antes do commit {#blob-seletivo-de-index-congela-um-head-que-ja-mudou}

`tags: git, index, hash-object, update-index, arvore compartilhada, duas sessoes, race, commit, pathspec, tenancy, R23`

**Sintoma:** numa árvore compartilhada por duas sessões, uma sessão monta o conteúdo de
um arquivo para o INDEX à mão (`git hash-object -w` + `git update-index --cacheinfo`),
removendo o "bloco da outra" para não commitar trabalho alheio. O commit passa limpo.
Dias (ou minutos) depois, um checkout limpo falha num teste de coerência
(classificação de rota, lista declarativa) que o working tree de todo mundo passa —
**a árvore commitada perdeu linhas que a outra sessão JÁ tinha commitado**.

**Causa raiz:** o blob seletivo é construído contra um retrato mental do HEAD
("aquelas linhas são trabalho não-commitado dela"). Se a outra sessão commita o bloco
dela ENQUANTO o blob é montado, as linhas mudam de status — de *trabalho alheio
não-commitado* (que o blob deve excluir) para *conteúdo do HEAD* (que o blob deve
preservar). O commit seguinte entra por cima e **remove da árvore** o que já era
história. O disco continua certo (tem os dois blocos), então a suíte local fica verde
e o defeito só aparece em checkout limpo — medido na Empresa Milionária (2026-08-30):
o `28401ba` apagou 3 entradas de tenancy que o `72d54c1` da outra sessão tinha
commitado minutos antes; rota existindo sem classificação = harness vermelho só na
árvore commitada.

**Correção:** entre montar o blob e commitar, **re-leia o HEAD do arquivo** e derive o
blob do HEAD, não do disco:

1. `git log --oneline -3` — o HEAD é o que você acha que é? Commit novo de outra
   sessão no meio = pare e remonte.
2. Prefira montar o blob como **HEAD + suas linhas** (aditivo) em vez de **disco −
   linhas alheias** (subtrativo). O aditivo sobrevive ao commit alheio; o subtrativo
   apaga o que ele commitou.
3. Depois do commit, `git show HEAD:<arquivo> | grep <marcador-alheio>` — a contagem
   das linhas do vizinho tem de ser ≥ a do pai do seu commit (`HEAD^`).

**Como reconhecer:** `git show <seu-commit>^:<arquivo>` contém as linhas; o seu commit
não; o disco sim. A tríade (pai TEM, commit NÃO TEM, disco TEM) é a assinatura.

**Relacionado:** commit-com-pathspec-leva-o-disco-nao-o-staged (o irmão inverso: lá o
pathspec leva junto o que não devia; aqui o blob deixa de fora o que devia ficar).
