## Trava de cobertura no FIM confirma o migrado; semeada no INÍCIO ela revela o esquecido {#trava-de-cobertura-no-fim-confirma-no-inicio-revela}

`tags: trava mecanica, inventario, AST, shrink-only, migracao em lote, pre-mortem, cobertura, isencao verificada, teto por igualdade, refactor de seguranca`

**Contexto:** migração em lote de N sítios para um contrato único (enforcement de escopo, portão de
escrita, normalizador canônico — o padrão se repete). O plano nasce com uma **trava mecânica** que
reprova sítio novo fora do contrato. A pergunta que ninguém faz: **em que momento do plano ela entra?**

**O erro:** pôr a trava como última task, para "fechar" a migração. O pre-mortem do conselho matou
isso com uma frase que vale de regra:

> *"Se a trava roda por último, ela só confirma o que você migrou — não revela o que você esqueceu."*

**Por que importa mais do que parece:** a contagem manual do inventário **erra sempre**. No caso
medido ela foi de 5 → 12 → 28 → 44 conforme eu olhava melhor, e a varredura AST disse **43**. Nenhuma
das quatro estava certa. Uma trava no fim teria carimbado a última contagem errada como "cobertura".

**O que fazer:** semear a trava **antes das migrações**, com o inventário inteiro listado como
pendente e o teto alto. Cada task seguinte **remove** linhas e **baixa o teto na mesma edição**. O
teto vira o medidor de progresso, e o build reprova se você esquecer um sítio.

⚠️ **Teto por IGUALDADE (`== TETO`), nunca `<=`.** Com `<=`, encolher sem baixar o teto deixa folga do
tamanho exato de uma exceção nova — que entra em silêncio, com o teste verde.

**O segundo achado, tão útil quanto: nem todo sítio precisa migrar.** Dos 43, **14 saíram por isenção
VERIFICADA** e não por migração:

- os que já filtravam pelo dono do item (`usuarioId == usuario.id`) — item próprio é visível em todos
  os modos, então acrescentar o filtro de escopo **só removeria itens do próprio dono**: regressão,
  não proteção;
- os que só alcançam filhos de um agregado já resolvido sob a guarda certa (escopo transitivo).

▶ Isso **cancelou uma task inteira que o pre-mortem tinha pedido** ("função X vaza no modo Y"): o
vazamento já estava impedido por uma guarda em **outra** função. Medir antes evitou mexer em caminho
de escrita que funcionava.

⚠️ **Isenção só vale com teste que confere a PREMISSA dela.** Cada categoria de isenção ganhou um teste
que verifica no AST que a justificativa existe de verdade — inclusive a transitiva, que reprova se a
guarda sumir do resolvedor. *Isenção que ninguém confere é buraco com nome bonito.*

**Sinal de que você está no anti-padrão:** a lista de exceções da trava só cresce, ou você está
migrando um sítio "para o número baixar" sem saber que risco ele carrega.

Ver também: [detector que casa identificador por texto](detector-que-casa-identificador-por-texto.md).
