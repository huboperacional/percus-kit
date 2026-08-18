## Guarda MEDIDA funcionando fica INERTE quando o DADO muda de forma (ninguém tocou no código) {#guarda-inerte-por-mudanca-de-dado}

`tags: guarda inerte, guard silencioso, drift de dado, cardapio renomeado, variant_label, matcher por nome, protecao morta, medicao envelhece, camada mascarada, contra-prova na mesma rodada`

**Sintoma:** uma guarda de segurança aprovada por medição (com teste verde e docstring citando o
caso exato que ela protege) **não protege mais esse caso** — e a suíte inteira segue verde.

**Causa raiz:** o insumo da guarda é **DADO DE CADASTRO** (cardápio, zonas, aliases, catálogo), não
código. No caso real: a guarda perguntava *"este texto nomeia um item?"* via um matcher que casa
pelo campo `name`; o item foi **renomeado** de `Coca-Cola` para `Refrigerante - 600ml` com a marca
migrando pro campo `variant_label`. Nenhum commit tocou a guarda — ela simplesmente parou de casar.
As fixtures dos testes nomeiam o item do jeito que a guarda espera, então **nenhum teste observa a
dependência**.

**Agravante:** guarda em CAMADAS esconde a morte da camada 1. Ali a camada 2 era um contador com
teto 3 — o defeito só apareceria na 3ª tentativa do cliente, quando o dano (pausar o atendimento)
já é o pior possível.

**Solução:**
1. Guarda cujo insumo vem de cadastro **re-mede contra o dado REAL de produção**, não contra a
   medição que a aprovou. Rodar as funções de produção dentro do container, com o catálogo vivo.
2. **Contra-caso na MESMA rodada, sempre.** Foi `'refrigerante'` acertando (e `'coca'` falhando) que
   provou que o defeito era de IDENTIDADE (nome × variante), e não "a função quebrou".
3. Quando a mesma causa raiz reaparece pela **5ª vez** em pontos que não se conhecem, o defeito é do
   **modelo de dados**, não dos call sites — pare de remendar consumidor.
4. Ao consertar: **formatador não é matcher.** Reusar a função que monta o nome de EXIBIÇÃO como
   fonte de "o texto nomeia este item?" é erro de categoria e deixa o defeito vivo.

**Ref:** tiatendo, achado G6 (2026-08-16), `docs/PENDENCIAS.md` §2e. Instrumento:
`scripts/measureBairroStep.py`.
