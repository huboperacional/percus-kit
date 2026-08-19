## Meça antes de projetar a tolerância: o critério certo derrubou 85 ocorrências para 2 {#medir-antes-de-projetar-a-tolerancia}

`tags: guarda, lint, teste de regressao, divida declarada, baseline, falso positivo, alarme falso, criterio de deteccao, legado, flex, layout, frontend`

**Contexto:** você vai ligar uma guarda nova (lint, teste de invariante, checagem de layout) num
código que já existe. A pergunta que aparece primeiro é *"e o legado que já viola isso?"*, e a
resposta reflexa é projetar um **mecanismo de tolerância** — lista de dívida declarada, baseline,
`// eslint-disable` em massa, quarentena.

**A armadilha:** esse mecanismo é caro, é permanente, e você o desenha **antes de saber se
precisa dele**. Pior: ele muda o desenho da guarda inteira, porque agora ela tem de distinguir
"violação nova" de "violação tolerada", ler um arquivo de exceções, e falhar quando uma exceção
fica obsoleta.

**Causa raiz:** o número de violações não é propriedade do código — é propriedade do **critério de
detecção**. Um critério largo demais conta ruído; um critério afiado conta defeito. Medido em
2026-08-19 (Empresa Milionária, guarda de layout):

| Critério | Ocorrências no repositório |
|---|---|
| qualquer nó de texto solto dentro de container `display:flex` | **85** |
| **≥2** nós de texto soltos (a frase foi *partida* por um elemento no meio) | **2** |

O primeiro conta o padrão normal — ícone ao lado de um rótulo — como se fosse defeito. O segundo
só dispara quando o `gap` do flex entra **dentro de uma frase**, que é o defeito de verdade. Com o
critério afiado, as duas ocorrências viraram correção e a guarda **nasceu verde**: nenhuma lista
de dívida foi escrita, e o mecanismo inteiro deixou de ser necessário.

**Procedimento:**
1. Escreva o **detector** primeiro, sozinho, num spec descartável que só **conta e imprime** —
   nunca falha. Rode contra o repositório inteiro.
2. Se o número for alto, **não** projete tolerância ainda: pergunte se o critério está separando
   defeito de padrão. Imprima **amostras** do que ele pegou (o texto do elemento, o seletor) —
   olhar 3 amostras diz na hora se são defeitos ou ruído.
3. Afine o critério e remeça. Repita enquanto o número cair sem perder o caso que motivou tudo.
4. Só depois de o critério estabilizar decida entre **corrigir tudo** (se der) e **tolerar**.

**Sinal de que o critério ainda está largo:** as amostras que ele imprime são coisas que você não
consertaria. Guarda que aponta o que ninguém vai corrigir é [[alarme-falso-mata-o-alarme]] — ela
nasce vermelha, alguém a desliga, e o defeito que ela existia para pegar volta a passar.

**Onde isto foi medido:** `empresa-frontend/tests/e2e/guarda-visual.spec.ts`, commit `9c277a5`.
