## Relatório com JANELA de período re-introduz viés de sobrevivência que você "já consertou" {#janela-reintroduz-vies-sobrevivencia}

tags: relatorio, janela, periodo, vies de sobrevivencia, dado censurado, media, mediana, gargalo, badge, etapa terminal, permanencia aberta, funil, cycle time

**Contexto:** relatório de "tempo médio parado por etapa". O viés de sobrevivência estava
identificado e tratado no plano: a média TEM que incluir as permanências **abertas** (`agora −
entrada`), senão quem ainda está parado — justamente o lento — fica fora e a etapa mais travada
aparece como a mais saudável.

**Causa raiz:** o plano definia a amostra como "o que ENTROU na janela". Isso conserta o viés
*dentro* da janela e o reintroduz *pela borda*: a tarefa parada há 60 dias **não entrou** numa
janela de 30 dias e **não saiu** (nunca saiu) — some do relatório inteiro. O pior caso vira
invisível justamente por ser o pior caso. Duas naturezas de bug moram aqui: o filtro que parecia
neutro (a janela) carrega a mesma assimetria que você acabou de remover do cálculo.

**Solução:** a base da média é `encerrou na janela` **∪** `segue aberta agora` — independente de
quando começou —, medindo a permanência INTEIRA (nunca a fatia dentro da janela). Corolários:
- **Declare a base de contagem de CADA campo** no docstring e na própria tela. Campos com bases
  diferentes (entrada por data de entrada, saída por data de saída) não se somam, e quem somar vai
  concluir que a tela está quebrada. Vale `amostra == saiu + ainda_aqui`; **não** vale
  `entrou == saiu + ainda_aqui`.
- **Taxa é fração da MESMA base do numerador.** `count/entrou` passa de 1 quando a etapa esvazia
  mais do que recebeu no período; `count/saiu` é limitada a 1 por construção.
- ⚠️ **Categoria TERMINAL não tem "tempo parado"** e envenena a mediana de comparação nos dois
  sentidos: recém-alimentada (média ~0) derruba a base e acusa de gargalo quem está só um pouco
  acima; envelhecida, absolve todo mundo. Tire-a da base **e** do diagnóstico.
- **Prove cada guarda por MUTAÇÃO:** reintroduza o bug e confirme que o teste específico fica
  vermelho com a mensagem certa. Foi assim que apareceu um teste que passava por **coincidência
  aritmética** (2,99 dias contra um corte de 3,0) — verde não prova que ele testa algo.

**Ref:** Plexco Tasks s150 (2026-07-26), `backend/app/services/stage_funnel.py` (as 6 armadilhas
no docstring), `backend/tests/test_stage_funnel.py`. Parente de
[#red-nunca-visto-embarca-fossil](red-nunca-visto-embarca-fossil.md).

---
