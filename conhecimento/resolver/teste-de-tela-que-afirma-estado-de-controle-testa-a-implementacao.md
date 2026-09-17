## Teste de tela que afirma estado de controle para provar regra de negócio testa a implementação, não a regra {#teste-de-tela-que-afirma-estado-de-controle-testa-a-implementacao}

`tags: e2e, playwright, tela, asserção, disabled, regra de negócio, spec, requisito, FR`

**Sintoma:** o requisito diz "nada é lido antes de o usuário escolher o tipo do documento". O teste de tela afirma que o
`input` de arquivo está **`disabled`** até a escolha. Parece a mesma coisa e não é: dois testes do mesmo arquivo passam a
se contradizer — um envia XML sem escolher nada (porque XML entra direto, pelo requisito) e o outro exige o campo
desabilitado, o que impediria o XML de entrar. Medido em 2026-09-17 (Empresa Milionária, Tasks 18 e 19 da leitura de
NFS-e), pela sessão de tela, ao implementar o que ela mesma tinha especificado.

**Causa raiz:** o requisito fala do **efeito** ("nenhuma rota é chamada"), e a asserção escolheu um **mecanismo** de tela
(`disabled`) para representá-lo. Mecanismo é decisão de implementação: trocá-lo por outro igualmente correto derruba o
teste, e mantê-lo pode impedir outro requisito.

**Solução:**

1. Afirme o efeito que o requisito descreve: zero chamadas à rota, mensagem de escolha pendente visível, arquivo não
   consumido. `disabled`, `readonly`, `aria-*` e ordem de foco são mecanismos — só entram na asserção quando o requisito
   fala deles (acessibilidade, por exemplo).
2. Quando dois testes do mesmo arquivo não podem valer juntos, um deles afirma mecanismo. Ache qual antes de "consertar"
   o produto.
3. Todo seletor que existe para dirigir comportamento pede o **par negativo**: escolher "boleto" manda o arquivo ao
   leitor de boleto. Sem ele, uma tela que ignore a escolha e sempre leia o mesmo tipo passa em todos os outros testes.
4. Vizinhos: `assercao-escrita-nao-e-assercao-que-discrimina` e `marca-de-campo-a-completar-nao-prova-que-o-campo-ficou-vazio`.
