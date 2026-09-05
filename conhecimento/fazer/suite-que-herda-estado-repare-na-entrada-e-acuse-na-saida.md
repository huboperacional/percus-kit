## Suíte que herda estado: repare na ENTRADA e acuse na SAÍDA {#suite-que-herda-estado-repare-na-entrada-e-acuse-na-saida}

`tags: pytest, conftest, fixture, estado compartilhado, banco de teste, schema, ordem de coleta, teardown, guarda que nunca falha, atribuicao, vitima x culpado, sentinela`

**Quando usar:** uma suíte em que vários módulos compartilham um recurso mutável (schema de banco,
diretório, fila, container) e **alguns módulos apenas herdam** o estado que outro montou. O sintoma
é vermelho que muda com a ordem de coleta, e que aparece **no módulo errado**.

**O problema estrutural.** A correção da suíte passa a depender de uma invariante mantida por
convenção — *"quem sujar, limpe"*. Ela quebra sempre, e quebra em silêncio: quem suja termina
verde, e quem paga é o módulo **seguinte**, que não fez nada. Todo conserto por lista de culpados
conhecidos ("o módulo X agora remonta no teardown") só vale até aparecer o X+1 — e a busca pelo
X+1 é cara justamente porque o sintoma aponta para a vítima.

**O padrão que resolve, em duas metades que fazem coisas diferentes:**

- **ENTRADA — reparar.** Uma fixture de escopo de módulo compara o recurso com um retrato
  canônico e o **reconstrói** se divergir. Isso dá *imunidade*: nenhum módulo depende mais do que
  herdou, e a suíte deixa de depender da ordem.
- **SAÍDA — medir e registrar, sem reparar.** A mesma fixture compara de novo ao sair e anota
  quem saiu fora do retrato. Isso dá *atribuição*: a entrada só diz "o anterior sujou"; a saída
  diz **o nome**.

🔑 **Só a metade da SAÍDA reprova.** Reprovar pela entrada acusaria a vítima — é ela que encontra
o recurso quebrado. Registre a entrada para diagnóstico e faça a reprovação ler só as ofensas de
saída.

**Sem a segunda metade, o desenho vira tapete.** O reparo mantém a suíte verde para sempre, e a
partir daí ninguém descobre que um módulo suja o recurso — o conserto automático apaga o sintoma a
cada rodada. Por isso o par é obrigatório: **o reparo mantém a suíte correta, a sentinela a mantém
honesta.**

### Como montar

1. **Retrato auto-calibrado, não lista escrita à mão.** Construa o recurso do zero uma vez por
   sessão e congele o conjunto observado (nomes de tabela, de arquivo, de fila). Lista manual
   envelhece a cada item novo e passa a acusar divergência que não existe.
2. **A sentinela é um teste próprio, e precisa correr por último.** Prefixe o arquivo para ordenar
   no fim (`test_zz_…`) e **meça** que ele é o último na coleta — se correr antes, lê um registro
   incompleto e fica verde sem ter visto nada.
3. **Dispensa por marca declarada, para quem suja por desenho.** Existe módulo cujo critério de
   sucesso *é* deixar o recurso vazio (o que testa o próprio limpador, por exemplo). Marque-o.
   ⚠️ Isso **não** recria a lista de culpados: a lista antiga determinava a *detecção* — quem não
   estava nela escapava —, e esta determina só a *tolerância*: quem suja sem a marca é nomeado.
4. **Não descubra o escopo pelo nome do arquivo.** Enumere pela propriedade que importa (a marca,
   o import, a chamada). O módulo que testa o *manipulador* do recurso quase nunca segue a
   convenção de nome dos que o *usam* — e é o que mais suja.
5. **Ative por duas condições e prove as duas.** Recurso configurado **e** o módulo pertencer ao
   conjunto. Meça a inércia com a variável definida e apontando para lugar inalcançável: se a
   fixture acordar indevidamente, ela quebra ao conectar. E faça o **controle negativo** — um
   módulo do conjunto, mesma configuração, tem que reagir. Sem ele, "inerte" pode ser "nunca roda".

### Como provar que funciona

A/B mais **duas** sabotagens, e as duas são necessárias:

- **remova o reparo da entrada** → os vermelhos originais voltam. Prova que o reparo é o que
  sustenta a suíte;
- **faça um módulo QUE NUNCA FOI SUSPEITO sujar o recurso** → a sentinela tem de nomeá-lo, e dizer
  o que faltou. Prova que a atribuição é genérica, e não decorada para o culpado conhecido.

⚠️ Confirme **no disco** que cada sabotagem foi aplicada antes de acreditar no número. Sabotagem
que não pegou devolve o placar do código original, que é exatamente o resultado que se esperaria de
uma guarda inútil — ver `a-sabotagem-prova-o-que-voce-imaginou`. Em Windows isso morde duas vezes:
`sed` com âncora `$` não casa em arquivo CRLF, e o `cat -A` é o que mostra
(`crlf-mata-regex-git-bash`).

**Referência:** Empresa Milionária, 2026-09-04/05. 19 módulos marcados, 9 apenas herdando o schema;
a invariante por convenção quebrou quatro vezes em três semanas. O culpado final era o módulo que
testa o próprio apagador de schema — ele **asserta que sobraram 0 tabelas**, e nenhuma varredura
por `*_postgres.py` o alcançava. Depois do padrão: `102 passed / 3 skipped / 0 failed / 0 errors`,
contra `5 failed + 4 errors`; sem o reparo, `44 passed / 61 errors`; sujando outro módulo, a
sentinela devolveu `test_peca_postgres saiu com o schema fora do retrato: faltando ['chaves_pix']`.
