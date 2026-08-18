## Consertei o hook no repo, a suíte ficou verde, e a máquina continua com o comportamento velho {#plugin-cache-nao-recebe-fix}

`tags: plugin, marketplace, CLAUDE_PLUGIN_ROOT, cache, autoUpdate, hooks, republish, versao instalada, installed_plugins, drift`

**Sintoma.** Você corrige um hook em `plugin/percus-review/hooks/`, roda a suíte, fica verde, commita —
e o comportamento na máquina **não muda**. Pior: a suíte verde vira evidência de que está consertado.

**Causa raiz.** `hooks.json` invoca `${CLAUDE_PLUGIN_ROOT}/hooks/*.cmd`, e `CLAUDE_PLUGIN_ROOT` resolve
para o **plugin instalado em cache** (`<CLAUDE_CONFIG_DIR>/plugins/cache/<marketplace>/<plugin>/<versao>/`),
**não** para a cópia de trabalho do kit. O que você edita e o que roda são artefatos diferentes, e os
testes do repo só enxergam o primeiro.

**Agravante medido em 2026-07-30:** `autoUpdate` vem ligado por padrão **apenas** para marketplaces
oficiais da Anthropic. Para marketplace próprio vem **desligado** — então o cache congela na versão do
último `/plugin update` manual. Aqui ficou **26 dias** parado, e nesse intervalo três guardas de
`PreToolUse` estavam mortas respondendo verde sem ninguém ver.

**Como confirmar em 10 segundos** (o `gitCommitSha` é a prova dura — se não é o do seu commit, o que
roda não é o que você consertou):

```powershell
$j = Get-Content "$env:CLAUDE_CONFIG_DIR\plugins\installed_plugins.json" -Raw | ConvertFrom-Json
$j.plugins.'<plugin>@<marketplace>'[0] | Select-Object version, gitCommitSha, lastUpdated
```

**Solução — publicar, não copiar:**
1. bump da versão em `plugin.json` **e** em `.claude-plugin/marketplace.json`
2. `git push` pro branch default do repo (é dele que o marketplace lê)
3. `/plugin marketplace update <marketplace>`
4. `/plugin update <plugin>@<marketplace>`
5. `/reload-plugins`, ou simplesmente a próxima sessão

No VS Code os slash commands `/plugin` não funcionam; o equivalente é `claude plugin marketplace update <marketplace>`
e `claude plugin update <plugin>@<marketplace>` num terminal.

**E ligue o auto-update de uma vez**, em `extraKnownMarketplaces` no `settings.json`:

```json
"percus-tools": { "source": { "source": "github", "repo": "..." }, "autoUpdate": true }
```

**Não copie arquivo pro cache à mão.** Funciona na hora e apodrece depois: o próximo update
sobrescreve, o cleanup de 14 dias apaga versão órfã, e o `installed_plugins.json` passa a mentir sobre
o que está rodando. Havia precedente disso no changelog do kit — era gambiarra, não referência.

**O que continua manual:** o `git pull` do próprio kit. O auto-update cuida do plugin em cache, não da
cópia de trabalho que o `PERCUS_CANON_DIR` aponta e de onde os gates de commit leem.

**Ref.** spec `docs/superpowers/specs/2026-07-30-guardas-mortas-powershell-51-design.md`;
`CANON_VERSION.md` v6.32.0. Relacionado: [ps51-ascii-hooks](ps51-ascii-hooks.md) — o defeito que ficou escondido atrás
disto.
