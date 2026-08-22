## `IF x <> 'esperado'` numa asserção de teste NÃO dispara quando `x` é NULL — e a prova passa sem provar {#assercao-de-teste-com-comparacao-nula-nao-dispara}

`tags: postgres, plpgsql, NULL, three-valued logic, IS DISTINCT FROM, teste vacuo, assercao, GET STACKED DIAGNOSTICS, constraint name, falso verde, invariante`

**Sintoma:** um teste afirma que a recusa veio da constraint certa —

```sql
GET STACKED DIAGNOSTICS nome = CONSTRAINT_NAME;
IF nome <> 'reserva_sem_sobreposicao' THEN RAISE EXCEPTION 'FALHOU'; END IF;
```

— e passa verde. Mas ele passaria verde **também** se `nome` viesse NULL, que é exatamente o caso
que a asserção existe para pegar: a exceção veio de outro lugar, ou de uma constraint sem nome.

**Causa raiz:** `NULL <> 'x'` é **UNKNOWN**, não TRUE. E `IF` em plpgsql executa o ramo só quando a
condição é TRUE — UNKNOWN cai no `ELSE` calado. A asserção não falha; ela simplesmente não acontece.

**Solução:** `IS DISTINCT FROM`, que trata NULL como valor e devolve TRUE.

```sql
IF nome IS DISTINCT FROM 'reserva_sem_sobreposicao' THEN RAISE EXCEPTION 'FALHOU: veio %', nome; END IF;
```

🔑 **A classe:** toda asserção escrita como negação (`<>`, `NOT IN`, `!=`) tem esse buraco em SQL, e
o buraco fica **exatamente no caso anômalo** — o valor ausente, que é o que a asserção deveria
denunciar. Em teste isso é pior que em código de produção: código errado quebra e aparece; asserção
que não dispara **certifica** o defeito.

⚠️ Note que a direção importa. Em `CHECK` de constraint o problema é o oposto e o
`IS DISTINCT FROM` **não** resolve — ver [#check-bicondicional-unknown](check-bicondicional-unknown.md).
Aqui, numa asserção `IF`, ele é exatamente a ferramenta certa.

**Como caçar:** `grep -nE 'IF +[a-z_]+ +(<>|!=) ' **/*.sql` nos arquivos de teste. Cada ocorrência é
suspeita até que se prove que o lado esquerdo nunca pode ser NULL.

**Ref:** Salas Flex, 2026-08-21, `db/tests/004_estorno_estado.sql`. Achado por review cross-provider
na mesma sessão em que outras duas provas nasceram vácuas — ver
[#teste-que-sai-com-erro-de-proposito-nao-distingue-morrer-de-terminar](teste-que-sai-com-erro-de-proposito-nao-distingue-morrer-de-terminar.md).
