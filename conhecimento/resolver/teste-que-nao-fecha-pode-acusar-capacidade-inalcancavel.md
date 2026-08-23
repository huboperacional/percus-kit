## Item parado em "falta o teste" pode ser capacidade INALCANÇÁVEL {#teste-que-nao-fecha-pode-acusar-capacidade-inalcancavel}

`tags: tracking, 4-C, code-complete, verificacao, smoke, capacidade inalcancavel, classificador, empate, LLM referente, escrita indevida, premissa de plano, TDD`

**Contexto:** uma feature fica marcada como *code-complete* (implementada, deployada) com a nota *"só
falta escrever/reescrever o teste que exercita a capacidade nova"*. A nota vem acompanhada de uma
causa **explicitamente não verificada** para o teste anterior não ter fechado. O item envelhece assim
por dias ou semanas, porque "escrever teste" parece trabalho mecânico que sempre cabe depois.

**Causa raiz (medida em 2026-08-23):** o teste não estava faltando — ele **não tinha como passar**.
Havia um defeito em produção tornando a capacidade **inalcançável**: um resolvedor de referente por LLM
desempatava sozinho entre dois alvos igualmente plausíveis, com confiança "alta", e **executava**. O
card de desambiguação que a feature construiu nunca chegava a abrir com a flag ligada. O smoke antigo
passava `12/12` porque exercitava outro caminho (um menu mais antigo, com um alvo só).

**A inversão que importa:** *"falta o teste"* é uma afirmação sobre o teste. Quase sempre é, na verdade,
uma afirmação **não medida** sobre o produto. Escreva o teste e **deixe ele reprovar** — a reprovação
é a medição, e é mais barata que a investigação que você está adiando.

**Diagnóstico (a ordem que funciona):**
1. **Separe bloqueio de SETUP de bloqueio de PRODUTO.** No caso medido, a tentativa anterior falhou ao
   criar o segundo registro *por mensagem*; **semear por SQL** funciona e é determinístico. Semeie o
   pré-requisito e exercite só o que está em dúvida — a criação pelo caminho real já era provada por
   outro caso da mesma rodada.
2. Rode o teste novo e **leia a reprovação como dado**, não como bug do teste.
3. Confirme no log do serviço qual componente decidiu (`n_candidatos`, `n_matches`, decisão do gate,
   escrita efetivada). Três linhas de log fecham o diagnóstico que a leitura de código não fecha.

**Conserto (padrão reutilizável):** quando um classificador escolhe entre candidatos **igualmente
plausíveis**, ele não deve escolher — cai no card/menu que sabe perguntar. O atalho continua valendo
quando ele **sabe** (um candidato casa). A sonda de empate tem de ser **o matcher do próprio handler**:
uma segunda regra de "isto é ambíguo" diverge do resolvedor na primeira mudança.

**Buraco que vale declarar em vez de fechar:** texto **sem termo** ("paguei a parcela") resolve o alvo
pelo CONTEXTO da conversa — capacidade legítima que não dá para sondar sem reimplementar o entendimento
do modelo. Empate sem termo é caso não medido; fechar ali é decidir sem evidência. Trave em teste para
que abrir depois seja decisão visível.

**Um portão de escrita não protege o ALVO.** No caso medido o portão aprovou (`destino=aplicar`) porque
a frase era assertiva — e era mesmo. O problema nunca é a assertividade, é o alvo. Não espere que o
gate de "esta frase autoriza escrever?" pegue "esta frase autoriza escrever **nisto**".

**O PASS forte não é "o card abriu"** (ele já existia). É *"escreveu no alvo escolhido e **ZERO** no
irmão"*. Sem a segunda metade, um resolvedor que baixasse os dois passaria verde.

Ver também [[ramo-que-cede-esconde-qual-irmao-sequestra]].
