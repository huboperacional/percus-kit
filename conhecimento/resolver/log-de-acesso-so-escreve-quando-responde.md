## "Nenhum erro no log do backend" não significa "nenhuma requisição" — o log de acesso só escreve QUANDO responde {#log-de-acesso-so-escreve-quando-responde}

`tags: uvicorn, access log, requisicao em voo, timeout de e2e, playwright, toBeHidden, botao em enviando, falso diagnostico, tela travada, latencia, tunel ssh, RLS, cross-empresa, medir no banco`

**Sintoma:** um teste de tela estoura esperando um diálogo fechar (ou um spinner sumir), o botão fica preso em "Enviando…"/"Registrando…", e o log do backend **não mostra erro nenhum** — nem 4xx, nem 5xx, nem traceback. A conclusão fácil é *"a tela travou"* ou *"a requisição nem saiu"*.

**Causa raiz:** o log de acesso do servidor (uvicorn, gunicorn, nginx) é escrito **no momento da resposta**, não no da chegada. Requisição ainda **em execução** não produz linha nenhuma. Se o cliente desiste antes (timeout do `expect`, do `fetch`, do proxy) e derruba a conexão, a linha **nunca** aparece — o log fica com um buraco exatamente onde estava o trabalho.

Logo: *"nenhum erro no log"* prova apenas que **nada terminou com erro**, e nada sobre o que começou.

**Solução:** quando o cliente desistiu, **não pergunte ao log — pergunte ao estado**. O que separa *travou* de *demorou* é olhar o banco (ou a fila, ou o arquivo) e ver se a escrita aconteceu:

```sql
-- as linhas que a requisicao deveria ter criado existem?
select count(*) from baixas where empresa_id = :alvo;
```

Se existem, o servidor completou e o cliente é que foi impaciente — o conserto é **timeout naquela asserção**, com o motivo escrito, e **nunca** no timeout global: alargar o global faz toda asserção do arquivo esperar, e um dia esconde uma tela que travou de verdade. A asserção em si não se afrouxa; o que muda é a paciência.

**Onde mais morde:** requisições que fazem muito trabalho num pedido só — as que atravessam fronteira de tenant, disparam notificação, ou gravam em duas empresas na mesma transação. Pior ainda quando o banco está atrás de um **túnel SSH**: cada ida custa latência de rede, e uma operação de trinta consultas passa de sub-segundo para dezenas de segundos sem nada estar errado.

**Como reconhecer na hora:** o par *"cliente estourou"* + *"log limpo"* é a assinatura. Some a isso um botão em estado de envio no screenshot/snapshot da falha, e a hipótese "travou" já está fraca — meça o estado antes de mexer no código.

**Ref:** 2026-09-07, Empresa Milionária — R1 do intercompany. Dois de quatro casos estouravam em `toBeHidden()` aos 15s com zero erro no backend; o banco mostrou as baixas gravadas nos dois lados e a pendência nascendo só no caso que devia. Conserto: timeout próprio de 60s naquela linha. Ver também [[preflight-cors-falha-silenciosa]], que é a outra causa de "a tela não fala com o servidor" e essa **sim** aparece no log, como `OPTIONS ... 400`.
