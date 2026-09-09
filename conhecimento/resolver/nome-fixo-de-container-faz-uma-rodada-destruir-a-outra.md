## Nome fixo de container efêmero faz uma rodada DESTRUIR a outra em pleno voo {#nome-fixo-de-container-faz-uma-rodada-destruir-a-outra}

`tags: container, nome fixo, docker rm -f, concorrencia, subagente paralelo, banco efemero, orfao, diagnostico que mente, log destruido, R23`

**Sintoma:** `"container vivo, socket ausente"` — o `docker exec` funciona (o container existe) mas
o serviço nunca responde, e o script conclui *"o serviço não subiu"*. A mesma invocação passou
minutos antes.

**Mecanismo, e ele é pior que "dois containers com o mesmo nome":** a **primeira linha** do bloco
remoto costuma ser `docker rm -f "$NOME"` (limpeza defensiva). Com nome FIXO, uma segunda rodada
**destrói o container da primeira em pleno voo** e cria o seu. A rodada A segue fazendo
`docker exec $NOME pg_isready` — **no container de B**, criado 90s depois e ainda inicializando.

**Conserto:** o sufixo não pode ser opcional. `SUF="-${SUFIXO:-$(date +%s)-$$}"` — default único
por invocação mata a classe inteira, inclusive o `rm -f` de abertura que sabota rodada alheia.

🚩 **Dois anti-padrões que apareceram juntos e custam mais que o bug:**

- **O ramo de erro destruía o container ANTES de qualquer log** (`docker rm -f` e então `exit`).
  Toda falha do gate nascia **indiagnosticável por construção**. Imprima `docker logs --tail 50` e
  `docker inspect` (com `.State.OOMKilled`) **antes** de remover.
- **A mensagem de erro carregava um diagnóstico em prosa, e ele mentia nas duas afirmações** —
  culpava containers órfãos por "competir por memória" (já medidos em ~76 MiB, e presentes durante
  os sucessos do mesmo dia) e dizia que o nome "é fixo" quando o sufixo já existia. **Diagnóstico em
  prosa apodrece igual a número em prosa**: prefira imprimir o log a adivinhar a causa.

**Ref:** tiatendo, 2026-08-31, commit `4665bd2`; mesmo sintoma no `071`. Irmãos:
[#harness-remoto-empacota-sem-o-ancora-de-rootdir]. R23.
