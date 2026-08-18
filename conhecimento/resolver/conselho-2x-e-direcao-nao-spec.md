## Conselho reprova a MESMA spec 2× — remendei os RF em vez de rever a DIREÇÃO {#conselho-2x-e-direcao-nao-spec}

`tags: council, conselho, spec, analyze, ajustar, bloqueada, round 2, remendo, brainstorming, abordagens, direcao, andando em circulos`

**Contexto:** o conselho devolve `AJUSTAR`/`BLOQUEADA`, você corrige os requisitos apontados,
re-roda — e volta reprovado com CRITICAL **novo**. Você vai pro round 3. Cada round acrescenta um
requisito (RF4 → RF4b → RF10 → RF9b) e a spec engorda sem ficar melhor.

**Causa raiz:** os findings não eram defeitos da spec — eram o **custo de uma decisão de direção
que nunca foi comparada com alternativa**. O caminho arquitetural do brainstorming tem um passo
explícito, *"proponha 2-3 abordagens com trade-offs"*, e ele foi pulado. **O conselho avalia a
opção que você TROUXE**, não as que você não formulou; conselho unânime aprovando a única
alternativa considerada ainda te deixa na direção errada.

**Como reconhecer (o sinal é objetivo):** liste os findings dos 2 rounds e pergunte *"todos atacam
a mesma decisão?"*. Se sim, **a decisão é o defeito, não os requisitos** — pare de corrigir RF.

**Solução:**
1. Volte um nível e formule 2-3 abordagens de verdade, com o que cada uma resolve e **o que
   NÃO** resolve.
2. **A medição que destrava costuma ser sobre o CONTEXTO, não sobre a sua função.** No caso real
   (tiatendo F5, 13-14/08/2026), o que fechou a questão foi medir *o que o bot falou ANTES* de cada
   ocorrência do defeito: num turno o cliente respondeu **"Adicionar"** a *"Quer adicionar
   Refrigerante - 2 Litros?"* — palavra sem informação de item, que **nenhuma** esperteza de
   matcher recupera. A direção defendida por 2 rounds **não resolvia o caso mais grave**, e nem eu
   nem o conselho tinham notado porque a pergunta nunca foi feita.
3. **Partir a frente costuma ser a saída:** defesa (subtrativa, pequena, fecha rápido) + recuperação
   (o desenho difícil, com os achados já pagos herdados por escrito).
4. Prefira a mudança **SUBTRATIVA** quando existir — a que só REMOVE não precisa de guarda nova em
   cada consumidor. ⚠️ Mas **"subtrativo" não é "provado"**: quando o conselho disse que a
   propriedade não valia para uma das peças, a resposta certa foi **medir** (aplicar a mudança em
   memória sobre o corpus real e diferenciar a saída), não argumentar — e a garantia virou teste
   direto em vez de raciocínio.

**Ref:** memória `feedback_conselho_reprovando_2x_e_sinal_de_direcao_nao_de_spec`;
`loops/conselho.md` (regra de parada: teto de 2 rounds).
