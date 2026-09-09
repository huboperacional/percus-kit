## O "par positivo" não salva a asserção negativa — ele também passa por coincidência {#o-par-positivo-tambem-passa-por-coincidencia}

`tags: teste, assercao negativa, vacuo, mutacao sobrevivente, template, jinja, html, substring, par positivo`

**Sintoma:** você escreve o par canônico — um teste que exige a string (`assert X in html`) e outro
que exige a ausência dela (`assert X not in html`) — os dois passam, e mesmo assim a **mutação que
deveria quebrá-los SOBREVIVE**. O código pode ser revertido ao defeito e a suíte segue verde.

**Por que o par não bastou:** a regra conhecida ("asserção negativa sozinha é vácuo — exija o par
positivo") assume que, se o positivo passa, a string É observável naquele ponto. **Não é.** O
positivo pode casar por **coincidência**, com outro trecho do artefato, enquanto o negativo é
vaziamente verdadeiro porque a string **não existe em lugar nenhum** da saída.

Caso medido: o teste procurava `"de 10 etapas"` / `"/ 10"` / `">10<"` no HTML para provar o
denominador de um checklist. O template **nunca renderiza o total como número** — ele só o expõe
como **porcentagem** (`{{ (done/total*100)|int }}%`) e como **subtração**
(`{{ total - done }} etapa(s)`). O negativo passava por vácuo; o positivo casava `">10<"` em outro
ponto qualquer do HTML. Os dois verdes, e a mutação viva.

🔑 **A pergunta que descobre isso em 30 segundos, e que "positivo + negativo" não faz:**
*onde, no artefato, este valor é REALMENTE escrito?* Abra o template/serializador e ache a linha.

```bash
# a fonte decide, não a sua intuição sobre o que a tela mostra
grep -n "total" execution/dashboard/templates/onboarding.html | grep -v "set "
```

Se a resposta for "não é escrito", o valor **não é observável por string** — meça pela forma
DERIVADA em que ele aparece (a porcentagem, a subtração, a contagem de elementos, um `aria-label`),
ou pelo efeito que ele causa em outro campo.

**Como resolver:**
1. Ache a linha que ESCREVE o valor. Se não existe, escolha outro observável.
2. Prefira uma âncora que **muda de valor** com a mudança (`aria-label="66% concluído"` →
   `"60% concluído"`) a uma que apenas existe ou não existe.
3. **Deixe a mutação arbitrar.** Um par que passa não prova nada; um par que a mutação mata, sim.
   Foi a mutação sobrevivente — não a leitura do teste — que expôs o vácuo.

⚠️ **Mutação sobrevivente tem mais de um desfecho, e este é o 4º:** não é "teste fraco" no sentido
de faltar cobertura, nem "guarda mascarada", nem "a guarda está errada", nem "a guarda está escrita
duas vezes" — é **o teste medir um observável que não existe**. O sintoma é idêntico; a correção é
diferente (trocar a âncora, não escrever mais testes).

**Não faça:** somar mais asserções negativas sobre outras strings adivinhadas — multiplica o vácuo.
Nem relaxar a mutação por "o teste parece cobrir": a suíte verde já mentiu uma vez ali.

**Família:** irmão de `fixture-que-mente-faz-a-mutacao-mentir-junto` (o insumo mente) e do gotcha
de espião sobrescrito (o instrumento mente). Aqui quem mente é o **alvo da observação**.

**Ref:** tiatendo, 2026-09-05 — TDD do step de entrega no onboarding (`§00w`). `M-10` sobreviveu a
10 alvos; reescrever os 2 testes para `aria-label="NN% concluído"` + a frase de etapas restantes
matou a mutação (10/10). Commit `9d74f3f`.
