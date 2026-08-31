## Anotar uma SEGUNDA população numa árvore construída a partir da PRIMEIRA perde gente calado — quem anota também tem de CRIAR o nó que falta {#anotar-segunda-populacao-numa-arvore-da-primeira-perde-gente}

`tags: arvore, populacao, agregacao, funil, drill-down, ausencia, silencioso, contagem, DRE, relatorio, R23`

**Sintoma:** um degrau novo do relatório (leads, reuniões, visitas…) sai com número MENOR que o
total real, e nada falha. As somas internas até fecham — `Σ filhos == pai` continua valendo —, então
o defeito passa por todos os testes de invariante. O que não fecha é com a realidade, e ninguém tem
como saber.

**Causa raiz:** a árvore foi construída a partir de UMA população (no caso medido: os NEGÓCIOS
ganhos) e você está anotando OUTRA em cima dela (os CONTATOS criados na janela). As duas não têm as
mesmas chaves. Uma campanha que gerou 40 leads e nenhuma venda **simplesmente não tem nó** — e um
laço que só faz `no["leadsCount"] += 1` sobre nós existentes descarta esses 40 sem erro nenhum.

Pior: é exatamente o caso que o degrau existe para mostrar. O funil serve para expor QUEDA entre
etapas; a campanha que traz gente e não vende é o achado, e é justo ela que some.

**Correção:** a função que anota também **cria** o nó ausente, e o nó criado nasce com o dinheiro em
BRANCO, não em zero:

```python
fonte = fonte_por_source.get(source)
if fonte is None:                      # a população nova trouxe uma Fonte que a árvore não tem
    fonte = _fonte_so_com_lead(source) # nasce com venda ZERADA e spend* = None
    fontes.append(fonte)
    fonte_por_source[source] = fonte
fonte["leadsCount"] += 1
```

- `spend = None`, nunca `0.0`: o gasto dessa campanha já está no `não identificado` do pai (ela não
  casou negócio nenhum). Repeti-lo conta o mesmo dinheiro duas vezes; escrever `0.0` afirma que foi
  de graça.
- `leadsCount = 0` **é** zero de verdade — contagem de população presente. `None` fica reservado
  para razão sem denominador.

**O gate que pega:** não é a invariante de soma (ela vale nos dois mundos). É

```python
assert sum(f["leadsCount"] for f in fontes) == len(registros_da_populacao_nova)
```

*nenhum item é descartado calado.* Foi o único teste que reprovou com a versão "só anota".

**Duas armadilhas vizinhas, ambas medidas:**

1. **Ordem importa.** Se a criação de nós rodar ANTES da rotina que emite as linhas de "plataforma
   que gastou e não vendeu", a Fonte recém-criada marca a plataforma como *atribuída* e a linha do
   GASTO some da tabela — o dinheiro desaparece para que o lead apareça. Anote depois.
2. **Nó criado depois da passada de zeragem não passa por ela.** Se o laço começa com um
   `for no in arvore: no["campoNovo"] = None`, os nós criados no laço seguinte nascem SEM a chave. O
   payload sai com uns `campoNovo: null` e outros sem o campo — contrato desigual que só aparece em
   produção, num nó que existe *só* por causa da população nova. O construtor tem de declarar a
   chave.

Parente de [[agregado-nao-e-componente]] e de [[medicao-uniforme-na-populacao-inteira-e-bug-da-medicao]]:
os três são a mesma família — **duas populações no mesmo objeto, tratadas como se fossem uma.**
