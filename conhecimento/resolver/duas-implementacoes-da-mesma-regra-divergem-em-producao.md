## Duas implementações da mesma regra (SQL + filtro em memória) divergem em produção — e o teste de cada lado passa {#duas-implementacoes-da-mesma-regra-divergem-em-producao}

tags: regra duplicada, sql vs python, filtro pos-query, dashboard, contador divergente, paridade, medir em prod, plexco tasks, fonte unica, characterization test

**Sintoma:** dois lugares que deveriam mostrar o mesmo número mostram números diferentes — card do
dashboard 30, tela/lista 27, badge do menu outro valor ainda. Cada lado tem teste verde, porque cada
teste exercita a SUA implementação. A diferença é pequena (2 a 3 itens), o que faz parecer
arredondamento, cache ou atraso de replicação, e o bug sobrevive a várias sessões.

**Causa raiz:** o conceito ("tarefa que é minha", "cliente ativo", "pedido em aberto") foi
implementado DUAS vezes: uma em SQL (`WHERE`) e outra como filtro em memória depois da query. A
segunda camada costuma nascer de um requisito que o autor achou difícil em SQL (ordem, ranking,
"primeiro passo pendente"). Quem escreve a terceira superfície copia só a camada SQL — a mais fácil
de achar — e herda metade da regra, sem erro nenhum.

**Como detectar antes de shippar (o passo que fecha):** não compare implementações lendo código;
**rode as duas regras lado a lado contra o banco de PRODUÇÃO**, agrupado por usuário/entidade, e
olhe a coluna de diferença:

```sql
select nome, count(*) filter (where regra_a) a, count(*) filter (where regra_b) b,
       count(*) filter (where regra_a) - count(*) filter (where regra_b) diferenca
from ... group by 1 order by diferenca desc;
```

Diferença 0 em todas as linhas é prova; "li o código e parece igual" não é. No caso medido, 7 de 11
usuários davam 0 — uma amostra pequena teria "confirmado" a paridade.

**Conserto:** uma fonte só. Expresse a regra inteira no lugar mais baixo (SQL), apague a outra
camada e **prove a equivalência** com um teste que roda as duas leituras sobre o mesmo seed antes de
apagar. Depois de apagar, delete também o NOME da versão frouxa: um helper que sobra é o que a
próxima superfície vai importar. Se um consumidor esquecido usava o nome antigo, ele quebra no
import — barulhento, não silencioso.

**Cuidado ao mover filtro de memória para SQL:** confira se o filtro antigo rodava antes ou depois da
paginação. Depois da paginação, a contagem total já estava errada e o conserto muda números que
alguém pode ter tomado como corretos; antes, só muda o custo.

Medido em 2026-09-17 no Plexco Tasks: `GET /tasks/mine` filtrava por `is_mine_membership` (passo
atual/próximo) em Python, e a cláusula SQL nova cobria só "responsável da raiz ou de qualquer filha".
Card × tela: Vitória 30×27, Felipe 8×6, Gabryella 5×2, Vitória Braga 4×2, sete usuários em 0. Com a
regra inteira em SQL e a versão frouxa removida, os quatro fecham em 0.
