## Timer solto no mock atravessa a fronteira do teste e derruba OUTRO arquivo {#timer-solto-no-mock-atravessa-a-fronteira-do-teste}

`tags: teste flaky, vitest, setTimeout, mock de fetch, vazamento entre testes, testing-library, findBy, asyncUtilTimeout, suite paralela, forks, corrida`

**Contexto:** uma suíte de 170 arquivos passou a cair **~1 em 4 execuções**, sempre em **testes
diferentes** — e nunca ao rodar o arquivo suspeito sozinho (4/4 verdes isolado). O sintoma parecia
"a máquina está carregada".

**Causa raiz — foram DUAS, e só a segunda explicava a aleatoriedade:**

1. **O `findBy*`/`waitFor` do Testing Library tem timeout PRÓPRIO de 1s**, que `--testTimeout` não
   alcança. Sob carga o teste levava 1141ms e estourava. Isso explica falhas, mas não explica por
   que caía um teste diferente a cada vez.
2. 🔑 **Um `setTimeout` dentro do mock de `fetch`** (usado para simular resposta lenta) **resolvia
   DEPOIS do fim do teste**. O `chamadas.push(...)` do mock caía no teste **seguinte**, que
   `beforeEach` já havia zerado — deslocando asserções sobre número e ordem de chamadas, inclusive
   em testes escritos meses antes.

**Por que engana:** o teste que falha não tem relação com o que vazou. Quem investiga olha o teste
acusado, não acha nada, roda de novo, passa — e conclui "flaky, é o ambiente". O vazamento só
aparece se você perguntar *quem estava em voo quando este teste começou*.

**Como resolver:**
- **Nunca use `setTimeout` para "atrasar" um mock.** Use uma **promise controlada** (portão) que o
  próprio teste resolve: `let liberar; const portao = new Promise(r => { liberar = r; })`, e o mock
  faz `await portao`. Sem timer, não há nada para atravessar a fronteira.
- Espere o **efeito**, não a chamada: o `push` do mock acontece ANTES da resposta, então
  `waitFor(() => chamadas.some(...))` passa com a resposta ainda em voo. Espere o sinal que o
  usuário veria (ex.: o texto "Carregando…" sumir).
- Ajuste `configure({ asyncUtilTimeout })` **por último e com parcimônia** — folga alta mascara
  travamento real. Depois de matar o timer, 2s bastaram onde 5s pareciam necessários.

**Como confirmar que era isso:** rode o arquivo isolado N vezes (verde) e junto com a suíte (cai).
Se o isolado nunca cai, a causa está **fora** do arquivo acusado.

Relacionado: [[gate-que-nunca-foi-visto-reprovando-aprova-tudo]] · [[guarda-verde-porque-nao-mede-nada]].
