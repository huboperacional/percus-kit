## Smoke devolve o resultado CERTO e a sua mudança nem rodou — confirme o CAMINHO, não a saída {#smoke-certo-mas-caminho-nao-rodou}

tags: smoke, 5-T, evidencia, guard, caminho-vivo, observabilidade, evento-de-qualidade,
resultado-nao-prova-mecanismo, llm-nao-deterministico, ordem-de-guards

**Sintoma:** você deploya uma guarda/fix, roda o smoke com a entrada que reproduzia o defeito, e a
saída vem **perfeita** — às vezes melhor do que você previu. Parece a prova do `[5-T]`. Não é.

**Causa raiz:** num sistema com vários caminhos que convergem pra mesma saída (N guards estruturais
+ fallback determinístico + caminho LLM), resultado bom tem muitas causas possíveis e a sua mudança
é só uma delas. Medido em 11/08 (tiatendo, C18): o carrinho saiu com os dois pratos certos e a
observação no item certo — e a guarda **nunca executou**. Os logs mostraram `ask_variant → fluxo
determinístico`, um guard que roda ANTES dela. Em 5 turnos, **3 foram interceptados por guards
anteriores**. O agravante: a saída correta é psicologicamente convincente, então é exatamente
quando você para de checar.

**Solução:**
1. **Emita evento de qualidade também no caminho FELIZ**, não só quando a guarda dispara. Foi o
   `detail='ancorado'` que permitiu distinguir "rodou e aprovou" de "nunca rodou". Guarda que só
   registra quando dispara é **indistinguível de guarda que não está no ar**.
2. Antes de declarar `[5-T]`, responda **"por qual caminho este turno passou?"** com evidência
   independente da saída: `quality_events`, linha de log, contador. Nunca pelo resultado.
3. Guarda que fica **atrás** de outros guards tem cobertura viva menor que a medida offline — o
   replay não modela quem intercepta antes. Meça a POSIÇÃO na fila, não só a regra.
4. Bug de LLM **não é determinístico**: anote o ESTADO em que reproduziu (ali: draft aberto) — é a
   única pista pra tentar de novo. 2/2 num dia, 0/5 no seguinte.

**Regra geral:** "a saída está certa" responde *o quê*, nunca *por quê*. `[5-T]` exige o *por quê*.

**Ref:** tiatendo, deploy `0.297.0` (2026-08-11), frente C18. R23.
