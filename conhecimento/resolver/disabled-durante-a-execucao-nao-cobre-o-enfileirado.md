## `disabled` durante a execução não cobre o que está enfileirado {#disabled-durante-a-execucao-nao-cobre-o-enfileirado}

`tags: react, fila, corrida, microtask, disabled, duplo clique, feedback, promise, estado derivado, UX, blur e click`

**Contexto:** para não gravar fora de ordem, serializa-se as gravações numa fila de promises, e um
booleano `ocupado` alimenta o `disabled` dos botões. O padrão parece completo e não é.

**O defeito, e ele é de construção:**

```js
const gravar = (acao) => {
  const proxima = fila.current.then(async () => {
    setOcupado(true)          // ← DENTRO do then
    try { ... } finally { setOcupado(false) }
  })
  fila.current = proxima.catch(() => undefined)   // ← isto sim é síncrono
  return proxima
}
```

`setOcupado(true)` só roda quando a gravação **chega a vez dela na fila**. Enquanto ela está apenas
**enfileirada**, `ocupado` ainda é `false`, o botão segue habilitado e o clique passa — mas a ação
demora um tempo arbitrário, sem feedback nenhum. **`ocupado` responde "gravando agora", nunca "há
gravação pendente"**, e só a segunda pergunta protege o botão.

**O gatilho real não é duplo clique humano — é `blur` → `click`.** Um campo que grava no blur
enfileira a gravação no mesmo instante em que o ponteiro vai para o botão, e entre os dois não há
renderização garantida. O usuário nem precisa ser rápido.

**Correção:** trocar o booleano por um **contador de pendências incrementado de forma síncrona** na
chamada de `gravar()`, antes de entrar na fila. Fecha a janela por construção (não há mais estado em
que existe gravação pendente e o `disabled` diz que não) e cobre fila com profundidade > 1.

**Gravidade — meça antes de escalar:** se a reatribuição de `fila.current` já é síncrona, a **ordem**
nunca correu risco; o defeito é só de **feedback**, e o segundo clique gera gravação redundante mas
correta. Não é corrupção de dado. Dizer "pode gravar fora de ordem" quando é "UX redundante" faz o
registro pedir prioridade que o fato não sustenta.

**Sobre provar empiricamente — e por que às vezes não se prova:** a fresta é uma corrida de
**microtask**, mais curta que o polling de qualquer driver de browser. Teste e2e passa nos dois
lados e dá falso conforto. O único jeito honesto é teste de unidade controlando a promise por fora
(promise deferida, chamar `gravar()`, ler o estado **antes** de resolver) — e isso exige runner de
unidade, que nem todo frontend tem. Quando não tem: fix verificável por **leitura** (é geometria,
não timing), suíte de não-regressão, e a lacuna **declarada no commit**. Lacuna registrada é melhor
que RED fabricado.

**Sintoma no teste de tela:** o `.click()` **passa** (o botão estava habilitado) e a falha cai na
**asserção seguinte**, não no clique. Foi esse detalhe que separou esta causa de "gravação em voo
travaria o clique" — que é verdadeira, e cobre outro caso.

⚠️ **Não use um teste de tela vermelho como evidência DESTE defeito — foi o erro cometido no caso
que originou este verbete.** Em 2026-09-01 atribuí a esta fila um spec que falhava, e a medição do
dia seguinte mostrou outra causa: **latência de rede por requisição**. O ambiente de teste falava
com o banco por túnel (~1,3s para conectar, ~0,5s por round-trip, contra 0,258s dentro da própria
máquina), a tela fazia DUAS chamadas por ação (grava e recarrega) e só fechava com as duas —
**15.205ms contra um orçamento de 15.000ms, errando por 200ms**. O defeito da fila era real e
independente; ele simplesmente não era o que pintava aquele teste de vermelho.

**Como separar os dois, e é barato:** meça uma chamada TRIVIAL do mesmo ambiente — um `/health`,
um `SELECT 1`. Se ela custa o mesmo que a operação real (foi o caso: 5,6–5,9s contra 5,3–6,2s), o
gargalo é transporte, não a aplicação, e nenhum conserto de estado no cliente vai mudar isso. Só
depois disso o defeito da fila se prova como se deve: **cronometrando o `disabled` do botão** —
com o contador síncrono ele fecha em t+0,5s, ou seja, no instante do clique e não quando a
gravação sai da fila.

Ver também [[fix-depois-do-teardown-herda-o-verde]].
