## Enriquecer o texto que um motor de regras analisa CONTAMINA as regras vizinhas {#enriquecer-texto-analisado-contamina-regras}

tags: enriquecer texto, concatenar contexto no prompt, motor de regras, deteccao de periodo, mes fantasma, contaminacao entre regras, efeito colateral, canal separado, handler, resolucao de alvo, fuzzy match, resposta numerada, LLM semantico, portao recusa indevida

**Sintoma.** Um handler resolve o alvo por fora (LLM semântico, escolha numerada num menu, fuzzy
match) e o motor de decisão exige que o *texto* nomeie esse alvo. A tentação é concatenar o nome
resolvido ao texto antes de chamar o motor. Funciona — até o nome do alvo conter um termo que outra
regra lê. Caso real (Família Milionária, 2026-08-13): compra chamada **"Fone de junho"** anexada ao
texto fez o detector de período enxergar um mês que o usuário nunca disse; o portão passou a exigir
uma parcela de junho e **recusou cinco parcelas vencidas**. A mesma armadilha existia com uma
recorrência "Seguro de junho" no caminho da resposta numerada.

**Causa.** O texto do usuário é a fonte de VÁRIAS regras ao mesmo tempo (é pergunta? há incerteza?
qual período?). Injetar dado do sistema nele satisfaz a regra que você queria e envenena as outras,
porque nenhuma delas sabe distinguir o que veio do usuário do que você acrescentou.

**Conserto.** Entregue o alvo resolvido por um **canal separado** que só a regra pretendida lê. Se o
motor já tem um canal de contexto ("o alvo pode vir dos últimos turnos"), use-o: é exatamente esse o
caso de uso. O texto do usuário permanece intocado e continua sendo a única fonte para pergunta,
incerteza e período.

```python
# ERRADO — o nome resolvido entra na mesma string que as outras regras leem
texto=f"{texto} {compra['descricao']}"

# CERTO — canal separado; `resolverPorPeriodo` só olha `texto`
texto=texto, contexto=[Turno("enviado", compra["descricao"])]
```

**Generalização.** Vale para qualquer pipeline em que um campo alimenta múltiplos extratores:
prompt de LLM que recebe metadados concatenados, query string que acumula filtros derivados, mensagem
de log parseada por mais de um alerta. Se você precisa dizer algo ao passo B, não escreva no canal
que A, B e C leem juntos.

**Como pegar antes de doer.** Nomeie a entidade com um termo que outra regra reconhece e veja se o
comportamento muda. No teste, escolha esse termo de forma DETERMINÍSTICA e distante do dado real
(ex.: um mês a 6 meses de distância do mês corrente), com um assert de coerência: sem isso, rodar a
suíte no mês "errado" deixa o teste verde sem exercer bloqueio nenhum.

Relacionado: [[#guarda-inalcancavel-meca-o-alcance]] (a guarda existe mas a frase não chega nela).
