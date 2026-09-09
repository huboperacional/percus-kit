## Mover uma guarda tem DUAS metades: cedo demais ela corta os escapes, tarde demais ela abre o que vinha depois {#guarda-que-vira-ultimo-recurso-abre-o-que-vinha-depois}

`tags: guarda, posicao, ordem de avaliacao, retorno cedo, early return, ultimo recurso, caminho alternativo, escape, fail-closed, mutacao de posicao, alcance, R23`

**Sintoma:** uma guarda correta é acusada de "cortar o caminho alternativo"; você a move para o fim
do fluxo; a suite fica verde; e a passada seguinte de review acha **defeitos novos**, criados
justamente pelos caminhos que agora a alcançam.

**Forma abstrata.** Guarda que **retorna cedo** decide o turno antes dos tratadores que ela não
substitui. Guarda que apenas **arma** o desfecho e deixa o turno seguir passa a ser precedida por
todos eles — e cada um pode fazer o que a guarda existia pra impedir. As duas posições têm custo,
e **as duas metades precisam ser medidas contra o baseline**, não argumentadas.

**Caso medido (tiatendo, N23/`074`, 2026-08-31), as duas metades na mesma frente:**

- **Cedo demais.** A guarda fail-closed devolvia a resposta na hora e rodava **acima** de três
  tratadores 60-130 linhas abaixo (resolver de pagamento, escape de endereço, escape de item).
  Medido: `"não, quero uma feijoada"` perdia o item novo; `"sim, mas não é na rua X, é na rua Y
  120"` perdia a correção de endereço. Ver [#guard-sem-caminho-alternativo].
- **Tarde demais.** Virada "último recurso", ela zerava o resultado do matcher determinístico — e
  **isso empurrou a frase pro resolver por LLM**, cujo flag estava LIGADO no tenant vivo. Ele
  *escolhia* a opção que o cliente se recusou a escolher, micro-confirmava, e o turno seguinte
  fechava a transação **sem o item** — exatamente o defeito que a frente existia pra consertar,
  de volta em dois turnos. Cobertura zero: nenhum teste cruzava aquele flag com aquela pendência.

**Procedimento.** Ao mover uma guarda de posição, **enumere os dois lados**: (a) o que ela deixa de
cortar, (b) o que passa a alcançá-la. Um teste por caminho, e um **mutante da POSIÇÃO** (a guarda
volta a retornar cedo).

🚩 **O mutante de posição sobrevive se o assert não distinguir QUEM atendeu o turno.** No caso
medido, o helper de asserção aceitava a fala da guarda **ou** a do escape — então a mudança
estrutural inteira ficou sem contra-prova. O discriminante que funcionou foi um dado que **só um
dos dois emite** (ali, o preço do item).

**Ref:** tiatendo, N23, 2026-08-31, commit `5594de9`. Irmãos: [#guard-sem-caminho-alternativo],
[#mutacao-sobrevivente-pode-acusar-codigo-morto], [#alvo-de-mutacao-pode-nascer-podre]. R23.
