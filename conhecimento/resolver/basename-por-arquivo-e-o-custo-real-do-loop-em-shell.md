## Gate de 120s: o custo não era o `awk`, era um `basename` por arquivo {#basename-por-arquivo-e-o-custo-real-do-loop-em-shell}

`tags: performance, shell, basename, subprocesso, fork, gate lento, pre-commit, git bash, windows, expansao de parametro, awk passada unica, medir antes de otimizar`

**Sintoma:** um gate/script que varre muitos arquivos passa de segundos para **minutos** depois de a
base crescer. No caminho do pre-commit, isso é fatal: gate lento é gate que alguém desliga.

**Causa raiz:** o loop chama um **executável externo por arquivo**. Cada `basename`, `dirname`, `sed`,
`cut` dentro de um `for` é um `fork`+`exec`. No Windows/Git Bash o custo de criar processo é uma
ordem de grandeza maior que em Linux, então o que parece idiomático vira o gargalo inteiro.

**O caso (percus-kit, 2026-08-18), e a ordem em que a medição corrigiu o palpite:**

| Versão | Tempo | O que mudou |
|---|---|---|
| original (1 arquivo) | ~2s | — |
| por arquivo: `sed \| tr \| awk` | **>120s** | ~2000 processos para 415 arquivos |
| uma passada de `awk` | 22,7s | 2 processos de awk… mas `basename` continuou no loop |
| sem `basename` | **1,9s** | expansão de parâmetro do shell |

🔑 **O palpite errado custou uma reescrita.** Eu ataquei o `awk` primeiro, porque "3 comandos por
arquivo" parecia o vilão óbvio — e ganhei 5×. O `basename`, que sobrou num loop de aparência inocente,
valia **12×** sozinho. Depois de otimizar, o gate ficou **mais rápido do que era antes**, com quatro
blocos de verificação a mais.

**Solução — expansão de parâmetro, que é interna ao shell e não cria processo:**

```sh
# lento: um processo por arquivo
_b=$(basename "$_f" .md)

# rápido: puro shell
_b=${_f##*/}     # tira o caminho
_b=${_b%.md}     # tira a extensão
```

Equivalentes que valem a pena decorar: `${p##*/}` = `basename`; `${p%/*}` = `dirname`;
`${v%suffix}` / `${v#prefix}` = `sed 's/…//'` em caso simples.

**Regra de método:** **meça antes de reescrever, e meça de novo depois.** O `time` custa nada e teria
mostrado, na primeira rodada, que o `awk` não era o problema principal. Otimização guiada por
intuição concerta o que incomoda a leitura, não o que consome o relógio.

⚠️ **Passada única de `awk` tem um preço próprio, e ele é fácil de esquecer:** ela move o estado
por-arquivo para dentro do `awk`, e aí você precisa **fechar o arquivo anterior à mão** no `FNR==1` —
senão a checagem só vale para o último arquivo da lista e passa verde em todos os outros. Ver também
[arquivo-vazio-escapa-de-checagem-por-awk](arquivo-vazio-escapa-de-checagem-por-awk.md): na passada
única, arquivo de zero bytes nunca é visitado.

**Ref:** percus-kit 6.38.0, 2026-08-18. `v2/gates/percus-gate.sh`, bloco 2, com 415 verbetes.
