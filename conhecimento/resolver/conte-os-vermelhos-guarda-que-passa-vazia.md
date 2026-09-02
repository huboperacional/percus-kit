## Conte os vermelhos: o teste que passa ANTES de existir a coisa é guarda vazia {#conte-os-vermelhos-guarda-que-passa-vazia}

`tags: TDD, red green, guarda vacua, teste vazio, extra=forbid, 422, mensagem de dominio, contagem de falhas, sabotagem, is not None, assercao fraca, falso verde`

**Sintoma:** você escreve N testes para uma feature que ainda não existe, roda o vermelho, vê
"FAILED" na tela e implementa. Depois tudo fica verde. Só que **alguns daqueles testes nunca
falharam** — eles passavam desde antes, por um caminho que não tem nada a ver com o que você quis
guardar. Eles vão continuar verdes se a feature quebrar.

**O passo que falta é aritmético:** escreveu 5 casos? Então **5 têm de falhar**. Se 3 falham e 2
passam, os 2 são vazios — e "eu vi vermelho na tela" não distingue os dois grupos.

**Três formas que se repetem, todas medidas (Empresa Milionária, 2026-09-02):**

1. **Comparar com `None` sem exigir que não seja `None`.**
   `assert recursoNovo is not recursoAntigo` passa trivialmente enquanto `recursoNovo` é `None` —
   ou seja, **exatamente no cenário que o teste deveria acusar**. Conserto: `assert x is not None`
   nas duas pontas ANTES de compará-las.

2. **`extra="forbid"` respondendo pelo domínio.** Um corpo Pydantic com `extra="forbid"` devolve
   **422 citando o nome do campo** quando o campo ainda não existe no schema. Um teste que assere
   *"422 e o nome do campo aparece"* passa sem que exista validação nenhuma. Conserto: asserir a
   **mensagem de domínio** (`"outro cliente"`, `"não encontrado nesta empresa"`), não o status.

3. **O arquivo de teste registrando o que ele mesmo mede.** Um caso que confere se um modelo entrou
   no `Base.metadata` passa mesmo sem o import no `__init__.py`, porque os **outros** casos do
   mesmo arquivo importaram o módulo direto no topo. A guarda mediu o próprio import.

**Sabote antes de confiar, e confira o RECORTE.** Não basta o vermelho aparecer: veja **quantos** e
**quais**. Uma guarda boa fica vermelha no caso que ela cobre e **deixa os vizinhos verdes** — se
sabotar derruba metade da suíte, ela não é específica; se não derruba nada, ela não é guarda.

**Por que isto engana mais que o normal:** o TDD dá a sensação de rigor. Você *viu* o vermelho, e
essa lembrança vale por prova. A contagem é o único jeito barato de separar a lembrança do fato.

**Anti-sinal:** ao implementar, um teste que você escreveu "passou de primeira". Em TDD honesto
isso não acontece — ou o comportamento já existia (e o teste é sobre outra coisa), ou o teste está
vazio.
