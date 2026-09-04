## Gate de tipos vira expansor de escopo quando o escape só serve à sessão interativa {#gate-de-tipos-vira-expansor-de-escopo-quando-o-escape-so-serve-a-sessao-interativa}

`tags: mypy, types-check-pre-commit, PreToolUse, subagente, sessao interativa, chamada de ferramenta, escape de gate, PERCUS_SKIP_TYPES_CHECK, env var nao alcanca o hook, divida pre-existente, escopo, arvore compartilhada, grafo de import`

**Sintoma:** um subagente implementador termina uma task de 5 arquivos e commita **24**. No
relatório, a justificativa: o hook de checagem de tipos bloqueou o commit por **dezenas de erros
que já existiam** em arquivos que a task nunca tocou, e ele "consertou" todos para destravar.

**Os três mecanismos que se somam, e é a soma que produz o estrago:**

1. **`mypy --strict` segue import.** O gate não analisa só os arquivos staged — ele percorre o
   grafo. Basta UM arquivo staged fazer `import app.models` (um teste de schema, por exemplo)
   para o pacote inteiro entrar na análise, e com ele toda a dívida de tipo pré-existente do
   projeto. Quem toca o grafo herda a conta de quem passou antes.
2. **O escape documentado não alcança chamada de ferramenta NENHUMA** — nem de subagente, nem de
   sessão interativa. `PERCUS_SKIP_TYPES_CHECK=1 git commit ...` inline **não pula a checagem**,
   porque o hook é `PreToolUse`: ele lê o env do **próprio processo**, herdado do harness,
   **antes** do teu comando executar. Setar inline chega tarde por construção.

   > 🔴 **Correção de 04/09, medida por uma segunda sessão (`-29`) horas depois deste verbete
   > nascer.** A primeira versão dizia "não alcança um **subagente**", o que era estreito demais:
   > a segunda medição mostrou que falha também nas **chamadas de ferramenta de uma sessão
   > interativa**, pelo mesmo mecanismo `PreToolUse`. O escopo real do defeito é *qualquer
   > comando disparado por agente*, não só por subagente.
   >
   > ⚠️ **O que segue NÃO medido:** um humano digitando `PERCUS_SKIP_TYPES_CHECK=1 git commit`
   > num shell **fora do harness**. Ninguém testou. É plausível que funcione (é a intenção
   > declarada no cabeçalho do hook) e é o único cenário em que o escape ainda faria sentido —
   > mas continua **hipótese, não fato**. A própria `-29` recusou o crédito por uma refutação
   > mais forte do que mediu, e a distinção é dela.

   Mesma família do guard R20, que lê o cwd do processo e não o do comando.
3. **O implementador não tem autoridade para decidir escopo, mas tem teclado.** Diante de "o
   commit não passa", a saída que ele enxerga é consertar. Reportar BLOCKED ao controlador é a
   saída certa e a menos óbvia — ninguém dispara subagente esperando que ele desista.

**Por que é caro mesmo quando as correções são inofensivas:** numa árvore compartilhada, 18
arquivos alheios entram num commit cujo assunto é outro. O `git log` passa a mentir sobre o que
aconteceu, o review da task tem que auditar mudança que não era da task, e a próxima sessão que
abrir um desses arquivos encontra anotação que ninguém explicou. No caso medido as correções eram
mesmo mecânicas (`dict` → `dict[str, Any]`, blocos `TYPE_CHECKING`, assinatura de listener) — mas
isso só foi possível **saber** depois de auditar as 18 linha a linha.

**Como resolver, na ordem:**

- **Antes de disparar o subagente:** rode a checagem você mesmo, uma vez. **Não há wrapper
  standalone** — o hook espera JSON no stdin simulando o payload, então o caminho prático é
  chamar o mypy direto com a mesma severidade: `mypy --strict <os arquivos que a task vai
  tocar>`. Se vier vermelho por dívida pré-existente, ou limpe antes (commit próprio, assunto
  próprio) ou diga ao subagente, no dispatch, o que fazer quando bater — sem instrução ele
  conserta.
- **No dispatch, sempre:** *"se um gate bloquear o commit por dívida que não é desta task, volte
  BLOCKED com a lista. Não conserte arquivo fora do escopo."* Uma frase evita a expansão inteira.
- **Se já aconteceu:** não reverta por reflexo. Audite o conjunto — **linha a linha, não por
  amostragem** — e decida com evidência. Correção mecânica de verdade pode ficar; qualquer
  mudança de comportamento sai para commit próprio.
- **Avise as sessões vizinhas** nominalmente, listando os arquivos. Quem abrir um deles depois
  precisa saber de onde veio a anotação que não escreveu.

**Não faça:** dar `--no-verify`, editar o hook, ou tratar o gate como defeito. Ele está certo — o
que está errado é uma rota de escape que existe para humano e não existe para agente, e um
dispatch que não disse o que fazer no bloqueio.

**Ref:** Empresa Milionária, 2026-09-04 — Task 3 do plano de cadastro bancário/chaves PIX
(5 arquivos previstos, 24 commitados; 36 erros pré-existentes em 18 arquivos). Review posterior
confirmou as 18 como mecânicas, mas a decisão de aceitar só pôde ser tomada depois da auditoria.
Ver também `subagente-que-espera-notificacao-de-background-trava-calado` (o mesmo implementador
travou 18 min antes disso, por outro mecanismo).
