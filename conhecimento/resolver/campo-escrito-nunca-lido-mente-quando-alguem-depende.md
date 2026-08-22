## Campo escrito e nunca lido só mente quando o primeiro dado depende dele {#campo-escrito-nunca-lido-mente-quando-alguem-depende}

`tags: campo morto, codigo morto, invariante nao aplicada, falha fechada, gate por lista branca, gate por varredura, dead field, write-only field, R23, revisao de tipo`

**Contexto:** um tipo de domínio ganha um campo com semântica forte escrita na docstring — *"onde o
eixo vale; eixo sem nível declarado não vale em nenhum: falha fechada"* — e o campo é **preenchido**
por duas funções e **consultado por nenhuma**. Nada quebra. Testes verdes, produção correta, e a
frase da docstring passa a valer como se fosse comportamento.

**Causa raiz:** a invariante não estava implementada, só **declarada**. Ela ficou latente porque todo
dado existente satisfazia o caso trivial (todos os valores válidos em todos os contextos), então o
filtro que não existia teria dado o mesmo resultado do filtro que existisse. O defeito nasce no dia
em que entra o **primeiro dado restrito** — e aí ele é silencioso na direção pior: o sistema aplica
uma regra a um contexto que a declaração excluía.

**Como diagnosticar em 30 segundos:** `grep` o nome do campo em todo o `src/` fora de testes e dos
arquivos de tipo. Se **todas** as ocorrências forem atribuições (`campo: valor`), e nenhuma for
leitura (`.campo`, `includes(campo)`, `filter(...campo...)`), o campo é write-only. Um campo de
domínio sem leitor é ou uma fatia que falta, ou um campo que não deveria existir.

**Conserto (as duas metades):**

1. **Implementar a leitura**, com o default explícito e documentado. Se o parâmetro que ativa o
   filtro for opcional, escreva *por que* omitir não filtra — um default derivado muda o
   comportamento de todos os consumidores de uma vez e em silêncio.
2. **Gate de FONTE varrendo a árvore, nunca lista branca.** A primeira versão do gate costuma
   enumerar os chamadores que o autor conhece:

   ```
   const CONSUMIDORES = ["a.ts", "b.ts", "c.ts"];   // ❌ verde no dia em que nascer o 4º
   ```

   Trocar por uma varredura ("nenhum arquivo de produto chama `f()` com um argumento só") converte
   a lista em **invariante**. Na prática isso paga na hora: a varredura achou um 4º chamador que o
   autor não tinha visto e uma docstring desatualizada, no primeiro run.

**Armadilha da varredura:** ela lê texto, então casa dentro de **comentário e string**. Uma docstring
citando `f(config)` vira falso positivo. Tire comentários antes de casar — relaxar o regex para
"resolver" o falso positivo deixa a chamada de verdade escapar junto. E exija que a varredura tenha
encontrado **pelo menos uma** ocorrência: seletor vazio deixa a comparação vácua e o gate fica verde
provando nada.

**Sinal irmão:** o mesmo cheiro aparece em campo de RESULTADO que ninguém consome (`dono`, `origem`)
— menos grave, porque ninguém depende dele, mas vale registrar em vez de deixar crescer.

Relacionado: [[gate-que-le-estado-pos-mudanca-e-cego]], [[comentario-nao-e-gate]],
[[ganho-medido-no-nivel-errado-e-ganho-invisivel]].
