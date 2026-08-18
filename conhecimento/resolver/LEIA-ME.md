# Como Resolver — registro de problemas → solução (cross-projeto)

> **Antes de gastar tempo debugando, consulte aqui.** Esta é a base de "já vimos esse problema".
> Regra: **R23** (`01_REGRAS_INEGOCIAVEIS.md`). Fonte da verdade = git; sincroniza pra todas as
> máquinas via `git pull`.

## Um verbete por arquivo

Cada problema mora no **seu próprio arquivo**, e o **nome do arquivo é o slug da âncora**:

```
conhecimento/resolver/<slug>.md      ## Título {#slug}
```

Isso não é organização estética — é o que faz duas sessões de projetos diferentes escreverem
lições ao mesmo tempo sem colidir. O git resolve conflito em **arquivo**: enquanto os verbetes
moravam todos num `COMO_RESOLVER.md` de 1 MB, sessões que escreviam sobre assuntos completamente
diferentes colidiam assim mesmo, e o commit de uma levava junto o rascunho inacabado da outra.

## Como consultar — grep primeiro

A linha `tags:` lista a **classe** de sintoma em termos independentes de locale e de wording.
Busque por classe, e o resultado vem em nomes de arquivo:

```sh
grep -l "tags:.*rls" conhecimento/resolver/*.md
grep -l "tags:.*hook" conhecimento/resolver/*.md
```

Precisa de visão ampla em vez de uma classe específica? `INDICE.md` lista todos os títulos.
Não leia a pasta inteira: são ~400 verbetes.

## Como registrar

Escreva o arquivo direto. Não há passo de merge, não há caixa de entrada, não há espera.

**Formato:** `## <sintoma curto> {#ancora-kebab}` · `tags:` · **Contexto** (ou **Sintoma**) ·
**Causa raiz** · **Solução** · **Ref:**

O gate barra, no commit:
- `##` sem âncora `{#slug}` fechando a linha
- âncora que não bate com o nome do arquivo
- verbete sem linha `tags:` (nasce invisível à busca)
- bloco de código aberto e nunca fechado
- link para verbete que não existe

## Relacionar verbetes

Link de arquivo relativo, e ele é **verificado pelo gate**:

```md
**Relacionado:** [título do outro verbete](outro-slug.md)
```

`INDICE.md` é **gerado** por `scripts/gerar-indice-conhecimento.ps1`. Não edite à mão.
