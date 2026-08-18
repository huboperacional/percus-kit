## Corpus adversarial que VOCÊ escreve não substitui replay sobre tráfego real {#corpus-escrito-nao-substitui-replay-real}

tags: teste, corpus adversarial, replay, trafego real, mutation test, falso negativo, ponto cego do autor, denominador honesto, guarda de escrita

**Sintoma.** A suíte cobre todos os casos que a spec listou, o mutation-test derruba os testes ao
desligar a regra, e mesmo assim o sistema autoriza em produção exatamente a operação que ele foi
construído para impedir.

**Como aparece (Família Milionária, 2026-08-15).** Um portão de escrita financeira tinha 15 casos
adversariais cobertos pelo pipeline real, todos verdes. O replay sobre `whatsapp_logs` — as
mensagens que usuários REAIS mandaram — mostrou o portão devolvendo `APLICAR` para
*"mas eu ja paguei a parcela do fone desse mês, a próxima agora é só em setembro"*, escrevendo na
parcela **futura** que a própria frase diz que ainda não foi paga. Era a segunda escrita do
incidente que originou o portão.

**Causa.** A frase tem DUAS orações: uma afirma um pagamento, a outra fala do que ainda vai vencer.
O extrator de mês varria a frase inteira e capturava o mês da oração que **nega** o pagamento. Como
a regra "mês nomeado escolhe a ocorrência" tinha precedência sobre "só sobrou futuro: nunca aplica",
o mês citado furava justamente a regra que existia para barrar aquilo.

**Conserto.** O período que ESCOLHE o alvo tem de ser dito na mesma oração do verbo de pagamento
(dividir por pontuação, ficar com as orações que têm o verbo). Sem verbo na frase, vale o texto
inteiro — respostas de menu ("1", "todas") não têm verbo, e exigir um quebraria esse caminho.

**A lição, que é maior que o bug.** Corpus adversarial escrito pelo próprio autor da regra herda os
pontos cegos do autor: eu jamais teria inventado uma frase com duas orações em que a segunda contém
um mês que não é o do pagamento. Linguagem real produz construções que a imaginação de quem escreve
o teste não gera. **Replay sobre tráfego gravado não é cerimônia de aceite — é a única fonte de
casos que você não pensou.** Rode antes do deploy, chamando a FUNÇÃO DE PRODUÇÃO (nunca uma cópia da
regra: replay que reimplementa a política mede um mundo que não existe), e realimente o corpus com
todo achado antes de subir.

**Ressalva obrigatória no relatório.** Reporte o denominador honesto. "Zero falso positivo" sobre
13 mensagens das quais só 3 exercitam a regra é teto sobre aquele tráfego, não aprovação — e essa
frase precisa estar escrita, senão o número vira selo.
