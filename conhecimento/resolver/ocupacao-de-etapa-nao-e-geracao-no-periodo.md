## Contador de etapa mostra OCUPAÇÃO, não geração no período — e o custo por lead sai barato demais pra alguém questionar {#ocupacao-de-etapa-nao-e-geracao-no-periodo}

`tags: funil, kanban, pipeline, crm, hubspot, board, contador de coluna, ocupacao vs entrada, quem esta agora vs quem entrou, data de entrada na etapa, custo por lead, CPL, CPA, SQL, appointment, janela, denominador de epoca diferente, acumulado desde sempre, numero que o leitor quer ver, midia paga`

**Sintoma:** o número está na tela do CRM, é grande, é fácil de copiar, e responde a **outra
pergunta**. O board mostra `Qualified 39.264` e `Presentation Done 6.353` (medido em 2026-08-21,
HubSpot) — e alguém divide o gasto do mês por ele.

**Causa raiz:** o contador de uma coluna de board é **quem está na etapa AGORA**, acumulado desde
sempre. A pergunta de negócio era *"quantos SQL foram **gerados** no período"*, que é **quem
ENTROU** na etapa dentro da janela. São conjuntos diferentes, e a diferença tem sinal nos **dois**
sentidos:

- um contato qualificado em **2024** e parado ali **ainda conta hoje** — infla o denominador com
  gente de outra época;
- um contato que entrou **e avançou** **sumiu** do contador — e ele era **geração real** do período.

**Por que este número específico é perigoso:** dividir **gasto de 30 dias** por **ocupação
acumulada de vários anos** dá um custo por lead **barato de um jeito que ninguém questiona**. É o
pior tipo de número errado — não o absurdo, que alguém pega; é o número que o leitor **quer** ver.
Ele passa reunião, entra em relatório de cliente e vira base de decisão de verba.

### Como resolver

1. **Conte por DATA DE ENTRADA na etapa**, não por pertencimento à coluna. No HubSpot são as
   propriedades da família `hs_v2_date_entered_*` — e descobrir o nome delas tem armadilha própria,
   ver [nome-de-campo-de-api-concatenado-devolve-zero-em-vez-de-erro](nome-de-campo-de-api-concatenado-devolve-zero-em-vez-de-erro.md).
2. **Numerador e denominador da mesma época.** Gasto de 30 dias exige entradas dos mesmos 30 dias.
   Se um dos dois lados não tem recorte temporal, **não publique a divisão** — publique os dois
   números separados e diga que a razão não é calculável.
3. **Declare a base de contagem na própria tela**, ao lado do número: *"entraram na etapa entre
   01/08 e 21/08"* × *"estão na etapa hoje"*. Sem isso, quem somar colunas vai concluir que a tela
   está quebrada, e quem dividir vai publicar o custo falso.
4. **Trate ocupação como estoque, não como fluxo.** Ocupação responde *"onde o pipeline está
   entupido agora"* — pergunta legítima, outra pergunta.

🔑 **Generalize:** vale para **qualquer métrica de funil/kanban/pipeline lida de contador de
coluna** — CRM, board de tarefas, painel de suporte, etapas de checkout. O contador de coluna é
sempre um **estoque**; toda pergunta que contém "no período" pede **fluxo**, e fluxo só sai de data
de transição.

**Relacionado:** [janela-reintroduz-vies-sobrevivencia](janela-reintroduz-vies-sobrevivencia.md) —
o passo seguinte: depois de trocar ocupação por entrada, a **borda da janela** reintroduz o viés
pelo outro lado; [oferta-nao-e-demanda](oferta-nao-e-demanda.md) e
[agregado-nao-e-componente](agregado-nao-e-componente.md) — a mesma família de "o número existe, é
verdadeiro, e não é sobre o que você perguntou".

**Ref:** Paid Media Automation, 2026-08-21 — board de CRM (HubSpot), frente de custo por SQL.
