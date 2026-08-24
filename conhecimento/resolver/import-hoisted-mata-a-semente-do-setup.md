## Import hoisted mata a semente do setup — e o sintoma só aparece na tarefa que vira o default {#import-hoisted-mata-a-semente-do-setup}

`tags: vitest, setupFiles, hoisting, ES modules, i18n, semente, falso verde, ordem de avaliacao, teste que nao mede, simulacao`

**Contexto:** arquivo de setup de suíte (`setupFiles` do Vitest) que precisa **gravar um estado
antes** de um módulo ser avaliado — semente de `localStorage`, variável de ambiente, mock de
relógio. O caso medido foi i18n: semear o idioma antes de `lib/i18n.ts` resolver o `lng` no
import-time.

**A armadilha:** escrever assim **não funciona**, e parece funcionar.

```ts
try { localStorage.setItem('mi.lang', ...) } catch {}   // corpo do arquivo
import '@/lib/i18n'                                     // ← HOISTED
```

`import` de ES module é **hoisted**: roda antes de qualquer código do corpo do arquivo,
independentemente da posição no texto. A semente é gravada **depois** de o módulo já ter lido o
estado vazio.

**Por que passa despercebido por semanas:** enquanto o valor semeado for **igual ao default**, o
resultado observável é o mesmo. No caso medido, a semente era `'pt-BR'` e o default também era
`'pt-BR'` — a suíte ficava verde **por coincidência**, e o defeito só detonaria na tarefa que
virasse o default para outro idioma. Ali o sintoma seria *"o flip quebrou 5 testes"*, quando a
verdade é *"a semente nunca funcionou"* — um diagnóstico muito mais caro.

**O conserto:** ordem **entre módulos** é real, ao contrário da ordem dentro do arquivo.

```ts
import './test-setup-idioma'   // modulo que SO' grava a semente
import '@/lib/i18n'            // avaliado depois, ja' enxerga o estado
```

**A prova, e ela é obrigatória:** troque temporariamente o default para um valor **diferente** da
semente e rode a suíte. Se a semente funciona, nada quebra além dos testes que afirmam sobre o
próprio default. Medição real do caso: com o default virado, o bug rendia `4 arquivos / 5 testes`
falhando; depois do conserto, **1 falha** — e ela era o guard deliberado que exige que o default
ainda não tenha virado, matematicamente incapaz de passar sob a simulação.

**Cuidado com o comentário.** O arquivo original **documentava** a intenção ("gravado antes do
import de propósito") e a documentação estava **errada sobre o mecanismo** — atribuía o
funcionamento à posição no texto. Comentário que justifica pelo motivo errado é pior que ausente:
o próximo a acrescentar um import ali confia nele e reintroduz o bug em silêncio. Escreva **por que
funciona** (ordem de avaliação entre módulos + o runner executar o setup inteiro antes dos testes)
e **o que quebra** (qualquer import novo que carregue o módulo semeado).

**Sinal de que você está no caso:** o teste passa, o valor semeado coincide com o default, e ninguém
nunca rodou a suíte com os dois diferentes.

Ver também [[a-sabotagem-prova-o-que-voce-imaginou]].
