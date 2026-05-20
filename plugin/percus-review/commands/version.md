---
description: Mostra a versão do plugin percus-review + changelog condensado e checa sincronia com o canon (.percus-version)
disable-model-invocation: true
allowed-tools: Read, Bash
---

# /version — Versão do kit Percus

Mostra a versão instalada do plugin `percus-review`, o changelog condensado, e
— se o canon estiver alcançável — verifica se a versão instalada bate com o
canon. Resolve a confusão recorrente de "qual versão estou rodando".

## Passo 1 — Versão do plugin instalado

Leia `${CLAUDE_PLUGIN_ROOT}/plugin.json`. Extraia:

- `version` — versão do plugin instalado AGORA nesta sessão.
- `description` — contém o changelog condensado rolante (vX.Y.Z — resumo +
  "Mantém vX..." das versões anteriores).

## Passo 2 — Sincronia com o canon (se alcançável)

O canon (`_Novo_Projeto`) é a fonte de verdade da versão. Tente localizá-lo:

1. Se `$env:PERCUS_CANON_DIR` está setado e existe, use-o.
2. Senão, procure `D:\Claud Automations\_Novo_Projeto` (Windows) ou
   `~/Claud Automations/_Novo_Projeto`.
3. Se não achar, pule este passo (reporte "canon não alcançável — só versão do plugin").

Achando o canon, leia:

- `<canon>/.percus-version` — versão canônica declarada.
- As 2 primeiras seções `## Changelog vX.Y.Z` de `<canon>/CANON_VERSION.md` —
  changelog detalhado das releases recentes.

## Passo 3 — Diagnóstico de drift

Compare:

- `plugin.json` version (instalado) **vs** `.percus-version` (canon).
- Se **iguais**: ✅ "plugin instalado em sync com o canon (vX.Y.Z)".
- Se **diferentes**: ⚠️ destaque o gap — ex: "plugin instalado é v6.8.0 mas o
  canon já está em v6.8.2. Atualize o plugin pela UI do Claude Code
  (marketplace → percus-tools → update)."

Esse drift é comum: o cache do plugin não atualiza sozinho quando o canon
recebe push. A `marketplace.json` da raiz é a fonte que a UI consome.

## Passo 4 — Apresentar

Formato conciso:

```
[percus-review:version]
  Plugin instalado:  vX.Y.Z
  Canon (.percus-version): vX.Y.Z   (ou "não alcançável")
  Sync: ✅ em dia  |  ⚠️ <descrição do gap>
  ---
  Changelog recente:
  <2 entradas mais recentes — título + 1-2 linhas cada>
```

Não invente versões nem changelog — leia sempre dos arquivos. Se um arquivo
não existir ou não parsear, diga isso explicitamente em vez de adivinhar.
