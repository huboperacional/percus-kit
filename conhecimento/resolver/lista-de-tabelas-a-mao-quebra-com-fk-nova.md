## Teste de infra cria/limpa o schema por LISTA escrita à mão — FK nova quebra os N testes de uma vez {#lista-de-tabelas-a-mao-quebra-com-fk-nova}

tags: create_all lista tabelas, UndefinedTable relation does not exist, fixture estoura todos os
testes, recorte de schema, drop_all lista, teste postgres setup error, FK aponta para fora da lista

**Sintoma:** um arquivo de teste que roda contra banco real passa a dar **E** (erro de setup, não
falha de asserção) em TODOS os seus testes, logo depois de alguém acrescentar uma tabela nova ao
domínio. A mensagem é `UndefinedTableError: relation "<tabela_nova>" does not exist` vindo de um
`create_all` — e a tabela nova nem é citada no arquivo de teste.

**Causa raiz:** a fixture cria (ou limpa) um **recorte** do schema a partir de uma tupla escrita à
mão — `TABELAS = ("grupos", "empresas", ...)`. Quando uma tabela DE DENTRO do recorte ganha FK para
uma tabela DE FORA dele, o `CREATE TABLE` referencia uma relação que a fixture não criou. Quem
escreveu a lista não tinha como saber; quem acrescentou a FK não sabia que a lista existia.

É a mesma classe do preparo que **limpa** por lista (`#preparo-limpa-so-o-que-conhece`, se houver):
lista escrita à mão só conhece o que conhecia no dia em que foi escrita, e o banco não perdoa.

**Solução — duas camadas:**

1. **Imediata:** acrescente a tabela nova à lista, com comentário dizendo POR QUE ela está lá
   (é alvo de FK de alguém do recorte), não só que está.
2. **Estrutural:** tudo que puder ser **derivado do metadata**, derive. No mesmo arquivo havia um
   conjunto `esperadas = {"fk_a", "fk_b", ...}` de constraints a conferir — trocado por uma
   compreensão sobre `Base.metadata`, com um `assert len(esperadas) >= N` para não passar
   trivialmente com conjunto vazio. **Isso não é auto-referencial:** o metadata diz o que o modelo
   QUER, o `pg_constraint` diz o que o banco ACEITOU, e o teste é a distância entre os dois.

**Como não descobrir isso tarde:** o recorte `postgres` costuma ficar fora da suíte padrão e rodar
só no fechamento. Ao acrescentar tabela ao domínio, `grep` pelos arquivos de teste que citam
tabelas por nome antes de considerar a task pronta.

**Ref:** Empresa Milionária, Fase B Task 6 (recorrência), 2026-08-14. `titulos` ganhou
`fk_titulo_recorrencia_empresa` e derrubou os 8 testes de `test_isolamento_fk_postgres.py` no
setup — a suíte padrão, com 300 testes do domínio, ficou verde o tempo todo.
