## Corrigir o instrumento antes do produto mede errado na direção oposta {#instrumento-de-avaliacao-adiantado-ao-produto}

`tags: harness, avaliacao, llm-as-judge, personas, fork, heranca, dominio, instrumento de medicao, benchmark, fase, migracao, guarda de dessincronia, wordswap`

**Origem:** Empresa Milionária, 2026-08-25 — cheguei para corrigir e a medição inverteu a
conclusão.

**Situação:** produto derivado de outro por fork. O harness que avalia o bot (personas +
prompt de juiz) descreve o **domínio antigo**: personas de pessoa física, rubrica falando de
"lançamento", juiz que se apresenta como avaliador de assistente *familiar*. O produto novo é
B2B. Parece defeito óbvio de herança, e a correção parece trivial.

**Por que corrigir seria pior:** o **backend também ainda é do domínio antigo**. Um harness
reescrito para o domínio novo passaria a cobrar comportamento que o produto não implementa — e
**reprovaria o bot por não fazer o que ele nunca prometeu**.

📌 **Instrumento à frente do produto não mede "melhor": mede errado na direção oposta.** E nota
ruim por motivo inventado é pior que nota nenhuma — ela some com o sinal real no meio do ruído,
e a primeira reação de quem lê é desconfiar do instrumento, não do produto.

⚠️ **O caminho mais tentador é o pior dos três:** trocar só a palavra do domínio nos prompts
(*"familiar"* → o termo novo). O harness deixa de casar com quem procura pelo nome **sem deixar
de simular uma dona de casa registrando mercado** — e agora com um verniz de "já foi corrigido",
que é o que impede alguém de olhar de novo.

**Solução: não corrija — trave a dessincronia.** Um teste que compara o domínio do instrumento
com o domínio do **backend**, reusando a mesma medição que outras guardas já fazem:

| backend | instrumento | veredito |
|---|---|---|
| antigo | antigo | ✅ coerente (estado de hoje) |
| **novo** | **antigo** | 🔴 **reprova** — reescreva os dois juntos |
| novo | novo | ✅ |
| antigo | novo | 🔴 reprova — *dessincronia inversa*, instrumento adiantado |

Os dois ramos vermelhos importam. O segundo é o que quase todo mundo esquece.

**Duas armadilhas na implementação, ambas medidas:**

1. **Guarda que só passa não prova nada.** Esta passa no estado atual, então a prova que vale é
   a segunda: force o outro estado (monkeypatch da função que mede o backend) e **veja o
   vermelho**. Sem isso você não sabe se escreveu uma guarda ou um `assert True`.
2. **A fronteira de palavra esconde o derivado.** `\bfamília\b` **não casa com "familiar"** — o
   detector acusou as personas e **nenhum dos dois prompts**, que é justamente onde a palavra
   aparecia. Reescrever as personas e deixar os prompts teria deixado tudo verde. Inclua as
   formas derivadas explicitamente.

Relacionado: [rotulo-casa-dentro-de-palavra](rotulo-casa-dentro-de-palavra.md) — a face oposta
da mesma fronteira, em que o rótulo casa **demais**.
