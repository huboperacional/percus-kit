# `.archive/` — o que foi aposentado, e por que ainda está aqui

Nada aqui é lido pelo canon em execução. Isto é **registro**: o gate anti-path-legado
(`plugin/percus-review/tests/no-legacy-kit-path.tests.ps1`) ignora esta pasta de propósito,
porque reescrever o passado falsifica o passado.

## `v2-experimento-standalone.bundle`

Os **8 commits** do experimento V2, que viveu em `D:\Claud Automations\_Novo_Projeto_V2` de
2026-07-20 a 2026-07-27 (`e027235` → `9f983c3`, branch `master`).

**Por que virou bundle em vez de morrer com a pasta:** aquele repo **não tinha remote**. O
conteúdo dele foi dobrado pra dentro de `v2/` do kit, mas a *história* não existia em lugar
nenhum — apagar a pasta apagava os 8 commits pra sempre. O `.rar` que existia ao lado
(`_Novo_Projeto_V2.rar`, 2026-07-21) estava 6 dias atrasado e não cobria o estado final.

Os 3 verbetes não-commitados que estavam em `referencia/conhecimento/COMO_RESOLVER.md`
daquela pasta **não** estão no bundle (não eram rastreados) — foram para
`conhecimento/COMO_RESOLVER.md` deste kit: `#sessao-30-dias-nao-persiste`,
`#auditar-outro-repo-ref-publicada` e `#env-stale-sobrepondo-default`.

**Como voltar a ler:**

```bash
git clone "<kit>/.archive/v2-experimento-standalone.bundle" /tmp/v2-experimento
git -C /tmp/v2-experimento log --oneline
```

Verificado em 2026-07-30: `git bundle verify` diz *complete history*, e o clone materializa
os 8 commits com a árvore de trabalho inteira.

## `PADRAO_AUTH_CROSS_PROJETO.md`

Camada v1 do padrão de auth cross-projeto. Substituído por `PADRAO_AUTH_SERVICE.md` e
`CONSUMIR_AUTH_SERVICE.md` na raiz do kit.
