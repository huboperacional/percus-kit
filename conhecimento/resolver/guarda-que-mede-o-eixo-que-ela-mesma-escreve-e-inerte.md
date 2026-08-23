## Guarda que mede o eixo que ela mesma escreve nasce inerte a partir da 2ª passagem {#guarda-que-mede-o-eixo-que-ela-mesma-escreve-e-inerte}

`tags: teto, guarda inerte, updated_at, efeito colateral de UPDATE, contador, worker recorrente, relogio rearmado, guarda medida um dia, R23`

**Sintoma:** o operador pede um teto ("não incomode quem está parado há mais de X"), você implementa,
o teste passa, e a guarda **funciona na primeira passagem**. Da segunda em diante ela nunca mais
barra nada — sem erro, sem log, sem sintoma. Quem olha o código lê um teto; quem olha produção vê a
guarda deixando tudo passar.

**Causa raiz:** a guarda mede um eixo (uma coluna de tempo, um contador, um carimbo) que a **própria
ação guardada ESCREVE**. Na primeira passagem o eixo ainda carrega o valor do mundo real e o teto
morde. A ação então carimba o eixo com o valor de agora — e na passagem seguinte a guarda mede o
rastro da própria ação anterior, nunca mais o mundo real. O teto vira tautologia: a condição é
sempre satisfeita porque quem a satisfez foi ela mesma.

**Medido em tiatendo (2026-08-23, frente P4 "mensagem lixo"):** o worker de recuperação de rascunho
tinha o teto de ociosidade que o operador exigiu em 20/08. A guarda e o efeito colateral estavam
**na mesma instrução SQL**:

```sql
WITH stale AS (
    SELECT o.id FROM orders o
     WHERE o.recovery_count = $3
       AND o.updated_at > NOW() - ($4 || ' hours')::interval   -- ← o TETO lê updated_at
)
UPDATE orders o
   SET recovery_count = recovery_count + 1, updated_at = NOW() -- ← e a ação ESCREVE updated_at
```

O tier 1 só existe **depois** de o tier 0 ter rodado; quando o tier 1 mede, o `updated_at` tem a
idade da cutucada anterior (~25 min), e 25 min < 3 h **sempre**. A guarda que o operador pediu vale
exatamente **metade** do que ele acha que comprou. Efeito colateral extra: o carimbo **estende a vida
do rascunho** — outras máquinas que também leem `updated_at` (limpeza, reset noturno) atrasam junto.

**Por que os testes não pegam:** o teste natural exercita a **primeira** passagem, onde a guarda
funciona. No caso medido, todos os casos do arquivo de teste do teto usavam o contador em zero — ou
seja, cobriam só o tier onde o defeito não existe. Verde legítimo, cobertura enganosa.

**Sinal barato de detecção — vale como pergunta de review:** *"a coluna que esta guarda LÊ aparece no
`SET` da mesma instrução (ou em qualquer escrita do caminho guardado)?"* Se aparece, a guarda é
inerte a partir da 2ª passagem. Um `grep` do nome da coluna dentro do próprio statement responde.

**Conserto:** separe os eixos. O carimbo de "quando eu agi" pertence a uma coluna **própria**
(`*_sent_at`, `*_last_run_at`); o eixo que a guarda mede tem que continuar significando o que ela
pensa que mede — atividade do usuário, não atividade do sistema. No caso medido o irmão do mesmo
projeto já fazia certo (o reset noturno carimba coluna própria e **não** toca `updated_at`), então
era **divergência entre dois workers**, não limitação da modelagem. Conserto = remover o token do
`SET`.

**Prova que fecha o caso — e a versão "histórica" desta receita FALHOU quando foi executada.**

> ⚠️ **CORREÇÃO MEDIDA (2026-08-23, tiatendo).** Este parágrafo dizia: *"o baseline já está no banco;
> pré-conserto `carimbo − momento_da_acao ≈ 0` em 100% das linhas; colha ANTES do deploy porque
> depois é irrecuperável"*. **Medido em PROD antes de deployar: 0 de 19 linhas.** O A/B histórico
> **não existia**, por dois motivos que se repetem em qualquer produto com conversa longa: *(1)* os
> registros da ação viviam quase todos numa **única conversa** que acumulava dezenas de entidades ao
> longo de semanas, então **não havia como parear ação com entidade** — todo `JOIN` pela conversa
> vira produto cartesiano (a 1ª tentativa cruzou UMA mensagem com 60 pedidos); *(2)* onde o carimbo
> sobreviveria, **outro processo o sobrescreveu depois** (no caso, o reset noturno). E não havia
> nenhuma entidade viva no estado necessário.

**Faça a prova CONSTRUÍDA, não garimpada** — ela é mais barata, não depende de arqueologia e não
transforma o deploy em decisão irreversível:
1. Crie a entidade pelo caminho real.
2. **Leia o carimbo no banco imediatamente**, antes de qualquer disparo.
3. Espere a guarda agir sozinha.
4. Assere **as duas coisas juntas**: que a ação ACONTECEU (log + registro + o contador próprio dela
   subindo) **e** que o carimbo **não moveu**. Sem a primeira metade, "carimbo parado" é
   indistinguível de "worker morto".

🔑 **O discriminante é a MAGNITUDE, não o sinal.** Código velho: o carimbo é escrito no claim e a
ação sai logo depois → `|delta|` de **poucos segundos**. Código novo: o carimbo fica na última
atividade real, que por definição é ≥ o piso de ociosidade → `|delta| ≥ o piso`. Medido no fechamento
desta classe: **−338,05 s** contra um piso de 300 s. Defina esse limiar **antes** do deploy, por
escrito, senão qualquer número posterior parece confirmar.

**Irmãos:** [guarda-que-isenta-remove-o-teto-que-ela-nao-ve](guarda-que-isenta-remove-o-teto-que-ela-nao-ve.md)
(o teto some porque você isentou quem mais precisava dele; aqui some porque ele mede o próprio
rastro) e a classe *"guarda medida um dia, inerte hoje porque o DADO mudou"* — a diferença é que
esta nasce inerte, não fica.
