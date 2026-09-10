## Guarda de escrita por link: POSSE decide 404, ESTADO decide 409 — juntar as duas troca o status {#guarda-de-escrita-por-link-posse-404-estado-409}

`tags: link de capacidade, magic link, ADR-0012, 404 vs 409, guarda de escrita, em maos, posse, tenancy, rota sem sessao, escopo estreito, idempotencia, segunda conclusao, RF-169`

**Contexto:** uma rota **sem sessão** (link de capacidade: o token no path é a única credencial)
precisa recusar duas coisas diferentes com dois status diferentes:

- o recurso **não é de quem tem o token** → `404` idêntico ao de "não existe" (senão o status vira
  oráculo: `403` confirmaria que o recurso alheio existe);
- o recurso **é dele, mas não pode mudar de estado agora** (já concluído, bloqueado, cancelado) →
  `409`, com a mensagem que o painel autenticado já dá.

**Causa raiz:** existia UMA função de conjunto — `etapaEstaEmMaos(pessoa, dia)` — escrita para a
LISTAGEM, que já filtrava por situação viva e por data. Reusá-la como guarda de escrita parece
economia (é "a mesma regra, num lugar só") e é a troca errada: a listagem pergunta *"o que aparece
na tela dele hoje?"* e a escrita pergunta *"ele pode mexer nisto?"*. Como o conjunto exclui o item
já concluído, a **segunda conclusão** caía na guarda de posse e respondia `404` — *"isto não existe
para você"* — a quem tinha acabado de concluir aquilo, no lugar do `409` que a spec pedia em dois
requisitos distintos.

**Por que ninguém viu antes (e este é o ponto):** o defeito **não tem sintoma no banco**. Nos dois
caminhos, `404` e `409`, nada é gravado — a duplicata que o requisito teme continua não acontecendo.
Um teste que só assertasse "não gravou duas observações" fica **verde com o status errado**. E um
teste de rota que assertasse a faixa (`4xx`, ou `not 200`) também. Só uma asserção do status EXATO
separa os dois, e ela costuma parecer preciosismo até alguém abrir a tela no celular e ler "etapa
não encontrada" sobre a etapa que está na mão da pessoa.

**Diagnóstico (a ordem que funciona):**
1. Liste as guardas da rota de escrita e pergunte de CADA uma: *ela responde sobre POSSE ou sobre
   ESTADO?* Uma guarda cujo nome tem substantivo de conjunto ("em mãos", "da fila", "do dia", "em
   aberto") quase sempre responde as duas — e é a suspeita.
2. Procure o consumidor da função de conjunto: `rg -n "<nome>" app/`. Se ela nasceu para a listagem
   e a rota de escrita é o único chamador, o acoplamento é o defeito.
3. Escreva o caso do **segundo clique** (concluir de novo, iniciar o já iniciado) e assert o status
   EXATO. Se ele der `404`, a guarda está misturada.
4. Confirme no requisito qual status é o devido: procure o RF que fala do estado, não o que fala do
   escopo. Costumam ser dois RFs diferentes, e é por isso que a mistura passa na leitura.

**Fix:** separe a condição em duas, e deixe a mais fraca na guarda:

- `_condicaoDePosse(empresaId, pessoaId)` → tenant + alocação (dela **ou** da equipe dela). Sem
  situação, sem data. É a guarda da rota: falhou → `404`.
- `_condicaoEmMaos(...)` = posse **+** situação viva **+** data. Continua sendo a regra da LISTAGEM.
- O caso de uso do painel decide o estado e levanta a exceção que vira `409`.

Depois do split, **meça o call site da função antiga**: se ela ficou sem chamador, ela é código
exportado morto com teste verde — remova, e reaponte o teste dela para a guarda VIVA. O teste
reapontado é o melhor lugar para deixar a lição, porque as linhas que mudam de `False` para `True`
(o futuro, o sem-data, o já-concluído) *são* a diferença entre as duas perguntas, escrita como
asserção.

**Sinal de que você está no caso:** a rota tem token no path, o requisito cita `404` num item e
`409` em outro, e a guarda chama uma função cujo nome descreve uma TELA.
