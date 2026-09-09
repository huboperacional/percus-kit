## Spec antes da tela, senão o review não tem contra o quê comparar {#spec-antes-de-tela-senao-o-review-nao-tem-contra-o-que-comparar}

tags: processo, review, spec, ui

**Procedimento para:** construir tela ou relatório que alguém vai USAR (não protótipo descartável).

Medido em 2026-09-08 (Paid Media Automation, tela *Anúncios · Resumo*). A tela passou por **quatro
passadas adversariais** que acharam e fecharam seis defeitos reais de aritmética e moeda. Suíte
verde, `tsc` limpo, lint zerado, mutantes mortos. **O operador reprovou a tela inteira na primeira
vez que a abriu:** *"do que me interessa detalhamento do que não teve gasto do período… essa tela tá
uma merda"*.

### Por que os quatro reviews não pegaram

Não havia **spec escrita**. A tela nasceu de um princípio anotado no plano ("vira print pro cliente;
todo número é `number|null`"), e os reviews compararam o código **contra si mesmo**: consistência
interna, contradições, unidades. Nenhum comparou a tela **contra o pedido**, porque o pedido não
existia como artefato.

🔑 **Polir a aritmética de uma tela que responde à pergunta errada não a torna certa.** Um review só
pode reprovar contra uma referência; sem spec, a referência vira o próprio código.

### O procedimento

1. **Escreva a spec ANTES do primeiro componente** — mesmo curta. O mínimo útil: a pergunta que a
   tela responde, a ordem dos blocos, o que NÃO entra, e as definições que não podem ser adivinhadas.
2. **Todo requisito com gate declarado.** "RF-3: uma linha por conta" vale pouco; "o número de
   linhas é igual ao número de contas ativas" é verificável.
3. **Cite o pedido LITERAL do operador** entre aspas na spec. Paráfrase perde a restrição: *"tráfego
   e tabela abaixo"* e *"um resuminho tipo conta X — rodou na semana — rodou ontem"* decidem layout;
   "melhorar a visualização" não decide nada.
4. **Marque explicitamente a definição que você NÃO vai adivinhar** e pergunte. Na tela acima era o
   que conta como "rodou" — e o terceiro estado ("não medimos" ≠ "não rodou") era o coração da
   honestidade da tela.
5. **Se o pedido original existiu em conversa e não foi localizado, registre isso na spec.** Escrever
   "esta spec vem de duas frases, não do pedido completo — o que estava lá e não está aqui vai faltar
   de novo" é mais honesto que fingir cobertura.

### Quando o operador reprova, procure o defeito ANTES de reorganizar

A reclamação foi de layout ("detalhamento do que não teve gasto"), mas a causa era um **bug de
dado**: a tela concluía que não tinha medido nada e enchia a página com a ausência. Reorganizar sem
investigar teria produzido uma tela bonita que continuava mentindo.

**Sanfona em cima de frase falsa é polimento de mentira.** Quando o pedido for cosmético e você achar
um defeito de fato no caminho, o defeito vem primeiro — e diga isso a quem pediu.

Ver [[ausencia-de-medicao-envenena-numero-medido]] para a família de defeito que essa tela escondia.
