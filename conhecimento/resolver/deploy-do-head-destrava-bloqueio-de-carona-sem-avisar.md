## Deploy do HEAD destrava um bloqueio "precisa de deploy" de carona, sem avisar {#deploy-do-head-destrava-bloqueio-de-carona-sem-avisar}

`tags: deploy, HANDOFF, bloqueio fantasma, merge-base, flag dark, carona, git merge-base --is-ancestor, drift`

**Contexto:** deployei do `HEAD` pra levar um fix específico e urgente (incidente de device
WhatsApp). O `HANDOFF` do mesmo repo tinha, havia semanas, uma frente PARADA descrita como "código
pronto atrás de flag OFF, mas **exige deploy** antes do flip" — feature não-relacionada,
mergeada em `main` muito antes.

**O que quase passou batido:** o deploy do incidente builda a imagem a partir da árvore `HEAD`
inteira (é assim que o `Dockerfile` funciona — ver
[[imagem-velha-transforma-mudanca-pequena-em-deploy-grande]]). Isso significa que a frente parada,
que já estava mergeada em `main`, **subiu junto**, dark, sem ninguém ter pedido. O `HANDOFF`
continuava dizendo "exige deploy" — um bloqueio que tinha acabado de deixar de existir, e que só um
`/clear` de distância viraria fato repetido pra próxima sessão sem verificação.

**Como pegar, barato:**
```bash
git merge-base --is-ancestor <sha-do-merge-da-frente-parada> <sha-do-que-acabou-de-ir-pra-prod> \
  && echo "SIM: já está em prod" || echo "não, segue de fora"
```
Rode isso pra CADA item do `HANDOFF`/`docs/PLANO.md` marcado como "bloqueado, precisa de deploy"
sempre que você fizer um deploy do `HEAD` de qualquer motivo — não só quando o deploy for sobre
aquela frente.

**Por que importa:** um bloqueio fantasma ("ainda precisa de deploy") é mais barato de carregar do
que resolver de verdade — é a mesma armadilha de acrescentar linha no fim do checkpoint.md
([v2/loops/checkpoint.md]). A diferença aqui é que o bloqueio virou fantasma **sem ninguém editar o
HANDOFF** — o código andou, o doc não. Reconciliar contra o estado real do binário (`merge-base`),
não contra a última frase escrita, é o mesmo princípio de "o `PLANO` vence sobre o `HANDOFF`
desatualizado" aplicado a deploys em vez de a `[0]→[5-T]`.

**O que não fazer:** assumir que "esse deploy é só sobre o incidente" significa que nada mais mudou
de estado — o raio de explosão de "o que subiu" e "o que isso desbloqueia" são coisas diferentes, e
a segunda quase nunca é medida.
