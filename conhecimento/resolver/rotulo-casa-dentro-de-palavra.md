## Rótulo curto casa DENTRO de outra palavra e escolhe a coisa errada (no caminho do dinheiro) {#rotulo-casa-dentro-de-palavra}

`tags: substring, fronteira de palavra, word boundary, regex, lookaround, match de rotulo, alias, sinonimo, tamanho, variante, catalogo, falso positivo, dicionario de excecoes, matcher, ILIKE, includes, indexOf, nlp`

**Sintoma:** o sistema escolhe um item/opção/rótulo que o usuário **não** citou, sem erro nenhum no
log. O texto do usuário "contém" o rótulo — mas por acidente, dentro de outra palavra.

**Caso real (tiatendo, 2026-07-31, `sabor-do-teste`):** o rótulo de variante *Torre* casou dentro de
"tor**resmo**". A frase *"quero retirar o torresmo da feijoada"* **adicionou** *Feijoada Torre —
R$ 80,00* ao carrinho, calada. Mesma classe, outras formas: "G" dentro de "**G**uaraná", "Cola"
dentro de "e**scola**", "coca" dentro de "Coca-Cola Zero", "info" dentro de "sentry**info**@".

**Causa raiz:** teste de pertinência de string cru — `rotulo in texto`, `ILIKE '%x%'`, `.includes()`,
`indexOf() >= 0` — entre **texto livre do usuário** e **rótulo curto de catálogo**. Quanto mais curto
o rótulo, maior a chance; rótulo de tamanho tem **uma letra**.

**Solução:**
1. **Fronteira de palavra, nunca substring.** Isso mata a **classe**. A alternativa — lista de
   exceções ("torresmo não é Torre") — **nunca fica pronta**: cada catálogo, tenant e idioma traz
   palavras novas, e a lista só cresce depois de cada prejuízo.
2. **Prefira lookarounds a `\b`** quando o rótulo pode terminar em caractere não-word ("P+", "1L?",
   "500ml."): `re.search(rf"(?<!\w){re.escape(needle)}(?!\w)", hay)`. Com `\b`, um rótulo terminado
   em `+` **inverte o sentido do limite** e o match aparece/some onde você não espera.
3. **Falhe FECHADO:** dúvida devolve "não casou" e o sistema **pergunta**, em vez de escolher — o
   custo de um turno a mais é menor que o de cobrar item que ninguém pediu.
4. **Prefixo não é grupo.** Declare rótulos como chaves **distintas** ("torre" × "torre e meia"),
   senão o hint de um casa o rótulo do outro. Se hoje funciona por acidente (a função devolve `None`
   pros dois), amanhã quebra: transforme o acidente em invariante travada por teste.
5. **Normalização interna não pode vazar pro usuário.** Se você colapsa "torre e meia" → `torreemeia`
   para sobreviver ao separador de chunks, **restaure** antes de ecoar — o cliente leu "torreemeia"
   na pergunta do bot.

**Como caçar:** `grep -rn " in \|ILIKE '%\|\.includes(\|\.indexOf(\|LIKE '%"` restrito aos módulos que
comparam entrada do usuário com nome/rótulo/alias de catálogo. Toda ocorrência é suspeita até provar
que os dois lados são vocabulário fechado.

**Ref:** tiatendo, `_wholeWordIn` em
`D:\Claud Automations\tiatendo\execution\engine\restaurantOrderFlow.py:154`, commit `c1ced5b`,
PROD `0.266.0`. Irmãos: [#guarda-destrutiva-testar-com-perguntas] (a mesma armadilha num guard de
remoção), [#smoke-prod-feature-llm] (conjunto fechado de formas aceitas para ref vinda de LLM),
[#classificar-formato-corrompe].
