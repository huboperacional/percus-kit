## Mecanismo armado não prova disparo — a tabela é que prova {#mecanismo-armado-nao-prova-disparo}

`tags: scheduler, cron, job, feature flag, default, urgencia, alcance, tabela ausente, ProgrammingError, falha silenciosa, latente vs ativo, verificacao, priorizacao`

**Sintoma:** você mede que o mecanismo está **configurado** — o job está no tick, a flag tem default
ligado, a variável não foi sobrescrita, o canal externo voltou a funcionar — e conclui que ele está
**disparando**. Prioriza o conserto como urgente, comunica isso a outras pessoas, e a conclusão é
falsa.

**Caso medido (Empresa Milionária, 2026-08-24).** Um defeito de preço em 12 mensagens de conversão
de trial. Todas as evidências de que "corria":

- `startScheduler` chamado em `main.py` ✅
- `processTrialReminders` presente no tick ✅
- `WA_PROACTIVE_ENABLED` com default `True` e **ausente** do `.env` de produção ✅
- o canal de WhatsApp reparado naquele mesmo dia ✅

Quatro medições corretas, e a conclusão errada. A verificação pós-deploy foi consultar o banco:

```
relation "trial_mensagens" does not exist
```

O texto das mensagens vivia numa tabela que **não existe em produção** — junto com `trial_envios`,
`whatsapp_sessoes`, `whatsapp_logs` e `lancamentos`. O módulo inteiro nunca executou. O defeito era
**latente**, não ativo, e a urgência atribuída não existia.

**Causa raiz:** configuração e execução são camadas diferentes, e a distância entre elas cresce em
produto derivado por fork — o código veio inteiro, o **schema** não. Medir o que está *ligado*
responde "pode acontecer?", nunca "acontece?".

**Detecção — pergunte pelo RESÍDUO, não pelo caminho.** Todo efeito real deixa rastro em algum
lugar que dá para consultar:

| Em vez de medir | Meça |
|---|---|
| o job está no tick | a tabela que ele escreve **existe**, e tem linha |
| a flag está ligada | o log do job na última janela |
| o canal foi reparado | o campo de **efeito** da última tentativa |
| o código foi publicado | o dado que o código produz |

No caso acima, o log já dizia — e ninguém o estava lendo:

```
ERROR trial_reminders_failed  errorType=ProgrammingError
```

🪤 **Falha silenciosa por desenho.** Um wrapper que isola exceção de job (`_rodarJob`, try/except no
tick) transforma "quebrado há semanas" em "nada aconteceu". O log de erro existe justamente para que
a ausência não passe calada — mas só funciona se alguém o ler. **Ao herdar um scheduler, liste os
jobs do tick e confira, um a um, se a tabela que cada um toca existe.** Uma guarda que cobre dois
nomes de job não cobre a classe: no caso, dois jobs de pessoa física saíram do tick por esse motivo
dois dias antes, e outros dois ficaram.

**Consequência prática:** o conserto continua certo — no dia em que o módulo for ligado, o defeito
estaria lá, e a guarda agora impede. O que muda é a **prioridade**, e prioridade errada comunicada
como fato faz outras pessoas decidirem errado.

Parente direto de [[status-de-sucesso-nao-prova-efeito]]: lá o `201` descreve aceitação e não
execução; aqui a configuração descreve possibilidade e não ocorrência. Ver também
[[guarda-inalcancavel-meca-o-alcance]].
