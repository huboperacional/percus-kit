## Parser de dinheiro assume um idioma e lê mil vezes menos — `1.500` vira R$ 1,50 {#parser-de-dinheiro-assume-locale}

tags: dinheiro, locale, separador decimal, separador de milhar, intl, numberformat, pt-BR, en-US, parser, centavos, ordem de grandeza

**Sintoma.** Campo de valor aceita o que o usuário digita e grava outro número. Não é
arredondamento: é ordem de grandeza. `1.500` entra como `1,50`, `12.480` como `12,48`. O
formulário não acusa nada, o backend recebe um `Decimal` válido, e o erro só aparece quando
alguém confere o total contra o boleto.

**Causa.** `.` e `,` **trocam de papel entre idiomas**. Em `pt-BR` e `es-ES` o ponto é
separador de milhar e a vírgula é decimal; em `en-US` é o inverso. Um parser escrito para um
dos dois lê o outro errado por um fator de 1000. E há um segundo nível: mesmo dentro de um
idioma, quando **só um** separador aparece a string é ambígua — `12.480` é doze mil e
quatrocentos e oitenta, mas `12.48` é doze e quarenta e oito, e os dois têm o mesmo formato.

**Como aparece (Empresa Milionária, 2026-08-15).** A tela de cadastro de título nasceu com
`emCentavos` assumindo `pt-BR`: sem vírgula, tratava o ponto como decimal. O placeholder do
campo era justamente `12.480,00`, então digitar `12.480` — o mesmo número sem os centavos —
gravava R$ 12,48. Achado por review cross-provider, não por teste: o frontend não tinha
runner unitário.

**Conserto, em duas partes.**

1. **Pergunte os separadores ao `Intl`, não os escreva à mão.**
   ```js
   const p = new Intl.NumberFormat(locale).formatToParts(12345.6)
   const decimal = p.find(x => x.type === 'decimal').value
   const milhar  = p.find(x => x.type === 'group').value
   ```
   Tabela escrita à mão cobre os idiomas que você lembrou e erra no primeiro que não. `fr-FR`
   usa espaço estreito (U+202F) no milhar, e nenhuma lista de três idiomas prevê isso.

2. **Desfaça a ambiguidade por AGRUPAMENTO, não por idioma.** Quando só o separador que não
   é o decimal do locale aparece: se todos os grupos depois do primeiro têm **exatamente três
   dígitos**, é milhar; senão, é alguém digitando o decimal com a tecla do teclado numérico.

**Devolva a leitura em voz alta.** Sob o campo, mostre o valor interpretado
("entendido como R$ 12.480,00"). É a defesa que funciona mesmo quando o parser erra, e custa
uma linha — num campo de dinheiro, ver o que o sistema entendeu antes de salvar vale mais que
qualquer heurística.

**A decisão de arquitetura que veio junto: moeda e locale são EIXOS INDEPENDENTES.** A
tentação é derivar um do outro (`pt-BR` → BRL) e ela está errada: exportadora brasileira que
fatura em dólar existe, e é o caso comum de quem pede o recurso. Guarde os dois campos,
separados, na entidade que os possui — no caso, a empresa, porque moeda é propriedade da
entidade legal e não preferência de quem está logado. Teste que prova a independência tem que
usar um par **cruzado** (`moeda=USD`, `locale=pt-BR`): com o par default nos dois lados, uma
implementação que inferisse passaria em tudo.

**Formate com `style: 'currency'`, nunca concatenando o símbolo.** A posição é do locale: em
`pt-BR` sai `R$ 12.480,00`, em `es-ES` sai `12.480,00 €` — símbolo depois. `"R$ " + numero`
funciona até o dia em que a moeda muda, e aí imprime duas moedas na mesma linha.
