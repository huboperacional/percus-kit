## Guarda que não emite evento: torne a fala PREVISÍVEL e preveja-a ANTES do disparo {#guarda-sem-evento-torne-a-fala-previsivel-e-preveja-a-antes}

`tags: prova em producao, turno real, quality_event ausente, funcao pura, assinatura unica, crc32, hash randomizado, baseline zero, ADR-0015, spec divergente do codigo, R23`

**Sintoma:** chegou a hora de provar a guarda em produção e **não há evento nem log para cruzar** — a spec prometia um, mas a implementação virou uma função pura que só devolve string. Sem instrumento, o turno real vira "a resposta pareceu certa", que não distingue *a guarda rodou* de *o LLM acertou por acaso*.


O `[5-T]` do ADR-0015 pede evidência que **distinga** *"a guarda rodou e agiu"* de *"nunca rodou"*.
O instrumento canônico é `quality_events` × log do container — mas **uma função pura que só devolve
string não emite nada**, e descobrir isso na hora da prova é comum: a spec do caso medido
**prometia** um evento na §8 e o código não tinha `recordEvent` nem log (`grep` no módulo inteiro,
zero ocorrências). A divergência spec × código atravessou 3 rodadas de conselho e 3 de review.

**O substituto que funciona, e é mais forte do que parece:**
- **Ache um token exclusivo do código** (um emoji, um wording) e **prove a exclusividade com `grep`
  na árvore inteira** — não no arquivo, na árvore.
- **Meça o baseline no banco**: quantas vezes esse token já apareceu em toda a história. Se for
  **ZERO**, você tem o "antes".
- 🔑 **Se a fala escolhe entre N variantes, prefira um seletor DETERMINÍSTICO e PREVEJA a saída.**
  No caso medido a variante vinha de `crc32(raw) % 3` — então a string exata foi **calculada antes
  do disparo** e conferida **byte a byte** depois. Um LLM não reproduz uma variante escolhida por
  `crc32` entre três, com a lista de opções e o rodapé no formato certo.
- Cruze com o log do container para nomear a **rota** (a linha do defer), mesmo que não haja linha
  da guarda em si.

⚠️ **`hash()` de str é randomizado por processo** — se o código usar `hash()` a fala muda entre
execuções e esta técnica não funciona (e todo teste de wording vira intermitente). `crc32`/`md5` são
estáveis. Isso é razão suficiente para preferi-los ao escrever a guarda, sabendo que ela vai
precisar ser provada em produção.

**Deixe registrado o que a prova NÃO cobre.** Um turno exercita um token e um ramo; os demais
continuam de bancada. E a ausência do evento continua sendo uma pendência real — sem ele **não há
como contar quantas vezes a guarda age em produção**, só provar que agiu uma vez.

**Irmãos:** [[prova-de-porta-fallback-morre-no-terreno-nao-no-tenant]] (como fazer a porta rodar,
antes de precisar provar que ela rodou) · [[funcao-que-responde-duas-perguntas-tem-status-load-bearing]] ·
[[fixture-que-mente-faz-a-mutacao-mentir-junto]] · [[golden-de-regressao-que-guarda-caminho-morto]]
