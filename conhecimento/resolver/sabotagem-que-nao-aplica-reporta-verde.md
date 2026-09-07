## Sabotagem que não chegou ao arquivo reporta VERDE, e o verde é do código original {#sabotagem-que-nao-aplica-reporta-verde}

`tags: sabotagem, mutation testing, sed, sed -i, ancora $, CRLF, git archive, guarda cega, falso verde, prova de aplicacao, ferramenta que falha em silencio, exit 0, pytest, N passed, cat -A, numero de linha`

**Sintoma:** você sabota uma guarda de propósito, roda a suíte esperando vermelho, e vem **`N passed`**. A leitura natural é *"a guarda não morde, é guarda cega"* — e ela pode estar perfeitamente boa. O que aconteceu é que a **sabotagem não foi aplicada**, e a suíte rodou o código original.

**Causa raiz:** a ferramenta que edita falhou **em silêncio**. O caso medido: `sed -i 's/^        await marcarPapelProvado.*$/        pass/' arquivo.py` casou **zero** ocorrências porque o arquivo estava em **CRLF** — o `$` ancorava antes do `\r`, que não estava no padrão. `sed` **não reclama quando não casa nada**: sai `0`, sem saída, indistinguível de sucesso. O arquivo tinha vindo por `git archive`, que entrega o conteúdo com a conversão de fim de linha do repositório (ver [[git-archive-windows-crlf-mata-entrypoint]] e [[regex-multiline-crlf-dollar-nao-casa]]).

A mesma classe aparece sem CRLF nenhum: `cp` para um caminho que só o outro runtime enxerga (`/tmp` diverge entre bash e Python no Windows), `patch` que aplica com offset em outro bloco, `sed` cujo padrão casa uma linha vizinha.

**Solução:** **provar a aplicação antes de ler o resultado**, sempre, e no mesmo par de comandos:

```bash
sed -i '779s/.*/        pass  # SABOTADO/' arquivo.py   # por NUMERO DE LINHA: independe de EOL
sed -n '779p' arquivo.py                                 # PROVA: imprime a linha ja trocada
pytest ...                                               # so agora o resultado significa algo
```

E, ao restaurar, prove também: `grep -c SABOTADO` tem de voltar a **0**.

**Onde mais morde:** baterias de sabotagem automatizadas que gravam, rodam e restauram num laço. Se a gravação falha silenciosamente, o laço reporta "nenhum teste caiu" para todas as agulhas e a conclusão vira *"as guardas são todas cegas"* — exatamente ao contrário. Uma bateria robusta lê e escreve em **bytes**, conta ocorrências e `assert count == 1` **antes** de substituir, confere que o disco mudou, e restaura comparando bytes: `sed` que não casa fica calado, `assert` não.

**Como reconhecer na hora:** "verde depois de sabotar" tem **duas** hipóteses, não uma — *a guarda não morde* **ou** *a sabotagem não chegou*. Descarte a segunda antes de acusar a primeira. Sinal barato: o mesmo `N passed` **idêntico** ao da execução limpa, incluindo o tempo. Sabotagem que aplica quase sempre muda alguma coisa no placar.

**Ref:** 2026-09-07, Empresa Milionária — Task 18 do intercompany, janela R20. A 1ª sabotagem devolveu `10 passed` e quase virou "guarda cega" no ledger; `cat -A` mostrou `^M$` e a troca por número de linha produziu o `1 failed / 9 passed` esperado, no teste certo. Irmão de [[sabotagem-prova-a-primeira-assercao-nao-o-teste]]: lá a sabotagem aplica e prova menos do que parece; aqui ela não aplica e parece provar o contrário.
