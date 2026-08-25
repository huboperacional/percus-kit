## Antes de culpar o código, desça a cadeia até a ENTREGA {#antes-de-culpar-o-codigo-desca-ate-a-entrega}

`tags: watchdog, alerta, diagnostico, cadeia de dados, falso culpado, N de M, midia paga, meta ads, conta pausada, higiene de cadastro, SUCCESS sem gravar, R23`

**Contexto:** um vigia novo entra em produção e, no primeiro dia, acusa um job:
`SEM_PRODUZIR — "3 de 13 sujeitos ativos sem carimbo novo"`. O instinto é abrir o código do job.

**O instinto erra na direção mais cara.** A cadeia tem pelo menos quatro elos, e o alerta nasce no
último:

```
entrega (há o que medir?) → coleta (trouxe?) → processamento (calculou?) → destino (gravou?)
```

O vigia só enxerga o **destino**. Subir a cadeia elo por elo custa minutos; começar pelo código custa
uma tarde e produz um "conserto" para um sistema que estava certo.

**Caso medido (2026-08-25).** O job de análise não escrevia relatório para 3 de 13 clientes.

1. **Código:** `if not metrics_today: return None` — ele **não grava** quando não há métrica. Certo.
2. **Processamento:** o último relatório de um cliente era de **12/06**; a última métrica dele, de
   **11/06**. Um dia de diferença — a cadeia estava **intacta**, a fonte é que secou.
3. **Coleta:** o log de coleta dizia `SUCCESS`, 7 execuções em 7 dias — e a tabela de métricas estava
   **vazia** para aquelas contas. Sucesso do processo ≠ dado gravado.
4. **Entrega:** perguntando à API do anunciante: uma conta tinha **8 campanhas, todas pausadas** desde
   11/06; a outra tinha **zero campanhas** e gasto histórico **zero** desde o cadastro.

**Ninguém estava quebrado.** Duas contas seguiam marcadas como ativas no cadastro sem ter o que
entregar — e nenhum dos três sinais anteriores dizia isso, porque todos os três respondiam
"funcionou": o job rodou, a coleta gravou `SUCCESS`, o registro de execução ficou fresco. **Só o
destino acusa esse modo de falha**, e é exatamente por isso que a segunda evidência existe.

**Leitura do `N de M`:** `N` pequeno quase nunca é o job quebrado — é sujeito sem matéria-prima.
`N == M` (todo mundo parado) aí sim aponta para configuração, lock ou o próprio código.

**Duas armadilhas ao resolver:**
- **Não silencie o job inteiro** por causa de 2 sujeitos: o silêncio costuma ser por JOB e calaria os
  outros 11 que estão saudáveis.
- **Não "conserte" o cadastro por conta própria.** Marcar conta de cliente como inativa é decisão de
  negócio, não de vigia. O trabalho do agente termina em entregar o fato medido.

**Cuidado com a sonda que você escreve para investigar:** a primeira versão da minha lia só o token
específico da conta e concluiu *"não decifrou"* para uma conta que o coletor lê sem problema — o
coletor tem um **fallback** para a credencial global que eu não havia reproduzido. Sonda de
diagnóstico precisa percorrer o **mesmo caminho** do produtor, senão ela inventa um defeito.

Relacionado: [[status-de-sucesso-nao-prova-efeito]],
[[funcao-que-termina-em-log-sempre-devolve-zero]].
