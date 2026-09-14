## Janela de estabilidade de alerta (histerese) se escolhe por REPLAY do log real, não por estimativa {#janela-de-estabilidade-de-alerta-se-escolhe-por-replay-do-log}

`tags: alerta, watchdog, oscilacao, flapping, histerese, janela de estabilidade, replay, telegram, recuperacao, R23`

**Sintoma:** um serviço em crashloop vira dezenas de pares "🚨 falhando" / "✅ recuperado" por dia. A
correção óbvia — "só considera recuperado depois de N minutos estável" — é escolhida com um N
redondo e uma estimativa de quantas mensagens sobram. A estimativa sai otimista e a decisão fica de pé
sem ninguém medir.

**Reprodução real** (Paid Media, watchdog de infra, 2026-09-13): em 13/09 o `tracking-worker` ficou
instável por 21h e a sonda `swarm` mandou **59 mensagens** (o contador zerava no primeiro check OK). A
decisão inicial foi "recuperado só depois de 15 min estável", anotada como "~6 mensagens em vez de 59".
Antes de virar spec, a sequência real da sonda foi extraída do log e repassada por um script. O
formato da linha do log (canônico dos watchdogs, `log()` = `[timestamp] [PROJETO] mensagem`) é:

```
[2026-09-12T00:00:02Z] [PAID_MEDIA] FAIL swarm (count=1) Servicos degradados: paid-media_tracking-worker(0/1).
[2026-09-12T00:05:02Z] [PAID_MEDIA] OK   swarm
```

Com separação por espaço, `$1` é o timestamp (um token só, sem espaço interno), `$2` a tag do projeto e
**`$3` o estado** (`OK`/`FAIL`). Se o seu log tiver timestamp com espaço, o índice muda — confira numa
linha real antes de rodar:

```bash
grep -E '(OK   |FAIL )swarm' watchdog.log | grep -E '^\[2026-09-1[23]' \
  | awk '{st=$3; if(st!=prev){ if(prev!="") print start, prev, n; start=$1; prev=st; n=0 } n++ } END{print start, prev, n}'
```

Isso dá as corridas (`início estado checks-seguidos`). Um simulador de 60 linhas aplicou a regra atual
e cada janela candidata. **Calibração primeiro:** a regra atual reproduziu 60 envios contra 59 no log —
sem isso, nenhum número do simulador vale nada.

| janela | mensagens em 13/09 |
|---|---|
| regra atual (fecha no 1º OK) | 60 |
| 15 min | **34** |
| 30 min | 10 |
| 45 min | 5 |
| 60 min | 5 |

**Por que 15 min não servia:** dentro do incidente, as janelas OK duravam **15 a 35 min** (3 a 7 checks
de 5 min). Qualquer janela abaixo de ~40 min fecha e reabre o incidente o dia inteiro. O número certo
estava na distribuição das janelas OK *dentro* do incidente — que só o replay mostra. A decisão foi
levada de volta ao dono e virou 1h.

**Brinde que só o replay dá:** o dia anterior, "calmo", era o mesmo serviço falhando **1 check a cada
30 min o dia inteiro** — invisível para a regra de "2 checks seguidos" que abre incidente.

**Como aplicar:**
- Toda regra de histerese de alerta (janela de estabilidade, anti-flap, limiar de abertura) se escolhe
  rodando a sequência real de OK/FALHA de pelo menos um incidente ruim sob cada valor candidato.
- Calibre o simulador contra o log (a regra atual tem de reproduzir os envios reais) antes de comparar.
- Guarde a sequência como fixture e trave o valor escolhido num teste que **reprova** com o valor
  descartado — assim ninguém "otimiza" a janela de volta para 15 min sem ver o número.
- Estimativa de "quantas mensagens sobram" escrita numa decisão é hipótese até o replay confirmar.
