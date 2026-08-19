## Saída de comando morto no timeout não é resultado — cabeçalho sem conteúdo embaixo parece exatamente igual a "não há nada" {#saida-de-comando-morto-no-timeout-nao-e-resultado}

`tags: timeout, background, comando morto, saida parcial, resultado ausente, falso negativo, grep truncado, secao vazia, conclusao errada, evidencia incompleta, investigacao, custo, R23`

**Sintoma:** um comando longo estoura o timeout e é movido para background. Você lê o arquivo de
saída dele, vê a estrutura toda que esperava — inclusive o cabeçalho da última seção — e conclui a
partir do que está ali. A seção final aparece **vazia**, e você lê isso como **"a busca rodou e não
encontrou nada"**. Só que ela não rodou: o processo morreu antes de chegar lá.

**Causa raiz:** `echo "=== titulo ==="` e o comando que vem depois são operações **separadas**. O
cabeçalho é impresso imediatamente; o resultado leva minutos. Quando o processo é morto no meio, o
arquivo de saída fica com o cabeçalho e sem o corpo — e **essa forma é indistinguível, na tela, de
uma busca que terminou sem achados**. Não existe marcador visual entre "terminou vazio" e "não
chegou aqui".

🔑 **Ausência de resultado NÃO é resultado vazio.** São dois estados diferentes com a mesma
aparência, e o custo de confundi-los é assimétrico: "vazio" autoriza uma conclusão, "ausente" só
autoriza continuar procurando.

**Caso concreto, medido em 2026-08-19 (`percus-kit`):** investigando um gasto de API de $29,76 que
nenhum relatório interno explicava, rodei uma varredura por consumidores da chave fora do
ferramental. Ela estourou 120 s e foi pro background. Li a saída parcial, vi
`=== outros consumidores da chave fora do percus ===` **sem nada embaixo**, e **afirmei ao operador
que não havia nenhum**. Quando o comando terminou de verdade, a mesma seção listava **12 arquivos**
— inclusive código de aplicação chamando a API direto, com o modelo antigo e mais caro. A conclusão
que entreguei estava errada, e ela **redirecionou a investigação inteira** para o lugar errado.

**Por que passa despercebido justamente em investigação:** você está procurando uma explicação. Uma
seção vazia *confirma* uma hipótese ("o gasto está todo no lugar que eu já conheço") e some do
radar, porque confirmação não pede segunda olhada. Achado inesperado a gente confere; ausência
esperada a gente aceita.

**Solução:**

1. **Antes de concluir a partir de saída de comando em background, confirme que ele TERMINOU.**
   Notificação de conclusão, código de saída, ou um marcador final impresso pelo próprio script
   (`echo "--- FIM ---"` na última linha). Sem uma dessas três, o que você tem é um instantâneo, e
   instantâneo não é resposta.
2. **Termine todo script de varredura com um totalizador**, não só com a listagem:
   `echo "N resultados"`. Zero explícito é um dado; ausência de linhas não é.
3. **Nunca transforme seção vazia em afirmação negativa** ("não existe X") sem que a busca tenha
   comprovadamente rodado até o fim. Se precisa da negativa, re-rode com escopo menor até ela caber
   no tempo — negativa é a afirmação mais cara de sustentar, e a que mais gente aceita de graça.

⚠️ **O agravante do background:** o arquivo de saída existe, é legível e cresce — tudo indica um
artefato normal. Ele só vira resultado quando o processo morre de morte natural. Ler o arquivo é
barato e sempre funciona, e é essa facilidade que faz a conferência parecer desnecessária.

**Mesma família, camada acima:** [[alarme-falso-mata-o-alarme]] — a ferramenta responde, o resultado
parece legítimo, e o que falta é invisível. Ver também
[[marcador-otimizado-pro-hook-apaga-o-historico-do-medidor]], onde o dado que faltava também não
produzia erro nenhum: o arquivo tinha sempre exatamente uma linha, e ela era sempre a mais recente.

**Ref:** medido em 2026-08-19 no `percus-kit`, canon 6.41.0, investigando gasto da API DeepSeek.
A varredura completa (background, ~5 min) contradisse a parcial (~120 s) que eu havia tratado como
final.
