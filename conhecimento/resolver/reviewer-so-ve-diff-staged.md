## Reviewer cross-provider (R11/conselho) acusa "migration ausente"/"campo morto" que JÁ existe — ele só vê o diff staged {#reviewer-so-ve-diff-staged}

`tags: review reviewer diff staged falso-positivo migration campo-morto r11 conselho`

**Sintoma:** num fluxo de commits pequenos (subagent-driven, TDD task-a-task), o reviewer do R11
solta `[SEV: risco]` do tipo:
- *"coluna adicionada no modelo sem migration correspondente no diff"* → a migration existe, foi
  commitada na task anterior;
- *"campo adicionado ao schema mas nada no backend consome — pode ser campo morto"* → o consumo foi
  commitado 2 tasks atrás;
- *"comentário cita `send_to_meta` mas essa função não está no diff"* → é forward-reference
  intencional, sequenciada no plano.

**Causa raiz:** o reviewer recebe **só o `git diff` staged**, não o repo nem o histórico. Toda mudança
sequenciada em commits atômicos "parece" incompleta pra ele. O bônus ruim: ele às vezes **inventa a
regra violada** (citou "R6 banco novo por projeto" e "R3 zero mock escondido" pra um TypeError
hipotético) e **aponta o caminho errado** (mandou criar a migration em `worker/migrations/` quando o
serviço usa `services/tracking/alembic/versions/`).

**Resolve:** triar CADA finding contra o repo antes de agir OU descartar — as duas coisas são erro:
1. `git log --oneline <base>..HEAD` / `git show <sha> --stat` → aquilo já foi commitado?
2. `grep` o consumidor do campo no repo (não no diff).
3. Se a regra citada não bate com o problema descrito, é sinal forte de alucinação — mas **verifique
   o problema mesmo assim** (a regra pode estar errada e o bug certo).
4. **Registre a triagem no commit message.** Senão o próximo (ou você em 2 semanas) "re-descobre" o
   mesmo falso-positivo e infla o código guardando contra fantasma.

**Não faça:** adicionar `getattr(x, 'campo', default)`/`?? ""` defensivo só pra calar o reviewer —
isso mascara atributo ausente de verdade e troca uma falha alta e óbvia por um bug silencioso.

**Contraponto (não vire cínico):** no MESMO marco, o Cross-Claude — que teve acesso ao repo e rodou
os testes — achou 2 bugs reais que a spec e eu tínhamos perdido. A diferença não é o modelo, é o
**contexto que ele recebe**. Reviewer com repo > reviewer com diff. Quando o finding importa, dê
acesso ao repo e peça prova empírica ("rode o teste", "quebre o guard e veja se pega").

**Ref:** Paid Media cont.104 (2026-07-15), tasks 2 e 5 do toggle Modo teste.
Ver também [Devolutiva cross-time escrita da MEMÓRIA acusa o bug errado](devolutiva-reverificar-no-codigo.md).
