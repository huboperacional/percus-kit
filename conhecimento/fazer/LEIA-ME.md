# Como Fazer — procedimento-base canônico (cross-projeto)

> **Antes de inventar procedimento, consulte aqui.** Esta é a base do "jeito canônico de fazer X".
> Regra: **R23** (`01_REGRAS_INEGOCIAVEIS.md`). Fonte da verdade = git; sincroniza pra todas as
> máquinas via `git pull`.

## Um verbete por arquivo

Cada problema mora no **seu próprio arquivo**, e o **nome do arquivo é o slug da âncora**:

```
conhecimento/fazer/<slug>.md      ## Título {#slug}
```

Isso não é organização estética — é o que faz duas sessões de projetos diferentes escreverem
lições ao mesmo tempo sem colidir. O git resolve conflito em **arquivo**: enquanto os verbetes
moravam todos num `COMO_FAZER.md` único, sessões que escreviam sobre assuntos completamente
diferentes colidiam assim mesmo, e o commit de uma levava junto o rascunho inacabado da outra.

## Como consultar — grep primeiro

A linha `tags:` lista a **classe** de sintoma em termos independentes de locale e de wording.
Busque por classe, e o resultado vem em nomes de arquivo:

```sh
grep -l "tags:.*rls" conhecimento/fazer/*.md
grep -l "tags:.*hook" conhecimento/fazer/*.md
```

Precisa de visão ampla em vez de uma classe específica? `INDICE.md` lista todos os títulos.
Não leia a pasta inteira: são ~17 verbetes.

## Como registrar

Escreva o arquivo direto. Não há passo de merge, não há caixa de entrada, não há espera.

**Formato:** `## <tarefa> {#ancora-kebab}` · `tags:` · **Quando** · **Passos** · **Armadilhas** · **Ref:**

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
