## Assert sobre um contêiner maior que o alvo passa vazio — e a contagem dos vermelhos NÃO pega {#assert-sobre-conteiner-maior-que-o-alvo-passa-vazio}

`tags: guarda vazia, assercao fraca, escopo do assert, substring, in vs igualdade, indexdef, WHERE parcial, numero esperado, numero observado, DID NOT RAISE, pre-condicao ausente, sabotagem, teste que nao mede, falso verde`

**Sintoma:** o teste **falhou** no vermelho, você implementou, ele ficou verde — e ele continua
verde depois de você sabotar a coisa que ele deveria guardar. É diferente do teste que passa antes
de a feature existir: aqui a contagem dos vermelhos estava **certa**, e a guarda é vazia mesmo
assim.

**Causa raiz — uma só, com muitas roupas:** o `assert` olhava um **contêiner maior** do que a coisa
a medir, e o contêiner tinha como satisfazê-lo sem o alvo estar correto.

Cinco ocorrências no mesmo arquivo em um dia (Empresa Milionária, gate da fatia 0 de produção,
2026-09-03):

| O que o assert olhava | O alvo real | Como passava sem medir |
|---|---|---|
| `count(*)` do **banco inteiro** | as linhas **do cenário** | uma empresa sem linha e a outra vendo o total satisfaz `sum <= total` |
| `INSERT … SELECT` filtrado pela empresa alheia | o `WITH CHECK` da policy | sob a própria policy a subquery traz **zero linhas**, nada é levantado → `DID NOT RAISE` |
| `predicado in indexdef` (a string toda) | a cláusula `WHERE` | `principal` casava dentro do **NOME** `uq_endereco_principal_por_pessoa` → passava com qualquer cláusula |
| status HTTP **por faixa** (`4xx`) | a guarda de tenant | outra guarda no caminho recusa antes com 403, que também é `4xx` |
| cenário sem a **pré-condição** | o filtro de categoria | a instalação estava concluída e sem data, então o cálculo do risco **nem rodava** |

**Por que a leitura não denuncia:** o assert aponta para o lugar certo. O defeito é o **tamanho do
recorte**, não a lógica — e um comentário que afirma a guarda (*"compara o PREDICADO, não só a
presença do WHERE"*) faz a linha ser lida como se cumprisse a promessa.

**Correção — três hábitos, na ordem de eficácia:**

1. **Recorte o alvo ANTES de comparar.** A cláusula, não o DDL: `_, _, clausula =
   ddl.lower().partition(" where ")`. A linha, não a query. O cenário, não o banco.
2. **Prefira igualdade a `in`, e número ESPERADO a número OBSERVADO.** Cenário próprio com
   *"cada empresa tem exatamente 1"* em vez de *"compare com o total do banco"* — números
   observados descrevem, números esperados medem.
3. **Sabote.** É o único jeito de distinguir as cinco linhas acima de guardas de verdade. Duas das
   cinco só apareceram ao sabotar; as outras três vieram de review externa.

⚠️ **Uma sexta variante merece nome próprio: pré-condição ausente.** O cenário não chega à linha
que você quer medir, então o alvo nunca é exercido. O sinal é a sabotagem **não derrubar nada** — e
a pergunta que resolve é *"este cenário chega até a linha que eu quero medir?"*, não *"o assert está
certo?"*.

**Corolário sobre a guarda que passa a EXIGIR o defeito:** no caso do RLS medido como superusuário,
o retrato veio invertido (tudo parecia vazar). Se alguém escrevesse a asserção **esperando o
resultado que viu**, o teste passaria a exigir o vazamento. Retrato invertido + assert sobre o
observado = guarda que protege o defeito.

**Ref:** Empresa Milionária, produção fatia 0 Task 9 + fatia 1 Task 4, 2026-09-03. Verbetes irmãos:
[[conte-os-vermelhos-guarda-que-passa-vazia]] (o caso em que a contagem PEGA),
[[mutacao-que-nao-casa-finge-que-o-gate-nao-reprova]] (quando a sabotagem não chega ao arquivo),
[[falsificacao-verde-porque-outra-camada-barrou]] (quando outra camada absorve o efeito).
