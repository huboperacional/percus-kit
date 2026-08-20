## Timeline sai fora de ordem: o relógio empata e o desempate é UUID aleatório {#relogio-empata-e-o-desempate-por-uuid-sorteia-a-ordem}

`tags: timeline, auditoria, ordem, order_by, UUID4, UUIDv7, datetime.now, granularidade do relógio, monotônico, teste intermitente, flaky, SQLite, IDENTITY, SEQUENCE, SQLAlchemy, default de coluna, histórico imutável`

**Sintoma:** um teste de ordenação falha ~1 vez em 5, com a lista embaralhada de um jeito
diferente a cada rodada. Fora do teste, a mesma lista aparece em ordens diferentes a cada F5.

**Causa raiz, em duas metades — e as duas precisam ser verdade:**

1. **O relógio empata.** `datetime.now()` no Windows tem granularidade de **~1,1 ms** (medido:
   2000 chamadas seguidas devolveram **dois** valores distintos). Registros criados no mesmo laço,
   ou na mesma requisição, recebem o **mesmo** timestamp. No Linux a granularidade é de ~1 µs, o
   que torna o empate raro em produção e **garantido** na máquina de desenvolvimento — é por isso
   que o defeito parece "flakiness de teste".
2. **O desempate é aleatório.** `ORDER BY criado_em DESC, id DESC` com `id` **UUID4** produz uma
   ordem total *arbitrária*. Um comentário dizendo que o id "desempata para a ordem ser total"
   está tecnicamente certo e é irrelevante: ordem total ≠ ordem dos fatos.

**Como confirmar em 30 segundos** (antes de culpar a consulta, o cache ou o ORM):

```python
from datetime import datetime, timezone
vistos = {datetime.now(timezone.utc) for _ in range(2000)}
print(len(vistos))   # 2 = o relógio empata. Milhares = o problema é outro.
```

**Fixes, em ordem de força:**

| | Dá ordem total | Custa |
|---|---|---|
| Coluna de sequência no BANCO (`IDENTITY`/`SEQUENCE`) | entre processos | migration + backfill; **e ver a armadilha abaixo** |
| Carimbo monotônico no PROCESSO | dentro do processo | nada |
| UUIDv7 no lugar de UUID4 | sim, por construção | muda identidade de auditoria; não conserta linhas já gravadas |

⚠️ **A armadilha da coluna de sequência:** se a suíte roda contra **SQLite**, ela não existe.
SQLite não tem `IDENTITY` nem `SEQUENCE` para coluna que não seja chave primária, e o
`create_all` dos testes quebra. A alternativa "coluna com default do lado do Python" dá
**exatamente a mesma garantia** que o carimbo monotônico e ainda cobra a migration — ou seja,
paga-se o preço da opção forte e leva-se a fraca.

**O carimbo monotônico, e os três detalhes que importam:**

```python
_ultimoCarimbo: datetime | None = None
_trava = threading.Lock()

def utcNowEvento() -> datetime:
    global _ultimoCarimbo
    with _trava:
        agora = utcNow()                      # (1) global do módulo, não import direto
        if _ultimoCarimbo is not None and agora <= _ultimoCarimbo:
            agora = _ultimoCarimbo + timedelta(microseconds=1)   # (2) 1 µs, não menos
        _ultimoCarimbo = agora
        return agora
```

1. **Chame o relógio por global do módulo.** Só assim ele é congelável no teste. Com
   `from x import utcNow` em outro módulo, o `monkeypatch` não alcança o nome já importado.
2. **O passo é 1 µs** porque é a menor unidade que `timestamptz` do PostgreSQL guarda. Passo menor
   é arredondado no INSERT e o empate volta, agora gravado.
3. **`threading.Lock`, não `asyncio.Lock`**, quando isto for **default de coluna** do SQLAlchemy:
   default de coluna tem de ser chamável **síncrono**. Uma corrotina ali seria gravada como objeto,
   não como data.

**Os limites, que precisam ficar escritos** (senão o fix vira promessa falsa):
- A garantia é **por processo**. Com vários workers, dois registros no mesmo microssegundo vindos
  de processos diferentes voltam a empatar. Mantenha o desempate por `id` como último recurso —
  não para ordenar direito, mas para que o resíduo saia **igual em toda leitura**.
- **Se o relógio andar para trás** (NTP), os carimbos ficam presos em "anterior + 1 µs" até ele
  alcançar. É deliberado: a alternativa é um histórico que anda para trás, e histórico costuma ser
  imutável — não há como corrigir depois.

**Três armadilhas ao TESTAR isto, e todas produzem verde falso:**

1. **Congelar o relógio pode não congelar nada.** `monkeypatch.setattr(modulo, "utcNow", …)` não
   alcança um `from modulo import utcNow` feito em outro arquivo, e muito menos o *default da
   coluna*, que guarda a própria função. Prove o vermelho em **dois passos**: primeiro ligue uma
   versão passa-tudo à coluna e veja o defeito falhar; só então implemente.
2. **O carimbo é estado global e vaza entre TESTES.** O controle positivo que empurra o relógio
   para o futuro deixa o piso lá, e todo teste seguinte do mesmo processo grava com data futura —
   **sem nada ficar vermelho**, porque "estritamente crescente" vale a partir de qualquer piso. Uma
   fixture `autouse` no `conftest.py` raiz tem de zerar o piso antes e depois de cada teste.
3. **Pausas artificiais viram dívida no instante do conserto.** O `sleep(5ms)` que fazia o teste
   antigo passar modela o caso fácil; mantido depois do fix, ele esconde uma regressão no relógio
   novo exatamente no cenário que o fix endereça. Tire a pausa e escreva o teste do caso difícil
   com o relógio **parado**.

**Quantos registros no teste:** com 3, uma implementação quebrada acerta 1 vez em 6 e o teste fica
verde sozinho de vez em quando. Use 6 (720 permutações) e acertar por acaso deixa de ser risco.

**Onde apareceu:** Empresa Milionária, P22 — timeline de título (FR-034, retenção fiscal de 5
anos). Achado em 2026-08-19 medindo um teste intermitente; fechado em 2026-08-20.
