## Editar JSON (plugin.json) via sed/CLI quebra a string com aspas {#json-sed-aspas}

`tags: json, sed, plugin.json, aspas, quote, string invalida, ConvertFrom-Json, jq, parse error, CLI, bump`

**Contexto:** ao bumpar/editar um `.json` (ex.: `plugin.json`) com `sed`/replace via CLI, o arquivo fica
inválido — `ConvertFrom-Json` falha com "unexpected character" / "After parsing a value...".

**Causa raiz:** a string de substituição continha **aspas duplas literais** (ex.: `"atualizar projeto"`)
dentro de um valor JSON que já é delimitado por aspas duplas → a aspa fecha a string no meio e o resto
vira lixo sintático.

**Solução:** (1) nunca ponha aspas duplas no texto inserido num valor JSON — use aspas simples ou nenhuma;
(2) para edição não-trivial de JSON, **reescreva o arquivo inteiro** (Write com JSON bem-formado) em vez
de `sed`; (3) **sempre valide antes de commitar**: `Get-Content x.json -Raw | ConvertFrom-Json` (PS) ou
`jq . x.json` (Unix). O hook de commit não pega JSON inválido — a validação é sua.

**Ref:** incidente v6.25.0 (`plugin.json` description). Relacionado: lição de validar tooling antes de
declarar pronto.
