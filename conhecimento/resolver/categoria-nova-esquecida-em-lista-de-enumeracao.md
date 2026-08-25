## Categoria nova cadastrada, gravada, e invisível pro consumidor — porque uma lista de enumeração não foi atualizada {#categoria-nova-esquecida-em-lista-de-enumeracao}

`tags: enum incompleto, categoria nova, adapter, vocabulario, botao que mente, mock esconde bug, teste que bypassa o adapter, TDD, read-path vs write-path, drag reorder nao pode apagar dado`

**Contexto:** um sistema de vocabulário/categorias tinha 7 categorias funcionando havia meses. A 8ª
categoria (`lixo`, Fatia E Task 5 do Paid Media Automation) foi implementada, testada (547 testes
verdes), revisada por cross-provider, e declarada `[5-T]` em produção em três checkpoints seguidos.
Um smoke real contra dado de produção (marcar `[Ad]` como lixo, esperando que 210 criativos saíssem
da fila) mostrou que a categoria **nunca filtrava nada** — a escrita persistia no banco, a tela
confirmava sucesso, e a leitura seguinte não refletia a decisão.

**Causa raiz — dois defeitos INDEPENDENTES, da MESMA classe, um escondendo o outro:**

1. A função que converte o modelo de configuração (`NamingConfig`) pro modelo que o parser consome
   (`ResolvedPattern`) construía o dicionário de vocabulário **enumerando as 7 categorias antigas
   por nome**, uma linha de código por categoria. A 8ª categoria nunca foi adicionada a essa lista —
   não por editar a linha errada, mas por a lista **simplesmente não ter crescido** quando a
   categoria nasceu.
2. Corrigido o primeiro, o sintoma persistiu para o cliente que tinha OVERRIDE (não usava o padrão
   da casa direto). A função que UNE vocabulário da casa com o override do cliente também tinha uma
   lista própria de "todas as categorias", **também esquecendo a 8ª** — reconstruindo o objeto de
   saída inteiro a partir dessa lista, e descartando qualquer chave fora dela.

**Por que os 547 testes verdes não pegaram:** o teste da função final (o parser) construía o objeto
de entrada **na mão**, já com a 8ª categoria populada — nunca passando pelas duas funções-adapter
que a esqueciam. É a assinatura de `mock_mirrors_bug`: o teste prova que o CONSUMIDOR final funciona
com o dado certo, não que o CAMINHO até ele entrega o dado certo. Nenhum teste exercitava
"config gravado pela tela → as duas funções de conversão → parser", que era exatamente o caminho
quebrado.

**Como o smoke pegou o que a suíte não pegou:** consultando a API de leitura DEPOIS de aplicar a
mudança (`GET .../queue`), em vez de confiar no avanço visual da tela (que é otimista e avança de
cartão mesmo quando o `apply` não muda nada de verdade).

**Diagnóstico (a ordem que funciona quando "gravei e não fez efeito"):**
1. Confirmar que a escrita persistiu de verdade (ler direto da API/tabela que grava, não da tela).
2. Se persistiu e o efeito não aparece: `grep` por TODAS as listas de categorias/campos/enum que o
   sistema mantém (`grep -rn "categoria1.*categoria2.*categoria3"` pelos nomes já conhecidos) — a
   nova categoria provavelmente falta em uma OU MAIS delas, cada função de conversão tendo a sua
   própria cópia da lista.
3. Testar CADA função de conversão isoladamente com um fixture que passa pela nova categoria, não só
   o consumidor final.

**Corolário sério — dedup/limpeza no READ-PATH pode vazar pro WRITE-PATH:** ao corrigir o defeito
acima, uma versão do fix fez a função de LEITURA deduplicar entradas duplicadas exatas (dado legado
que uma versão antiga do sistema permitia). Como essa mesma função de leitura era reusada pela
operação de REORDENAR (arrastar um item = ler agrupado → mover → achatar de volta pra gravar),
arrastar um item — uma ação que o operador percebe como "só ordem" — silenciosamente **apagava**
a duplicata como efeito colateral. Reordenar não pode ter o efeito colateral de apagar dado que
ninguém pediu pra apagar; limpeza de dado legado, se for necessária, tem que viver numa migração ou
numa ação explícita, nunca dentro do caminho de leitura que uma ação neutra (mover, listar) também
usa pra gravar de volta.

**Fix:** adicionar a categoria faltante nas DUAS listas de enumeração, com teste que reproduz o
sintoma exato do smoke (config com a categoria populada → passa pela função de conversão → categoria
aparece no objeto de saída) antes do fix — não só um teste do consumidor final. Reversão do dedup
indevido: função de leitura nunca apaga dado; colisão de identidade (ex. key do React) se resolve no
RENDER com um índice, não descartando entradas na leitura.

**Ref:** Paid Media Automation, sessão TAGS & TEMAS 2026-08-25 — `web/src/lib/naming/naming-config-adapter.ts`
(`namingConfigToResolvedPattern`) e `web/src/lib/naming/uniao-casa-override.ts` (`unirVocabularioDaCasa`),
commits `b6a73f07` e `e0b25a9a`. A feature (Fatia E Task 5, "Lixo") tinha sido declarada `[5-T]` em
produção por três sessões seguidas antes do smoke que a derrubou.
