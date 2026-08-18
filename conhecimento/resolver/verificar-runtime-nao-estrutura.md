## Declarei hook/gate "instalado/consertado" checando a estrutura, nao RODANDO no cenario real {#verificar-runtime-nao-estrutura}

`tags: verificacao, evidencia observada, hook, gate, pre-commit, rodar nao olhar, runtime, env var ausente, fail-closed, dead code, estrutura vs comportamento, verification before completion, cenario real, shell sem env var`

**Sintoma:** voce instala/conserta um hook ou gate, confere que "esta la" e declara pronto. Numa sessao/maquina diferente ele nao roda -- ou como dead code (nunca executa), ou fail-closed travado (bloqueia tudo antes do check que importa). O defeito passa porque a verificacao foi ESTRUTURAL, nao de COMPORTAMENTO.

**Causa raiz:** "o arquivo tem o bloco certo" e "o script roda sozinho" NAO provam "o hook faz a coisa certa no commit real". Um hook depende do AMBIENTE de quando dispara: env var que nao propaga pra shell nova, `exit 0` de um bloco anterior que mata o codigo seguinte, cwd diferente, PATH diferente. Checar a estrutura e cego pra tudo isso.

**Solução:**
1. **Verifique RODANDO, no cenario de runtime real.** Pra hook de git: rode o proprio hook (`sh .git/hooks/pre-commit`), nao o script que ele chama. Reproduza a condicao adversa -- ex.: `env -u PERCUS_CANON_V2_DIR sh .git/hooks/pre-commit` (env var DESLIGADA), com um caso que DEVE passar e um que DEVE bloquear.
2. **Exija os DOIS sinais:** passa quando deve (nao trava por acidente) E bloqueia quando deve (com a mensagem certa -- "teto 150", nao "nao definida").
3. **"O script funciona" != "o hook roda no commit".** Rodar `percus-gate.sh` direto passando nao diz nada sobre o hook: o gate pode estar como dead code, ou o hook pode travar antes de chega-lo.
4. **Fallback pra estado de ambiente:** o que depende de env var deve ter fallback duravel (arquivo gravado na instalacao) -- env var e o modo mais fragil de passar estado, some entre shells.
5. E a regra `superpowers:verification-before-completion` / "evidencia observada, nunca assercao" aplicada a hook: a evidencia e a EXECUCAO no cenario real, nao a leitura do arquivo.

**Ref:** canon Percus, gate V2 no pre-commit, 2026-07-21. Declarei hooks "VIVO" checando a estrutura (gate alcancavel); rodei `percus-gate.sh` direto, nunca o hook num shell sem `PERCUS_CANON_V2_DIR`. Sessao fria rodou de verdade: hook fail-closed travado (bloqueava qualquer commit). 3a vez no mesmo dia que verificacao estrutural escondeu defeito de runtime. Fix real so veio ao rodar `env -u PERCUS_CANON_V2_DIR sh .git/hooks/pre-commit`.
