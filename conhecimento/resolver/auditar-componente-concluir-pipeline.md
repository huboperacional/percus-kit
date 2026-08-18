## Auditei o COMPONENTE e concluí sobre o PIPELINE: diagnóstico confiante e errado, antes de existir fix {#auditar-componente-concluir-pipeline}

tags: auditoria, diagnostico errado, classificador, pipeline, medir componente isolado, severidade inflada, conselho pegou, bot, roteamento, fail-open

**Sintoma:** uma auditoria bem-feita — enumeração exaustiva, medição com chamadas reais, tabela de
achados — produz um diagnóstico **confiante e errado**. Não é achismo: houve medição. O problema é
que se mediu o COMPONENTE (o classificador, sozinho) e se concluiu sobre o SISTEMA (o pipeline).

**Caso real (Família Milionária, 2026-08-12).** Medi `classifyIntent` com chamadas reais e concluí:
"cancela a recorrência do aluguel" → rótulo `exclusao` → logo o usuário recebe menu de EXCLUIR
lançamento, e o handler certo "só é alcançável por comando". Duas afirmações, ambas falsas:
- o handler de recorrência roda ANTES do dispatch, para texto arbitrário (via `command_handler`) —
  o defeito real é **fail-open** entre dois classificadores encadeados, não rota ausente;
- a frase produz um beco SEGURO; o menu destrutivo só aparece com outra frase (sem alvo nomeado).

Consequência se tivesse seguido: o fix teria sido "criar a rota que falta" — resolvendo o sintoma
errado e deixando o fail-open vivo.

**Causa raiz:** o classificador é UMA camada. O comportamento que o usuário vê é o produto de
várias (pré-gates por keyword, sub-classificadores por objeto, guards, overrides, handler de
estado). Medir a camada dá o rótulo; só o pipeline dá o **desfecho**. E severidade é sempre
propriedade do desfecho.

**Solução:**
1. Auditoria de roteamento entrega, no mínimo, UM probe por achado rodando o **pipeline inteiro**
   (webhook → todas as camadas → estado final + mensagem final). Enumeração e medição de camada
   servem pra gerar HIPÓTESE, não veredito.
2. Enquanto não houver probe de pipeline, escreva o achado como hipótese ("o classificador rotula
   X; falta medir o desfecho"), nunca como fato.
3. Rode o probe com as VARIANTES que mudam o grounding — no caso acima, "com o objeto existindo" e
   "sem o objeto" deram desfechos diferentes, e o segundo revelou o achado que nenhuma leitura de
   código previu (bot nega algo que existe, porque procurou na tabela errada).
4. **Imprima a mensagem final, não só o estado.** O veredito automático do probe deu "ok, não
   destrutivo" enquanto o bot exibia o menu de exclusão — o assert olhava o estado da sessão e a
   leitura voltou vazia. A prova estava na mensagem impressa.

**Sinal de que você está caindo nisso:** a auditoria afirma severidade ("destrutivo", "perda de
dado") a partir de um caminho de código lido, sem um turno real observado ponta a ponta.

**Irmão (mesma família, outro momento):** [`#classificador-handoff-intercepta-antes-do-handler-fix-inalcancavel`]
— aquele é sobre o FIX nascer inalcançável; este é sobre o DIAGNÓSTICO nascer errado. Os dois têm o
mesmo remédio: exercitar o pipeline, não a função.

⚠️ **Este verbete cobre METADE do problema de encoding do 5.1 — a outra metade tem conserto
OPOSTO.** Aqui o defeito é o `.ps1` **fonte** sem BOM não parsear, e o remédio é **pôr BOM no
`.ps1`**. Quando o arquivo mal-lido é um **dado** (`.md`, `.json`), pôr BOM é justamente o conserto
errado — markdown não usa e JSON com BOM quebra parser alheio; ali quem lê é que declara o
encoding. Ver [#get-content-sem-encoding-mojibake-51](get-content-sem-encoding-mojibake-51.md).
Uma varredura de BOM em `.ps1` **não enxerga** aquela, e foi assim que ela ficou viva num hook.
