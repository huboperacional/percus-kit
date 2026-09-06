## Repro isolado fora da árvore do projeto **inventa** limitação de ferramenta — e ela vira comentário permanente no código {#repro-fora-da-arvore-inventa-limitacao-de-ferramenta}

`tags: mypy, repro, sys.path, ignore_missing_imports, falso positivo, medicao, comentario mentiroso, causa nao medida, controle positivo, R23`

**Sintoma:** alguém encosta num erro estranho do type checker (ou linter, ou build), monta um
arquivinho isolado num diretório temporário para reproduzir, **reproduz**, e conclui uma limitação
da ferramenta: *"o alias X faz o mypy perder o genérico"*, *"o decorator Y apaga o tipo"*. A
conclusão então vira **comentário no código** ("workaround porque a ferramenta não resolve Z") e,
pior, vira **lição repassada** para as próximas fatias — gerando churn e afastando o código do
idioma que já roda em produção.

**Causa raiz:** o repro fora da árvore não tem o `sys.path`/`MYPYPATH` do projeto, então os imports
de primeira parte **não resolvem**. Com `ignore_missing_imports = True` (comum em config de adoção
incremental), o módulo não resolvido vira `Any` — e tudo que depende dele vira `Any` em cascata. O
erro que aparece é **real**; a causa atribuída é **inexistente**.

```
### SEM MYPYPATH (imports de primeira parte viram Any) ###
t.py:13: error: Returning Any from function declared to return "Sequence[Any]"  [no-any-return]
### COM MYPYPATH=backend (imports reais) ###
Success: no issues found in 1 source file
```

**Medido em Plexco Tasks (2026-09-06):** um implementador "provou" que `db: DbSession` (um
`Annotated[AsyncSession, Depends(get_db)]`) fazia o mypy perder o parâmetro genérico de
`.scalars().all()`, e envolveu 7 retornos em `list(...)` por causa disso — gravando a alegação em 3
comentários permanentes. Era falsa. O contra-exemplo estava **no próprio relatório dele**:
`products.py` usa exatamente `db: DbSession` + `return result.scalars().all()` cru, está fora do
baseline e passa `--strict` hoje.

**Como resolver:**

1. **Reproduza dentro da árvore.** Copie os arquivos reais para uma shadow tree preservando a
   estrutura de pacotes, e rode o checker com o `MYPYPATH`/`sys.path` apontando para a raiz de
   código do projeto. Se o erro **some**, a limitação não existe.
2. **Controle positivo obrigatório.** No mesmo harness, quebre algo de propósito (remova uma
   anotação de retorno) e confirme que o erro aparece. Um `Success` num harness mudo não prova nada.
3. **Procure o contra-exemplo no repo antes de concluir.** Se existe código em produção que faz
   exatamente o que o seu repro diz ser impossível, **o repro está errado — não o repo.** Um `grep`
   pelo padrão custa segundos e mata a hipótese.

**A regra geral:** *número* pode entrar num brief como estimativa declarada; **causa não pode**.
Causa entra com a medição junto, ou entra marcada como hipótese a medir. Causa não medida que chega
ao implementador vira comentário permanente — e comentário é a memória do projeto, lida por quem
não estava lá.

**Ver também:** `zero-so-vale-com-controle-positivo`,
`resolver/anotar-handler-fastapi-cria-response-model-e-muda-o-contrato`.
