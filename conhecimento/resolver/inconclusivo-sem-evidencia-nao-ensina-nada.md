## INCONCLUSIVO sem evidência não ensina nada — e esconde o caso em que o culpado é o harness {#inconclusivo-sem-evidencia-nao-ensina-nada}

`tags: smoke, inconclusivo, veredito, harness, evidencia, placar, LLM, nao deterministico, prova por ausencia, discriminador, producao`

**Contexto:** smoke ao vivo contra produção num caminho que depende de LLM. O desenho já é o certo —
veredito `INCONCLUSIVO` separado de `FALHOU`, saindo com exit 1 nos dois, porque "nada mudou" é
ambíguo: pode ser o fix funcionando ou a frase nunca ter alcançado o handler.

**Sintoma:** o smoke devolve `0/2 INCONCLUSIVO` e você não tem a menor ideia do porquê. Roda de
novo: `0/2` de novo. O veredito é honesto e **inútil** — ele diz que não mediu, mas não diz o que
aconteceu no lugar.

**O caso (Família Milionária, 2026-08-20):** dois `[4-C]` esperavam `[5-T]` havia cinco dias. Duas
rodadas do smoke voltaram `0/2 INCONCLUSIVO`. Ao acrescentar **uma linha** que imprimia a resposta
REAL do bot, as duas causas apareceram na mesma tela — e nenhuma era do produto:

- **os dois fixes já funcionavam.** O bot respondeu `Encontrei: *cafe* — R$ 10,00` (o alvo NOMEADO,
  não o mais recente) e `📝 Descrição: mercado → *lanche no subway*` (a ressalva aplicada);
- **o harness é que errava**, de três formas diferentes: respondia o card errado (`"cafe"` num card
  que pedia `1`/`sim`), deixava um caso contaminar o outro (a pendência **sobrevive ao `DELETE` em
  `whatsapp_sessoes`**), e conferia o banco cedo demais (após a ressalva o item ainda está
  pendente, e o card volta corrigido pedindo confirmação).

Com a instrumentação, `2/2 PASS` na rodada seguinte, sem tocar em uma linha de produto.

**O que fazer:**

- **Todo veredito imprime a EVIDÊNCIA que o produziu**, não só o rótulo. Num smoke conversacional
  isso é a fala do bot (`SELECT conteudo FROM whatsapp_logs WHERE direcao='enviado' AND criado_em >
  :t0`); num job, o stdout do processo.
- **Cuidado com onde o rastro sai.** Job rodado por `docker exec` escreve no stdout **daquele
  processo**, não no `docker logs` do container. Conferir o lugar errado reprova 2/2 com o produto
  bom — o mesmo smoke pode falhar por olhar a fonte errada.
- **Um caso não pode herdar estado do anterior.** Limpe na ABERTURA de cada caso, não entre eles:
  entre-casos só funciona se o anterior COMPLETAR, e o anterior pode sair inconclusivo — que é
  justamente quando a contaminação acontece.
- **`INCONCLUSIVO` sem evidência é indistinguível de `FALHOU` mal diagnosticado**, e o custo é
  concreto: você vai procurar defeito no produto que está certo.

**Ver também:** [[smoke-certo-mas-caminho-nao-rodou]] · [[smoke-degradado-vs-errado]] ·
[[smoke-conversacional-sessao-presa-cascateia]]
