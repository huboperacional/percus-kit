## Trava que cobre `UPDATE` e não cobre `DELETE` não é trava — apagar a linha apaga a evidência {#trava-que-cobre-update-e-nao-delete-nao-e-trava}

`tags: postgres, trigger, imutabilidade, BEFORE UPDATE, BEFORE DELETE, evidencia, idempotencia, estorno, dinheiro, garantia no banco, intencao, estado transitorio`

**O padrão:** um estado precisa ser irreversível porque dele depende uma decisão que gasta dinheiro
ou não se desfaz — "já pedimos o estorno", "já emitimos a nota", "já enviamos o lote". A garantia
vira `BEFORE UPDATE ... RAISE EXCEPTION` e todo mundo dorme tranquilo.

**O buraco:** `DELETE FROM tabela WHERE id = ...` passa sem erro nenhum. A linha some, e com ela o
carimbo que dizia "já fizemos isso". O sistema volta a achar que pode fazer de novo — e faz.

**Solução:** o par. `BEFORE DELETE` com a mesma condição do `BEFORE UPDATE`.

```sql
CREATE OR REPLACE FUNCTION x_nao_some() RETURNS trigger AS $$
BEGIN
  IF OLD.status IN ('em_curso','concluido') OR OLD.despachado_em IS NOT NULL THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: ...' USING ERRCODE = 'raise_exception';
  END IF;
  RETURN OLD;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER ... BEFORE DELETE ON tabela FOR EACH ROW EXECUTE FUNCTION x_nao_some();
```

🔑 **Duas extensões que se esquecem junto, e as duas apareceram no mesmo caso real:**

1. **O estado TRANSITÓRIO também é evidência.** Proteger só o estado final (`estornado`) deixa o
   intermediário (`estornando`) apagável e revertível por UPDATE — e é ele que registra "recebemos
   um dinheiro que não vamos entregar". Feche a transição: de `em_curso` só se sai para `concluido`.
2. **Prove os DOIS lados.** Um teste que só mostra "a linha protegida não some" não distingue "a
   regra pega o caso certo" de "a regra pega tudo". Prove também que a linha limpa continua
   apagável — senão a trava pode estar entupindo operação legítima e ninguém percebe.

⚠️ **Armadilha de teste:** ao endurecer a trava, as fixtures do próprio teste passam a esbarrar
nela (reciclar a mesma linha para o caso seguinte deixa de funcionar). Isso é a trava funcionando —
adapte o teste com linhas separadas, **não** abra exceção na regra.

**"Mas nada no código apaga essa tabela."** É o argumento a favor, não contra: a trava existe para o
caminho que ninguém escreveu ainda e para o `psql` de uma madrugada ruim. Se dependesse de o código
estar certo, ela não precisaria existir.

**Ref:** Salas Flex, 2026-08-21, migrations 023/024/025 e `db/tests/004_estorno_estado.sql`. O mesmo
raciocínio que a tabela `aceite` do projeto já seguia desde a 001 — e que o pagamento não seguia.
