# Loop: tdd — o teste nasce antes do código

**Quando:** ao começar a implementar qualquer feature ou bugfix — depois da spec, antes do
primeiro código de produção.

**Por quê nesta ordem:** teste escrito depois nasce moldado pelo código que já existe — passa
junto com o bug que deveria pegar. Só o teste-primeiro pode falhar pelo motivo certo.
(Conselho 3/3, 2026-07-20.)

## O loop

1. **Escolha um comportamento observável** da spec (o `QUANDO … O SISTEMA DEVE …`).
2. **Escreva o teste que o descreve. Rode. Tem que falhar.** Se passou, ou o comportamento
   já existe, ou o teste não testa nada — pare e descubra qual dos dois.
3. **Escreva o mínimo que faz o teste passar.** Nada além.
4. **Refatore** com o verde como rede.
5. Próximo comportamento → volta ao 1.

## Quando pular — decisão registrada, não omissão

TDD não se aplica a tudo. Pular é legítimo **se registrado**:

- protótipo de UI que vai morrer · spike exploratório · script one-shot · ajuste puramente visual.

**Como registrar:** uma linha na frente correspondente do PLANO — `tdd: pulado — <motivo>`.
O `drift.md` conta os pulos. Pulou em 9 de 10 features? Ou o loop está errado ou o projeto
está — é sinal pra auditar o desenho, não pra culpar a disciplina.

## Armadilhas

- **Teste que nunca falhou não prova nada.** O passo 2 exige *ver* a falha vermelha.
- **"Escrevo os testes no final"** não é TDD, é verificação — e cai exatamente na armadilha
  do teste moldado.
- **Saiba o que seu verde prova.** Suíte local pode skipar testes de banco (guard de
  segurança tipo dbSafety) — verde local ≠ banco provado. Rode o recorte da feature no
  gate real antes do `[5-T]`.
- **Mudança financeira:** o teste de invariante (soma-zero, idempotência) vem **antes** do
  código que escreve dinheiro — nunca depois.
