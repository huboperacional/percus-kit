## A leitura de versão do `enforcement-health` VENCE no meio da sessão — `autoUpdate` fecha a divergência sozinho enquanto você "conserta" {#health-check-versao-vence-autoupdate}

`tags: enforcement-health, SessionStart, versao instalada diferente do kit, autoUpdate, installed_plugins.json, plugin cache, percus-review, trampolim, hooks.json, registro vs codigo, aviso obsoleto, retrato do launch`

**Sintoma:** o `SessionStart` abre a sessão com `versao instalada (X) diferente da do kit (Y) --
mudanca de REGISTRO (matcher, hook novo) ainda nao vale nesta maquina`. Você trata o aviso como
estado corrente, diagnostica a diferença e **escreve doc/decisão em cima dela** — e ela já não
existe.

**Contexto (Scraper-prospeccao, alinhamento 6.32.0→6.35.0, 2026-08-11):** o hook acusou
`6.34.1 ≠ 6.35.0` no launch. Diagnóstico feito, parágrafo escrito no `CLAUDE.md` explicando por que
ficar atrás era normal. ~20 min depois, o `percus-review-auto.sh` imprimiu
`plugin pasta=6.35.0 plugin.json=6.35.0` — numa pasta que **não existia** na listagem do cache feita
minutos antes. O `installed_plugins.json` confirmou: `lastUpdated` reescrito no meio da tarefa.

**Causa raiz:** `autoUpdate: true` no marketplace `percus-tools` busca a versão nova **depois** que a
sessão sobe, com atraso aleatório de até 10 min (documentado no `CANON_VERSION.md`). O
`enforcement-health` roda uma vez, no `SessionStart`, **antes** disso. A saída dele é um retrato do
launch que nada invalida depois — não há segundo aviso dizendo "pronto, alinhou".

**Solução:**
1. **Releia `~/.claude-home/plugins/installed_plugins.json` antes de agir sobre o aviso** — não a
   memória do que o hook disse, e não a listagem de pastas do cache (aqui são **7** versões; escolher
   "no olho" erra). O `installPath`/`version` da entrada `percus-review@percus-tools` é a verdade.
2. Só então decida se há o que fazer. E quase sempre não há, pelo item 3.
3. **Divergência de versão é sobre REGISTRO, não sobre comportamento.** O **código** dos hooks vem do
   kit pelo trampolim da v6.33.0 (`git pull` basta); só **hook novo ou matcher novo** exige
   publicação. Pra saber em qual caso você está, compare os registros:
   `diff "$PERCUS_CANON_DIR/plugin/percus-review/hooks/hooks.json" "<install>/hooks/hooks.json"`.
   Idênticos = nada a publicar, independente do número da versão.

**Prova estática que não dá falso verde:** pra saber qual `.ps1` roda de verdade, **leia o `.cmd`**,
não o `.ps1` do cache — o wrapper tem a linha
`set "PERCUS_HOOK_PS1=%PERCUS_CANON_DIR%\plugin\…"`. Medido neste caso: o
`external-action-guard.ps1` **do cache não tinha** a autorização em lote da v6.35.0 e o **do kit
tinha** — ou seja, o comportamento "novo" já estava vivo com o plugin "velho" instalado. Quem
tivesse olhado só o `.ps1` do cache concluiria o oposto.

**Consequência que vale além do caso:** health check que roda **uma vez** produz um valor com prazo
de validade, e prazo de validade não aparece na saída. Quando a mesma máquina tem um mecanismo
automático mexendo naquilo que o check mede, o check é um **gatilho pra ir olhar**, nunca a
observação final. O sinal de que isso aconteceu costuma vir de fora do check — aqui, de uma linha de
log de outra ferramenta citando uma versão impossível.

**Relacionado:** [#smoke-certo-mas-caminho-nao-rodou] (confirme o caminho, não a saída) ·
[#teste-string-nao-prova-gate-runtime] (conferir o texto do arquivo não prova o que roda).

**Ref:** Scraper-prospeccao, alinhamento ao canon 6.35.0 (2026-08-11). `installed_plugins.json`
`lastUpdated: 2026-08-11T22:57:34Z`. R23.
