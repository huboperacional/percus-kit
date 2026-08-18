## Contar linha com `psql` num banco com RLS mede a POLÍTICA, não o dado — e "0 linhas" vira diagnóstico falso {#psql-sem-contexto-mede-rls-nao-o-dado}

tags: RLS, row level security, multi-tenant, psql, contagem de linhas, banco vazio, diagnostico falso, auditoria, SET LOCAL, set_config, current_setting, NULLIF, fail-closed, seed, producao, medicao enganosa

**Sintoma:** uma auditoria abre o banco de produção por `psql`, conta as linhas das tabelas
principais e encontra **0** nas que importam. A conclusão parece inevitável: o seed nunca rodou,
o ambiente está pela metade, o piloto está quebrado. Escreve-se um plano inteiro em cima disso.

**O que está acontecendo:** a política é fail-closed por desenho —

```sql
USING (usuario_id = NULLIF(current_setting('app.usuario_id', true), '')::uuid)
```

Com `FORCE` ligado e **sem** contexto na sessão, `current_setting(..., true)` devolve string
vazia, o `NULLIF` a transforma em `NULL`, a comparação nunca é verdadeira e **nenhuma linha
aparece**. O `psql` não está vendo o banco: está vendo o que a política libera para uma sessão
que não declarou quem é. Zero linhas é a resposta CORRETA da RLS — e é indistinguível de tabela
vazia.

**O tell que entrega o engano, e ele está na própria medição.** Se você tabelar as contagens,
repare em quais tabelas vieram com dado e quais vieram zeradas: as que aparecem são exatamente
as **sem** política por tenant (no caso de origem: `grupos`, `empresas`, `usuarios`,
`familias`), e as zeradas são exatamente as **com** (`papeis_*`, e tudo que tem `empresa_id`).
Uma tabela de contagens que separa perfeitamente "tem RLS" de "não tem RLS" não é um retrato do
banco — é um retrato do isolamento funcionando.

**Como medir de verdade** — qualquer um dos dois, e de preferência os dois:

```sql
-- 1. psql declarando o mesmo contexto que a aplicação declara
SET app.usuario_id = '<uuid do usuário>';
SET app.empresa_id = '<uuid do tenant>';
SELECT count(*) FROM papeis_empresa;
```

```bash
# 2. melhor ainda: pergunte pela PRÓPRIA aplicação, que já sabe aplicar o contexto.
#    Um seed idempotente é o instrumento ideal — ele responde "criei" ou "reaproveitei",
#    e "0 criados" é prova de que o dado já estava lá.
docker exec <container-da-api> python -m scripts.seed_piloto --<args>
```

O seed idempotente é a contraprova mais forte porque é **independente do seu SQL**: ele passa
pelo mesmo código de contexto que a aplicação usa. Se ele diz *0 criados, 16 reaproveitados*, o
dado existe — e ainda dá para conferir se o número fecha com a lista do que o seed cria.

**Regra que sai daqui, e ela generaliza:** cada camada de proteção cega um instrumento de
medição diferente. *Screenshot prova o que a tela mostra, não o que o banco tem. `psql` sem
contexto prova o que a RLS deixa ver, não o que está gravado. `curl` + `grep` provam que uma
string existe no HTML, não que alguém a enxerga.* Antes de escrever um plano em cima de uma
medição, pergunte **qual camada pode estar respondendo no lugar do dado**.

**Custo real quando passa batido:** no caso de origem, duas sessões inteiras trataram um piloto
saudável como quebrado. Uma "Entrega 0" foi especificada, revisada pelo conselho 3/3 e declarada
pré-requisito de todas as outras — para consertar um estado que não existia. O conserto correto
custou uma linha de `SET`.

⚠️ **Cuidado com a "cura" pior que a doença.** O caminho de auto-serviço que o produto oferecia
para o estado quebrado (onboarding cadastrando a empresa de novo) teria criado uma **segunda**
empresa com o mesmo CNPJ num grupo implícito novo — porque o índice único de CNPJ é *por grupo* —
deixando a original órfã. Quando o diagnóstico é "falta dado", confirme que ele falta **antes**
de deixar o produto recriá-lo.

**Ref:** Empresa Milionária, 2026-08-17 — refutação do achado D11 da auditoria de rumo de
2026-08-16 (`docs/2026-08-16-auditoria-de-rumo.md`). Entradas irmãs:
`#contexto-antes-da-tabela-que-decide-acesso`, `#rls-sem-force-dono-ignora-politica`,
`#refresh-apos-commit-perde-contexto-rls`.
