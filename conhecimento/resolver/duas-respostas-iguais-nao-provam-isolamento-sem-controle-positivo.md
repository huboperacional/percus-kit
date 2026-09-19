## Duas respostas iguais não provam isolamento: sem controle positivo, "404 em tudo" passa verde {#duas-respostas-iguais-nao-provam-isolamento-sem-controle-positivo}

`tags: rls, multi-tenant, 404 identico, controle positivo, teste que nao discrimina, postgres, papel, contexto de usuario, R23`

**Sintoma:** um teste de isolamento compara a resposta de "recurso da empresa vizinha" com a de
"recurso que não existe" e exige que sejam **idênticas** — o padrão certo, que impede a API de
distinguir "não é seu" de "não existe". O teste fica verde. E não prova nada.

**Por que ele pode passar sem medir isolamento:** se a montagem do teste não resolver o **papel do
usuário** (sessão da requisição sem o contexto que a aplicação aplica, tabela de papéis isolada por
usuário, recurso do módulo desligado, token de outra empresa), **toda** rota responde 404 — a
própria, a alheia e a inexistente. Duas respostas iguais é exatamente o que se obtém quando ninguém
acha coisa nenhuma. A asserção não discrimina entre "o isolamento funciona" e "a montagem está
quebrada", e as duas produzem o mesmo verde.

**Reprodução real** (Empresa Milionária, V2.3 Task 23, 18/09/2026): o arquivo de teste da janela
comparava, em 9 rotas, a resposta da entrega da vizinha com a de um id inexistente, sob RLS `FORCE`.
A sessão injetada por `dependency_overrides[getSession]` entregava sessão crua, sem o contexto de
usuário; o review cross-provider apontou que `papeis_empresa` é isolada por usuário e que, sem ele, o
404 viria da ausência de papel. Nenhum teste teria acusado.

**A correção que vale é o controle positivo, não adivinhar a fiação:** antes de comparar qualquer
404, o mesmo cliente, na mesma rota, pede o recurso **da própria empresa, que existe** — e ele
**não pode** dar 404. Se der, a montagem está quebrada e o resultado inteiro da corrida é inválido,
com a mensagem de falha dizendo isso em voz alta.

```python
# ⚠️ CONTROLE POSITIVO antes de qualquer comparação de 404.
propria = await cliente.get(f"{BASE}/{empresaA}/entregas/{entregaA}/eventos", headers=headers)
assert propria.status_code != 404, (
    "controle positivo falhou: a entrega da PRÓPRIA empresa respondeu 404 nesta montagem, então as "
    "comparações abaixo não medem isolamento — medem a ausência de papel/contexto")
```

**Vale para qualquer par "recusa igual":** 404 de tenant, 403 de alçada, 401 de sessão. Sempre que a
prova é *"as duas respostas são iguais"*, o teste precisa de um terceiro caso que **não** pode ser
igual — senão ele confunde "o sistema esconde certo" com "o sistema não achou nada".

Relacionado: [[psql-sem-contexto-mede-rls-nao-o-dado]], [[contagem-zero-sob-rls-force-nao-e-fato]],
[[404-por-design-esconde-tenancy]].
