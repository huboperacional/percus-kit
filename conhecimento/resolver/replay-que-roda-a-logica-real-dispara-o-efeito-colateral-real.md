## Replay que roda a lógica real dispara o efeito colateral real — "somente leitura" do banco não cobre saída HTTP {#replay-que-roda-a-logica-real-dispara-o-efeito-colateral-real}

`tags: replay, backfill, sonda, somente leitura, efeito colateral, whatsapp, notificacao, script de operacao, producao, R23`

**Sintoma:** você escreve um script que reprocessa histórico de produção contra a lógica **real** de
um detector/guarda/job, com a regra "somente leitura" escrita no brief. O script de fato nunca faz
`INSERT`/`UPDATE`/`DELETE`. E ainda assim ele **manda uma mensagem de verdade** para uma pessoa real.

**Causa raiz:** a lógica que você quis reusar tem uma **saída para o mundo** acoplada à decisão —
notificar o operador, chamar webhook, mandar e-mail. Quem escreve "somente leitura" está pensando em
**banco**; a chamada HTTP não é escrita de banco e passa pelo lado de fora da regra. E o ambiente
local costuma ter as credenciais **reais** do provider, porque é o mesmo `.env` com que se opera.

Reusar a lógica real é a decisão **certa** — reimplementar a regra no script produz duas regras que
divergem em silêncio. O efeito colateral vem junto por construção, e é isso que precisa ser
neutralizado explicitamente.

**Medido na Família Milionária (2026-09-18):** o replay do histórico do guard anti-loop lia
`whatsapp_logs` só com `SELECT` e alimentava um SQLite em memória local. Ao travar o número do
incidente, o detector chamou `_avisarOperador` → `escalarParaOperador` → `wa_client` → **GOWA real**:
uma mensagem WhatsApp entregue no telefone do operador (`messageId` retornado pelo provider),
anunciando um silêncio que só existia na memória do script. Uma só — o dedupe por episódio segurou as
outras 22 — e nenhuma linha de produção foi escrita.

### O que fazer

1. **Antes do primeiro run**, liste as saídas da lógica para fora do processo: envio de mensagem,
   e-mail, webhook, fila, cache compartilhado. `grep` pelos clientes (`*_client`, `escalar*`,
   `notificar*`) a partir da função que você vai chamar.
2. **Neutralize no próprio script**, não no ambiente: reatribua o símbolo **no namespace do módulo
   que o chama** (é lá que o nome é resolvido em tempo de chamada) por um stub que **captura numa
   lista local** e devolve o valor de sucesso.
3. **Coloque o patch dentro da função que toca a lógica**, não no nível do módulo nem só no `main()`:
   no nível do módulo, quem importar o script cala a saída no processo inteiro; só no `main()`,
   qualquer chamador direto da função interna volta a mandar de verdade.
4. **Prove pela ausência no log**: o run final não pode ter a linha de envio do provider
   (`whatsapp_sent`, `mail_sent`…). E **imprima a contagem de suprimidos** — "N avisos suprimidos" é
   prova por presença de que o desvio funcionou.
5. No brief, escreva **"sem efeito colateral externo"**, não "somente leitura". São coisas
   diferentes, e a segunda não implica a primeira.

### O que NÃO fazer

Não mova a preparação de ambiente (`os.environ["DATABASE_URL"]`, `APP_ENV`) para dentro do `main()`
"para tirar efeito colateral de import": ela **tem** de rodar antes de qualquer `import app.*`, porque
`settings` e `engine` nascem no import — mover reabre o risco de o script apontar para o banco de
produção. Import com efeito colateral é o preço; isole o script rodando os testes dele em subprocesso.

Relacionado: [[fail-open-esconde-teste-vacuo]], [[corpus-escrito-nao-substitui-replay-real]].
