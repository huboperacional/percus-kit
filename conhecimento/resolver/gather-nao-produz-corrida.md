## Teste de concorrência com `asyncio.gather` não produz corrida — e fica VERDE sem a constraint {#gather-nao-produz-corrida}

tags: teste de concorrencia, asyncio gather, race condition, constraint unica idempotencia,
teste passa sem a constraint, asyncio Barrier, corrida serializada

**Sintoma:** um teste que se chama "corrida" — N execuções do mesmo caso de uso via
`asyncio.gather`, contra banco real — passa. Depois você **derruba a constraint única** que ele
deveria estar exercitando, e ele **continua passando**.

**Causa raiz:** `gather` agenda corrotinas no mesmo event loop; ele **não garante intercalação**.
Na prática a primeira execução chega ao commit antes de a segunda fazer a leitura, a segunda
encontra o registro pela consulta comum e devolve "já existia". O caminho medido é o feliz, não a
corrida — e o caminho feliz não precisa de constraint nenhuma.

**Solução — sincronizar explicitamente no ponto anterior à escrita:**

```python
barreira = asyncio.Barrier(quantidade)
original = CasoDeUso._buscarExistente

async def buscaSincronizada(self, *a, **k):
    achado = await original(self, *a, **k)
    if not getattr(self, "_jaSincronizou", False):   # <- ver armadilha abaixo
        self._jaSincronizou = True
        await barreira.wait()
    return achado
```

Com isso as N leituras acontecem **antes** de qualquer INSERT, que é o instante que a constraint
existe para resolver: uma vence, as outras batem na violação e recuperam.

⚠️ **`asyncio.Barrier` é CÍCLICA.** Se o caso de uso chamar o método interceptado uma segunda vez
(a releitura da recuperação, por exemplo), a segunda espera fica aguardando participantes que já
terminaram e o teste **trava até o timeout** em vez de falhar. Marque no `self` que aquela
execução já sincronizou — cada execução tem sua própria instância.

**Ref:** Empresa Milionária, Fase B Task 6, 2026-08-14. Com a barreira e sem a constraint, o teste
passou a acusar `as duas execuções disseram [True, True]: ou as duas criaram (o dinheiro dobrou)`.
