## O agregado da plataforma não é um componente — somá-lo com os próprios componentes dobra tudo {#agregado-nao-e-componente}

`tags: meta ads conversions lead dobrado duplicado agregado componente action_type cpl metade`

tags: número exatamente 2x, dobrado, conversões infladas, CPL pela metade, action_type lead, lead_form, lead_pixel, onsite_conversion.lead_grouped, offsite_conversion.fb_pixel_lead, agregado somado com componente, quebra por tipo idêntica, recoleta, duas réguas na série, fronteira da janela recoletada

**Sintoma:** um número nosso é EXATAMENTE 2,00× o da plataforma (ou do relatório de outra
equipe), enquanto outra coluna da mesma linha — investimento, impressões — bate ao centavo. A
razão exata é a pista: erro de arredondamento ou de janela não produz 2,00× em várias linhas.

**Causa:** APIs de anúncio devolvem, na MESMA resposta, o TOTAL e as PARTES que o compõem. No
Meta: `lead` é o total; `offsite_conversion.fb_pixel_lead` e `onsite_conversion.lead_grouped` são
os componentes. Se o total cair no mesmo balde de um componente, o escalar soma o todo mais uma
parte dele mesmo. Numa conta que só usa um dos caminhos, total == componente → exatamente 2×.

**Como confirmar em 1 consulta:** olhe a quebra por tipo bruta, não o escalar. Se ela vier
`{"lead_form": N, "lead_pixel": N}` com valores IDÊNTICOS em toda linha, não são dois eventos —
é o mesmo contado duas vezes.

**Como corrigir sem criar o defeito inverso:** dê ao agregado um balde próprio e **prefira os
componentes**, usando o agregado apenas como FALLBACK quando não houver componente nenhum. Sem o
fallback, a conta que só reporta o total zera — o fix vira perda silenciosa de conversão.

**Três armadilhas que vêm junto:**
- **O teste pode estar fixando o defeito como contrato.** Aqui havia `counts["pixel"] == 7`
  somando `lead`=4 com `fb_pixel_lead`=3 — some o agregado com um componente e chame de esperado.
  Ver `#mock-que-espelha-o-bug`. Quando o número de um teste MUDA, decida se é regressão ou se é
  o conserto, e escreva qual dos dois no docstring.
- **O mesmo defeito costuma existir no consumidor.** O front repetia a soma. E a pertinência do
  agregado ao total **depende do resto do mapa** (só conta se não houver componente), então um
  predicado por chave não resolve — a decisão tem que ver o conjunto inteiro.
- **Ordem de deploy:** suba primeiro quem LÊ a chave nova, depois quem a ESCREVE. O inverso deixa
  o consumidor antigo recebendo uma chave que ele não classifica.

**A fronteira da série não é a data do deploy.** Se você recoletar uma janela, o dado corrigido
começa no INÍCIO DA JANELA, não no dia em que o código subiu — e qualquer trecho fora da janela
mas anterior ao deploy fica dobrado no meio. Ou você recoleta até o dia do deploy (deixando UMA
fronteira), ou modela várias. Modelar uma só e escolher a data errada classifica o dado ao
contrário. Ver `#reordenar-gate-muda-o-significado-do-contador`.

**Ref:** Paid Media Automation, 2026-08-10 (`5d66c97f`, `00f1997b`). Descoberto sem querer: o
operador pediu "ideias" a partir do PDF de um relatório de outra equipe, e cruzar aquele PDF com o
banco revelou o bug. Canário em produção antes da recoleta em massa (24 → 12 numa conta/dia, com
gasto idêntico) provou o fix antes de reescrever 328 dia/conta.
