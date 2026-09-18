## Teste escrito dentro de um plano antigo passa sem a implementação — 6 defeitos em 9 tarefas {#teste-escrito-em-plano-antigo-passa-sem-a-implementacao}

`tags: plano, writing-plans, TDD, teste vácuo, teste flaky, fixture, wiring, endpoint, controle positivo, SAVEPOINT, subagente, plano retomado, created_at, now(), EmailStr, MissingGreenlet, expire_all, R23`

**Sintoma:** você retoma um plano escrito dias antes, com os testes já escritos nos passos "Step 1:
Write the failing test", e manda executar tarefa por tarefa. Tudo fica verde. Medido em 17–18/09/2026
(Plexco Tasks, plano "Cliente × Projeto" de 04/09, 20 tarefas): **em 9 tarefas executadas, os testes do
plano estavam defeituosos 6 vezes**, cada vez de um jeito diferente — e nenhum dos seis teria dado
vermelho sozinho.

**Os seis jeitos (todos medidos, não hipotéticos):**

1. **Vácuo.** `type: 'select'` num formulário genérico caía no ramo `else` e virava `<Input>`; o
   `fireEvent.change` escrevia nele e o submit levava o valor. Verde sem o `<select>` existir. Só o
   `tsc` acusava — e o vitest não o enxerga.
2. **Flaky por construção.** Ordenava por `created_at` duas linhas criadas na mesma transação. No
   Postgres `now()` é o timestamp da **transação**: as duas empatam e o resultado é sorteio.
3. **Fixture que não monta o cenário.** A fixture criava organização **sem** projeto, então o caminho
   que o nome do teste prometia nunca rodava. Um deles passaria até com a chamada removida.
4. **Verde com zero wiring.** Testava só o serviço. A regra ficaria implementada, testada, verde — e
   contornável pela tela, porque o botão usa `PATCH` e o teste cobria o `DELETE`.
5. **Asserção que não morde.** Usava como entrada o valor default que o código já escolhe sozinho;
   a asserção passava com o campo do body ignorado.
6. **Bug de verdade no código do plano.** `flush()` sem SAVEPOINT: no Postgres uma violação de
   unicidade aborta a transação inteira, e a promessa "uma falha no lote não derruba as demais" era
   falsa — o próprio teste do plano teria dado erro, não o `ok is False` esperado.

**Causa:** quem escreveu o plano escreveu o teste **sem rodá-lo contra o código sem a
implementação**. Um teste que nunca foi visto vermelho não é prova de nada — ele só descreve a
intenção. E o plano envelhece: o código andou entre a escrita e a execução.

**Correção (vale para o executor e para quem despacha subagente):**
- Rode o teste do plano **antes** de implementar e confirme que ele falha **pelo motivo certo** — a
  mensagem de falha tem que apontar a ausência da implementação, não um erro qualquer.
- Todo filtro negativo precisa de **controle positivo no mesmo teste** (algo que TEM que aparecer),
  senão uma função que devolve vazio passa igual.
- Regra que vale num endpoint se testa **pelo endpoint**.
- Diga isso explicitamente no prompt do subagente — nesta rodada, os subagentes que receberam o
  aviso encontraram e reforçaram os testes fracos; sem o aviso, copiariam o plano.

**Armadilhas que só aparecem contra banco real** (subagente sem Postgres local não vê nenhuma):
e-mail `@exemplo.test` é recusado pelo `EmailStr` (TLD reservado — use `.com.br`); `db.expire_all()`
num helper de teste expira também o objeto de usuário que o override de autenticação devolve, e a
requisição seguinte morre com `MissingGreenlet`, longe da causa; `MagicMock` de entidade precisa ter
todo campo do `response_model`, e um campo novo no schema quebra o teste longe da mudança. Nesta
rodada, a suíte inteira contra banco real pegou 13 falhas que os subagentes não tinham como ver.

Relacionado: [review por task não pega bug do plano](review-por-task-nao-pega-bug-do-plano.md) ·
[premissa de plano também é medição](premissa-de-plano-tambem-e-medicao.md) ·
[zero só vale como prova com controle positivo](zero-so-vale-como-prova-com-controle-positivo.md)
