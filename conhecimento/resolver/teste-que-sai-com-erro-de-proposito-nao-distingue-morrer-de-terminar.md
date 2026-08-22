## Teste que termina em erro DE PROPÓSITO não distingue "passei" de "morri no meio" — e a suíte encolhe calada {#teste-que-sai-com-erro-de-proposito-nao-distingue-morrer-de-terminar}

`tags: teste, invariante, postgres, psql, ROLLBACK, RAISE EXCEPTION, fixture, chave estrangeira, suite encolhe, falso verde, exit code, DO block, teste vacuo`

**O padrão que causa isso** (e ele é bom, é por isso que se usa): um teste de invariante roda contra
o banco real dentro de um `DO $$ ... $$`, e a última linha é

```sql
RAISE EXCEPTION 'ROLLBACK_PROPOSITAL: % de 16 testes passaram', total;
```

O erro deliberado é o que desfaz as fixtures — permite rodar contra produção sem sujar nada.

**O defeito:** a saída de "passou tudo e reverteu" e a de "morreu no teste 6" são a mesma coisa —
um erro e um código de saída != 0. Quem roda vê vermelho nos dois casos, e o vermelho é esperado.

**Como apareceu:** uma migration deu chave estrangeira de verdade a uma coluna `cliente_id` que
antes era uuid solto. A fixture do teste continuou inserindo um uuid sorteado, e o teste passou a
morrer no T6 com `carteira_cliente_fk`. Por **um dia inteiro** o HANDOFF e o PLANO afirmaram "16
invariantes de banco, testes assertivos que falham alto se a regra sumir". Cinco rodavam. Onze não.

Não havia falso verde — havia **falso vermelho aceito**, que é pior: ninguém olha duas vezes para
um vermelho que já sabe que vai acontecer.

**Solução — o runner tem que distinguir os dois erros:**

```js
const rollbackDeTeste =
  alvoEhArquivoDeTeste &&              // resolva o caminho; startsWith mente com ../
  codigoDeSaida === 3 &&               // erro de script do psql, não outro
  saida.includes('ROLLBACK_PROPOSITAL') &&
  !saida.includes('FALHOU')
```

Os quatro juntos. Só a substring não basta: qualquer arquivo cuja saída contenha o token viraria ✓
verde depois de falhar pela metade. E o contador final (`% de 16`) tem que ser **lido**, não só
impresso — foi ele que sempre esteve certo e nunca foi conferido.

🔑 **Duas classes maiores:**

1. **Fixture de teste envelhece com o schema, e o teste não fala sobre ela.** Toda migration que
   aperta integridade (FK nova, NOT NULL, CHECK) pode matar fixtures antigas. Depois de apertar,
   rode as suítes e **conte os casos**, não só o resultado.
2. **Todo sinal de sucesso que se parece com o sinal de falha vai ser confundido.** Se o caminho
   feliz sai != 0, é obrigação do runner separar — senão a suíte encolhe sozinha e o relatório
   continua citando o número antigo.

**Parente:** [#alarme-falso-mata-o-alarme](alarme-falso-mata-o-alarme.md),
[#runner-de-teste-sai-zero-sem-rodar-nada](runner-de-teste-sai-zero-sem-rodar-nada.md),
[#seed-parcial-parece-sucesso-conte-as-linhas](seed-parcial-parece-sucesso-conte-as-linhas.md).

**Ref:** Salas Flex, 2026-08-21. `db/tests/002_invariantes_assertivo.sql`, `scripts/psql.mjs`.
