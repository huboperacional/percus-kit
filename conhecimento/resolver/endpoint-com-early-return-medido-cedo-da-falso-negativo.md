## Endpoint que responde antes de terminar: medir logo depois dá falso-negativo {#endpoint-com-early-return-medido-cedo-da-falso-negativo}

`tags: early-return, 202, accepted, background task, assincrono, falso-negativo, corrida, redis, scan_iter, verificacao, otp, magic-link, anti-abuso, medicao`

**Sintoma:** você aplica uma correção, chama o endpoint pra validar, e a verificação diz que o efeito
**não aconteceu** — nenhuma chave nova no Redis, nenhuma linha nova na tabela, nenhum arquivo escrito.
O endpoint respondeu sucesso (`202`, `200`), mas o resultado não está lá. Parece que a correção falhou,
ou pior: parece o modo de falha que você mesmo tinha previsto, o que torna a conclusão errada muito
convincente.

**Causa raiz:** o endpoint tem **early-return por desenho** e faz o trabalho depois de responder. É
comum em fluxos anti-abuso (responder igual pra destino existente e inexistente, pra não virar oráculo)
e em qualquer coisa com fila/worker. O `202 Accepted` significa literalmente "aceitei, ainda não fiz".
Sua verificação corre em milissegundos; o trabalho leva ~1 segundo. Você mede o "antes" e chama de
"depois".

O agravante: a checagem "capturei o conjunto antes, chamei, capturei o conjunto depois, diferença = 0"
**parece rigorosa**. Ela tem grupo de controle, tem antes-e-depois — e ainda assim é uma corrida.

**Solução:**
1. **Confirme que é assíncrono antes de concluir qualquer coisa.** O log costuma entregar: se a linha
   que prova o trabalho (`smtp.sent`, `dispatched`, `stored`) tem timestamp **posterior** à sua
   varredura, o problema é a corrida, não o código.
2. **Verifique por estado final, não por delta imediato.** Em vez de `depois - antes`, liste o estado
   e procure o registro esperado — o efeito continua lá depois. Um `sleep` curto resolve o caso
   simples, mas ler o estado final é mais honesto que calibrar espera.
3. **Antes de declarar "não aconteceu", valide a própria sonda.** Confirme que o padrão de busca casa
   com o formato real (leia o código que grava a chave). Padrão errado e trabalho ausente produzem o
   mesmo zero — e você não distingue os dois sem olhar.
4. **Se o log tiver ramo de skip com motivo, procure o motivo.** Código que loga "pulei porque X"
   transforma o silêncio em evidência: **ausência da linha de skip** já diz que não foi pulado.

**Por que isso vira dano:** o falso-negativo aparece justamente quando você acabou de mexer em algo e
está procurando confirmação. A tentação é reverter a mudança boa, ou reportar quebra inexistente pro
time do outro produto.

**Relacionado:** [Métrica que dá o MESMO valor extremo pra população inteira é bug da medição](medicao-uniforme-na-populacao-inteira-e-bug-da-medicao.md)

**Ref:** auth-service, troca de domínio da audience `openreply` → `liliflow.com.br`, 2026-09-07.
`/otp/request` responde `202` e minta o magic-link do combinado em background; a varredura de
`auth:magic:*` feita logo após o `202` deu zero, e a magic estava lá segundos depois, com o
`redirect_uri` correto. O `smtp.sent` no log, 1s após o `202`, foi o que denunciou a corrida.
