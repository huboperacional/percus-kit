## Guarda de ordem sobre um PAR fica verde quando o defeito é um terceiro participante {#guarda-de-ordem-sobre-par-nao-ve-o-terceiro}

`tags: guarda de ordem, assert de sequencia, teste que nao morde, cobertura aparente, terceiro participante, RLS, contexto de tenant, no-op, guarda estatica, AST, registro canonico, lista escrita a mao, R23`

**Sintoma.** Existe um teste de sequência, ele é citado como prova de que a ordem está coberta, e ele **passa verde com o defeito no lugar**. Quem lê "existe teste de sequência" conclui que a ordem está protegida — e a conclusão é maior que a asserção.

**Causa raiz.** A guarda asserta a ordem de um **par** (`assert ordem == ["A", "B"]`) e não diz nada sobre um **terceiro** participante que corre antes dos dois. Ela foi escrita contra o modo de falha que já tinha acontecido — inverter A e B. Um modo de falha novo, com A e B na ordem certa e algo mais na frente, passa por baixo.

**Caso medido (2026-09-07).** `RegistrarEmpresa.executar` tinha `test_o_contexto_do_usuario_vem_antes_do_contexto_da_empresa`, assertando a sequência entre as duas chamadas de contexto de RLS. As duas de fato estavam nessa ordem. O defeito era a **leitura** — `_grupoDoUsuario()` consultando `papeis_grupo` (`FORCE ROW LEVEL SECURITY` por `usuario_id`) **antes das duas**: sem contexto, `current_setting` devolve `''`, o `NULLIF` devolve `NULL`, e `usuario_id = NULL` não é verdadeiro para linha nenhuma. A busca enxergava **zero** com a linha lá. 14 `POST` criaram **14 grupos distintos**, a cota nunca recusou e a visão consolidada nasceu vazia — com a guarda verde o tempo todo.

**Conserto.**

1. **Ao ver uma guarda de ordem, pergunte quem MAIS participa dessa ordem e não está na asserção.** O alvo certo raramente é o par: é *"nada que dependa de X corre antes de X"*.
2. **Derive os participantes de um registro canônico**, nunca de lista escrita à mão. No caso, a lista de métodos saiu de `TABELAS_ISOLADAS_POR_USUARIO` + `TABELAS_POR_USUARIO_OU_PAPEL_PROVADO` pelo `__tablename__` do modelo — então método novo que consulte a tabela entra no alcance **sozinho**. Lista à mão envelhece: a docstring de `marcarPapelProvado` no mesmo projeto já tinha envelhecido duas vezes.
3. **Escolha a forma pelo AMBIENTE, não pelo gosto.** Ali a guarda tinha de ser **estática (AST)**: `aplicarContextoDoUsuario` é *no-op* fora do PostgreSQL, então guarda de comportamento fica verde em SQLite **nos dois caminhos** — a certa e a errada. Quem "melhorar" a guarda transformando-a em teste de comportamento a estará **desligando**.

**Como saber que a guarda nova morde.** Ela tem de ficar **vermelha** no código original antes de o conserto entrar. Se ela já nasce verde, ou o defeito não é o que você pensa, ou ela não alcança o defeito.

Ver também [[controle-positivo-que-nao-atravessa-o-ponto-fragil]] — mesma família: o instrumento prova o que exercita, e só isso.
