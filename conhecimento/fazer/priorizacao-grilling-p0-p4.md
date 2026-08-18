## Priorizar perguntas no `grilling` com P0-P4 e camadas {#priorizacao-grilling-p0-p4}

`tags: grilling, elicitacao, discovery, prioridade, P0, P1, camadas, rodadas, cobertura, escopo`

**Quando:** qualquer sessão de `v2/loops/grilling.md` — feature não-trivial ou projeto novo.

**Passos:**
1. Antes de perguntar, classifique a categoria da pergunta usando o catálogo de 14 camadas em
   `v2/referencia/discovery-camadas.md` (Problema, Atores, Aposta/Horizonte, Escala/Porte,
   Gatilhos estruturais, Fluxo, Regras de negócio, Estados, Exceções, Integrações, Operação,
   Segurança, Critérios de aceite — mais Objetivo/Resultado).
2. Priorize por `Impacto × Incerteza × Risco ÷ Custo`: P0 (muda arquitetura) e P1 (pode causar
   retrabalho) sempre antes de P3/P4 (acabamento/preferência).
3. Agrupe em rodadas de 5-8 perguntas com objetivo de 1 frase declarado.
4. Pare quando: cobertura ≥85% das camadas relevantes, zero lacunas P0, riscos P1 com decisão ou
   mitigação registrada, fluxo principal descritível ponta-a-ponta.

**Armadilhas:** tratar "já perguntei bastante" como critério de parada — é sensação, não medida.
Pular P0/P1 pra chegar mais rápido nas perguntas de acabamento é o erro mais caro: uma pergunta
de alto impacto respondida por último custa retrabalho se a resposta já tiver sido pressuposta
em decisões anteriores da mesma conversa.

**Ref:** `v2/referencia/discovery-camadas.md`; framework de origem discutido pelo operador com
GPT, cross-validado contra o MDS na mesma sessão (2026-08-04).
