---
name: consult-knowledge
description: Use ANTES de gastar tempo debugando um problema que parece conhecido, OU ao precisar do procedimento-base canônico de uma tarefa recorrente (deploy, git, migration). Lê a base de conhecimento Percus (conhecimento/resolver/ + conhecimento/fazer/) e casa por CLASSE de sintoma, não string literal. Também usada ao FIM de um problema resolvido, para registrar a solução (R23).
---

# Percus — Consultar Base de Conhecimento (R23)

Base cross-projeto versionada no canon. **Um arquivo por verbete**, duas áreas:

- `${env:PERCUS_CANON_DIR}/conhecimento/resolver/<slug>.md` — **problema → solução** (troubleshooting)
- `${env:PERCUS_CANON_DIR}/conhecimento/fazer/<slug>.md` — **procedimento-base** (como fazer X canônico)

O **nome do arquivo é o slug da âncora**. São ~400 verbetes em `resolver/`.

## Quando usar

- **Bateu num erro/comportamento estranho que parece conhecido** → CONSULTE antes de debugar do zero.
- **Vai fazer uma tarefa recorrente** (commit/review, rodar conselho, migration, deploy) → confira o padrão.
- **Acabou de resolver um problema não-trivial** → REGISTRE a solução (gate R23 / `CHECKLIST_ENCERRAR_SESSAO`).

## Como consultar — grep pelas tags, primeiro

A linha `tags:` de cada verbete lista a **classe** de erro, o componente e termos independentes de
locale. Como cada verbete é um arquivo, o grep devolve **nomes de arquivo** — e custa o tamanho da
resposta, não o da base:

```sh
grep -l "tags:.*rls" conhecimento/resolver/*.md
grep -l "tags:.*hook" conhecimento/resolver/*.md
grep -l "tags:.*deploy" conhecimento/fazer/*.md
```

Depois **leia só o(s) verbete(s) que casaram**. Um verbete típico tem 3–6 KB.

> ⚠️ **Case por CLASSE, não por string do sintoma.** Sintomas reais variam em wording, stack e
> locale. Busque o termo da *classe* (`rls`, `crlf`, `matcher`, `cache de borda`), não a frase de
> erro que você recebeu. Se o primeiro termo não achar nada, tente o sinônimo da classe antes de
> concluir que não existe.

**Precisa de visão ampla** ("o que existe sobre isto?") em vez de uma classe específica? Leia
`conhecimento/resolver/INDICE.md` — títulos e links, gerado a partir dos arquivos.

⚠️ **Não leia a pasta inteira.** São ~400 verbetes; junto dá ~250k tokens. O ponto de a base ser um
arquivo por verbete é justamente você nunca precisar disso.

Se nada casar, debugue normalmente — e ao resolver, volte pra registrar.

## Como registrar (após resolver algo novo)

Escreva o arquivo **direto**:

```
conhecimento/resolver/<slug>.md    # troubleshooting
conhecimento/fazer/<slug>.md       # procedimento
```

Não há passo de merge, não há caixa de entrada, não há espera — arquivos diferentes não colidem no
git, então duas sessões escrevendo ao mesmo tempo não se veem.

O **nome do arquivo tem de ser exatamente o slug** da âncora (`{#slug}`) — o gate barra se divergir.

- Troubleshooting: `## <sintoma> {#ancora}` · `tags:` · Contexto · Causa raiz · Solução · **Ref:**
- Procedimento: `## <objetivo> {#ancora}` · `tags:` · Quando · Passos · Comando · Armadilhas · **Ref:**

**Relacionar verbetes** usa link de arquivo relativo, e ele é **verificado pelo gate**:

```md
**Relacionado:** [título do outro](outro-slug.md)
```

Depois de escrever, regenere o índice:

```powershell
pwsh -File "${env:PERCUS_CANON_DIR}\scripts\gerar-indice-conhecimento.ps1"
```

## Anti-padrões

- ❌ `grep` pela **frase de erro** e concluir "não tem nada" — busque o termo da classe nas `tags:`.
- ❌ Ler a pasta inteira ou o `INDICE.md` quando você já tem hipótese de classe — o grep é mais barato e mais preciso.
- ❌ Debugar 30 min um problema que já estava catalogado (não consultou) — R23.
- ❌ Resolver incidente não-trivial e encerrar sem registrar — conhecimento se perde (R23).
- ❌ Editar `INDICE.md` à mão — é gerado; índice divergente do conteúdo já escondeu 14 verbetes por semanas.
- ❌ Recriar `conhecimento/COMO_*.md` — foram aposentados; o hook `knowledge-write-guard` recusa.

## Referências

- Regra: `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` R23.
- Formato de cada área: `conhecimento/resolver/LEIA-ME.md`, `conhecimento/fazer/LEIA-ME.md`.
- Gates de captura: `checklists/CHECKLIST_ENCERRAR_SESSAO.md`, skill `percus-review:checkpoint`.
