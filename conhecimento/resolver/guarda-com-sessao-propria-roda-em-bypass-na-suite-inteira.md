## Guarda fail-open com sessão própria roda em bypass na suíte inteira, e o estado dela vaza entre testes {#guarda-com-sessao-propria-roda-em-bypass-na-suite-inteira}

`tags: fail-open, guarda, sessao propria, AsyncSessionLocal, conftest, fixture autouse, estado de modulo, xdist, flaky, teste vacuo, R23`

**Sintoma:** você liga uma guarda num caminho por onde **toda** a aplicação passa (um facade de envio,
um middleware). A suíte continua verde. Meses depois, testes de outras áreas começam a falhar de
forma irreproduzível — e passam quando rodados isolados.

**Causa raiz:** duas coisas que só existem juntas.

1. A guarda abre **sessão própria** (`AsyncSessionLocal` global) em vez de receber a do chamador — o
   desenho certo, para o registro dela não morrer num rollback de negócio. Só que em teste o engine
   **de produção** costuma apontar para um banco que não é o de teste (na suíte medida, um
   `sqlite+aiosqlite://` em memória, **vazio e sem tabelas**, separado do engine da suíte). Toda
   consulta da guarda estoura, e o **fail-open** deixa passar. A guarda roda, em todo teste, no seu
   modo mais estranho — e o verde não diz nada.
2. O bypass costuma ter **estado de processo** (teto em memória, contador de alarme). Esse estado
   **não zera entre testes**: ele atravessa arquivos dentro do mesmo worker.

**Medido na Família Milionária (2026-09-18):** um teste-sonda com 25 envios ao mesmo número, sem
fixture nenhuma, mostrou os envios **bloqueados a partir do 21º** pelo teto em memória do bypass, e um
**alarme ao operador** capturado no mesmo balde de envios do teste. Nenhum teste da área tinha relação
com a guarda. A suíte passava por sorte da distribuição do `xdist`.

**O sinal que denuncia:** o implementador precisa de uma fixture de redirecionamento nos testes
**novos** "senão o bypass mascara o cenário". Se o teste novo precisa, **todo o resto da suíte está
sem** — e rodando em bypass.

### O que fazer, na mesma tarefa que liga a guarda

- **Fixture autouse no `conftest.py`** que **desliga a guarda por padrão** em toda a suíte (irmã da
  fixture que já fixa outros kill-switches) e **zera o estado de processo** antes de cada teste.
- **Fixture opt-in** que liga a guarda **e** redireciona a sessão global para o banco de teste; os
  arquivos que testam a guarda a pedem (um `autouse` local por arquivo evita repetir na assinatura).
- **Teste que prova a fixture**: N envios acima do teto sem a guarda ligada ⇒ todos saem e **nenhum**
  alarme é capturado. Sem ele, o dia em que a fixture sumir ninguém percebe.
- **Uma medição, uma vez:** rode a suíte inteira com a guarda **ligada de verdade** e relate — sem
  consertar nada — quais testes tropeçam. É o dado que diz se a regra tem falso positivo no
  comportamento real do produto. (Na medição citada: zero em 4128 testes.)

### Por que não deixar ligada em toda a suíte

Seria mais fiel, mas muda a semântica de milhares de testes de uma vez e vira projeto de descoberta
dentro da tarefa errada. Desligada por padrão + ligada explicitamente onde se testa a guarda + a
medição única acima entrega a mesma informação sem parar a frente.

Relacionado: [[fail-open-esconde-teste-vacuo]] (mesmo fail-open, outro mecanismo: lá o teste fica
vácuo; aqui a guarda inteira roda em modo bypass),
[[replay-que-roda-a-logica-real-dispara-o-efeito-colateral-real]].
