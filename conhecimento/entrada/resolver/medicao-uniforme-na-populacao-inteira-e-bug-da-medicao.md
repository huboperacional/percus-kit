## Métrica que dá o MESMO valor extremo pra população inteira é bug da medição, não achado {#medicao-uniforme-na-populacao-inteira-e-bug-da-medicao}

`tags: medicao, metrica, falso-verde, falso-zero, redis, scan_iter, agrupamento, chave vs payload, grupo de controle, baseline, auditoria, R23`

**Sintoma:** você roda uma medição sobre produção e o resultado é o **mesmo valor extremo em todos os
grupos** — todo mundo `0`, todo mundo `0,0h`, todo mundo `100%`. O número é plausível pro grupo que
você está investigando (é justamente o que você suspeitava!), então você o reporta.

**Causa raiz:** uniformidade perfeita quase nunca é propriedade do mundo — é propriedade de um
**agrupamento quebrado**. O caso concreto: medir "vida da família de refresh token" agrupando por um
campo `family_id` **do payload JSON**, quando a família mora na **chave**
(`auth:refresh:{family_id}:{token_id}`) e esse campo não existe no payload. Com o fallback caindo na
chave inteira, **cada token virou sua própria família** → `max(created_at) - min(created_at) == 0`
para todas, em todas as audiences.

**O que salvou:** um **grupo de controle com valor conhecido**. A foto anterior dizia que duas
audiences tinham famílias de 486h e 502h. Quando essas também apareceram com `0,0h`, ficou óbvio que a
régua estava quebrada — não que 20 dias de sessão tinham sumido. Sem esse par de referência, o
`0,0h` teria sido reportado como evidência de que um fix de outro time não pegou.

**Solução / protocolo:**
1. **Inspecione UM registro cru antes de agregar.** `print` das chaves e tipos do payload de um item.
   O agrupamento errado é invisível no agregado e óbvio no registro.
2. **Inclua sempre um grupo que você sabe que deveria ter valor diferente.** Se ele vier igual ao
   suspeito, a medição é o defeito. Isso vale mais que qualquer revisão de código da query.
3. **Desconfie de fallback silencioso.** `fam = p.get("family_id") or chave` não falha, só mente.
   Prefira falhar alto: conte os registros que não deram parse e **imprima o contador** — se for
   ≠ 0, não reporte nada ainda.
4. **Separe "não aconteceu" de "não teve chance".** Uma sessão criada há 10 minutos não deveria ter
   renovado; contá-la como "presa" infla o defeito. Estratifique por **idade** contra o intervalo
   natural do fenômeno (ex.: access token de 15min → só idade > 1h "teve chance").
5. **Ausência ainda não é defeito.** Mesmo medindo certo: família sem rotação pode ser usuário que
   logou uma vez e não voltou. Se a fonte não sabe distinguir isso, diga isso na conclusão em vez de
   converter ausência em culpa.

**Por que isto vira dano real:** métricas cross-produto disparam trabalho no repo alheio. Um `0,0h`
falso mandado numa devolutiva reabre investigação encerrada, e o outro time gasta dias procurando um
defeito que existe só na sua query.

**Ref:** auth-service, medição de rotação de família da audience `micro-investors`, 2026-08-17.
Primeira rodada deu `0,0h` em 9 audiences, inclusive `paid-media` e `plexco-tasks`, que a baseline de
2026-07-25 registrava com 616h e 217h. Mesma família de erro do falso-zero por comparar `created_at`
como ISO-string quando é `int` epoch (2026-07-31) e de medir a população errada no P0 de CORS
(2026-07-30).
