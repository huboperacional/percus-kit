## Ausência de medição envenenando número medido {#ausencia-de-medicao-envenena-numero-medido}

tags: honestidade-de-dado, cobertura, agregacao, print-para-cliente

**Classe de sintoma:** a tela nega um fato que ela mesma exibe. "Não conseguimos medir nenhum dia"
com o gasto gravado no banco; "conta sem entrega no período" na conta que mais gastou; "o dia 02/09
não teve gasto" numa linha que imprime `≈ US$ 2.277,60`.

Medido em 2026-09-08/09 na tela *Anúncios · Resumo* (Paid Media Automation), cliente D4U. **Três
defeitos independentes, um mecanismo só** — e todos sobreviveram a quatro passadas adversariais que
já tinham "limpado" o mesmo arquivo.

### O mecanismo

Em todos os três, um dado AUSENTE de uma fonte apagou um dado PRESENTE de outra:

| defeito | a ausência | o que ela apagou |
|---|---|---|
| dia inteiro em `—` | 1 conta entre 14 sem linha de nível conta | os números das outras 13 |
| "conta sem entrega" | nenhum dia integralmente coberto | 101.323 impressões medidas daquela conta |
| "não teve gasto" | dia marcado como não-contável | as somas do dia, zeradas antes do delta |

### O erro é de DIREÇÃO, e é isso que se leva para outros projetos

Faltar dado de OUTRA parte só pode fazer a agregação **contar a menos**. Nunca autoriza afirmar que
o sujeito não fez. Duas consequências práticas:

- **Prova positiva não se apaga por ausência alheia.** Uma impressão que existe é prova de entrega;
  exigir "o dia inteiro coberto" para acreditar nela transforma incompletude nossa em acusação sobre
  o cliente.
- **Zero inventado é pior que traço.** Zerar uma soma "por segurança" e depois compará-la produz uma
  AFIRMAÇÃO ("não teve gasto"), não uma ausência. O `—` pergunta; o `0` acusa.

### A régua que substitui "tudo ou nada": COBERTURA IGUAL

O medo que originou a regra tudo-ou-nada é legítimo — somar 7 contas num dia e 12 no outro mostra um
crescimento que é só cobertura entrando. Mas a resposta certa não é esconder tudo: é **comparar
apenas coberturas iguais**.

- Chave de cobertura = conjunto do que faltou naquele período. Chaves iguais ⇒ comparável.
- O total soma os períodos da cobertura dominante e **nomeia** o que ficou de fora.
- "Completo" passa a exigir DUAS condições: todo período contado **e** nada faltando. Só a primeira
  faz sete dias parciais se declararem completos.

### 🔑 Separar "mostrar" de "contar"

O erro que reintroduziu o defeito nº 3 foi usar **uma função só** para duas perguntas diferentes:
*"este período mostra número?"* e *"este período entra no total?"*. São critérios distintos — o
primeiro é mais permissivo. Uma porta só para os dois faz a correção de um vazar para o outro.

### Como o gate falha (e como endurecer)

Dois testes verdes deixaram o defeito nº 3 chegar à tela:

- `expect(campo).not.toBeNull()` **passa para `undefined`** — aprova um campo que nem existe. Exija
  o tipo: `expect(typeof campo).toBe("number")`.
- O gate verificava que dois períodos eram *comparáveis* e qual virou base, mas **nunca que a
  variação tinha valor**. Verificar a habilitação sem verificar o resultado é verde que não prova
  nada.

E o gate que de fato pegou um erro meu foi um que já existia: *"janela que não compara não carrega
número em `deltas`"* — ele reprovou quando calculei uma fração nova sem respeitar a comparabilidade.
Ver [[assercao-de-teste-com-comparacao-nula-nao-dispara]].

### Sinal de que você está neste caso

Procure, no mesmo render, um número e uma frase que se contradizem. Se a frase for uma afirmação
sobre o sujeito ("não teve", "não entregou", "está parada") e o número disser o contrário, a causa
quase sempre é uma agregação que exigiu completude para acreditar em presença.
