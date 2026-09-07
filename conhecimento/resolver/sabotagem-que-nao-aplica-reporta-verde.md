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

**Terceira hipótese, e ela é pior: a sabotagem chegou e foi DESFEITA antes do teste rodar.** Quando o alvo é **DDL no banco** (e não código-fonte), uma fixture que compara o schema na entrada do módulo e **remigra** apaga a sabotagem antes da primeira asserção — e o resultado é `passed` com o mecanismo intacto. Medido duas vezes: `ALTER TABLE ... NO FORCE ROW LEVEL SECURITY` e `DROP CONSTRAINT`, os dois revertidos pela fixture, os dois reportando `1 passed`. Só um **pós-check no catálogo** (`pg_class.relforcerowsecurity`, `pg_constraint`, `pg_indexes`) denunciou.

A regra que sai daí: **sabote a FONTE — a migration ou o helper que emite o DDL — nunca o banco.** Aí a remigração produz o estado quebrado de verdade, e o teste cai pelo motivo certo. E não presuma ponto único de emissão: `FORCE` pode vir do helper central **e** de SQL literal dentro de uma migration; `rg` a fonte antes de escolher onde sabotar.

**Como reconhecer na hora:** "verde depois de sabotar" tem **três** hipóteses, não uma — *a guarda não morde*, *a sabotagem não chegou ao arquivo*, ou *a sabotagem foi revertida antes do teste*. Descarte as duas últimas antes de acusar a primeira. Sinal barato: o mesmo `N passed` **idêntico** ao da execução limpa, incluindo o tempo. Sabotagem que aplica e sobrevive quase sempre muda alguma coisa no placar — e o **vermelho no teste esperado** é, ele mesmo, a prova de que ela chegou viva até a execução.

**Ref:** 2026-09-07, Empresa Milionária — Task 18 do intercompany, janela R20. A 1ª sabotagem devolveu `10 passed` e quase virou "guarda cega" no ledger; `cat -A` mostrou `^M$` e a troca por número de linha produziu o `1 failed / 9 passed` esperado, no teste certo. Irmão de [[sabotagem-prova-a-primeira-assercao-nao-o-teste]]: lá a sabotagem aplica e prova menos do que parece; aqui ela não aplica e parece provar o contrário.
