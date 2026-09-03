## Três jeitos de uma guarda produzir o mesmo verde {#tres-jeitos-de-uma-guarda-produzir-verde-falso}

`tags: guarda vazia, verde falso, harness, cobertura, deselected, addopts, marker postgres, sabotagem, review, teste que ninguem le`

**Sintoma:** a suíte está verde, a guarda existe, e o defeito está lá.

**As três formas estavam vivas no MESMO repositório, no MESMO dia** (Empresa Milionária,
2026-09-02), achadas por sessões diferentes:

1. **Guarda que roda e não mede.** O ataque 2 do harness de vazamento estava cego em **44 rotas
   de escrita**. A fixture montava as empresas **sem ativar módulo nenhum**, então
   `exigirRecursoAtivo` recusava com **403 antes** da guarda de tenant — e 403 satisfaz um assert
   de `4xx`. Provado removendo o filtro `empresa_id` de uma consulta e vendo o harness ficar
   **VERDE**.

2. **Guarda que mede e não roda.** `tests/pj/test_rls.py` compara `TABELAS_COM_TENANT` com o
   metadata e falharia. É marcada `postgres`, e o `pytest.ini` traz
   `addopts = -m "not schema_pf and not postgres"`. Rodar o arquivo devolve **"20 deselected"** —
   que na tela se parece o bastante com verde para quem procura vermelho.

3. **Guarda que roda, mede certo, e ninguém lê.** `tests/pj/test_rls_cobertura.py` — sem marca,
   suíte padrão — esteve **vermelha por três commits**, nomeando exatamente as quatro tabelas que
   faltavam em `TABELAS_COM_TENANT`.

**A terceira é a pior, e é a única sem conserto de código.** Nas duas primeiras há o que
arrumar: ligar o módulo na fixture, rodar com `-m postgres`. Na terceira **o teste está
perfeito** — o defeito está em quem não leu o vermelho.

**Como cada uma se detecta:**

- **Classe 1** — sabote o código que a guarda deveria pegar e confirme que ela fica vermelha. Se
  a sabotagem passa verde, a guarda mede outra coisa. Guarda que nunca falha é pior que nenhuma.
- **Classe 2** — leia a **contagem** da saída, não a cor. `20 deselected` ≠ `20 passed`.
- **Classe 3** — conte os vermelhos antes e depois. Um número que **não muda** quando você
  acrescenta tabela, rota ou campo é o sinal.

Ver também [[conte-os-vermelhos-guarda-que-passa-vazia]] (a variante aritmética, dentro de um
arquivo só) e [[o-recorte-de-teste-e-escrito-por-quem-despacha]] (como a classe 3 nasce quando se
delega).
