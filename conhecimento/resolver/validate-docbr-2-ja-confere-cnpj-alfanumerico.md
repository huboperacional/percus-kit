## `validate-docbr` 2.0.0 já confere o CNPJ alfanumérico: "documento com letra não confere" tem de ser guarda nossa {#validate-docbr-2-ja-confere-cnpj-alfanumerico}

`tags: python, validate-docbr, cnpj, cnpj alfanumérico, cpf, dígito verificador, documento, receita federal, biblioteca, atualização de dependência`

**Sintoma:** o código diz que "só confere DV de documento de dígitos", e quem lê supõe que a biblioteca recusaria letra.
Na verdade quem recusa é um `if` do nosso lado. Sem ele, `CNPJ().validate("12ABC34501DE35")` devolve `True`, e o CNPJ
alfanumérico passa a "conferir" por DV, contra uma decisão de plano. Medido em 2026-09-16 com `validate-docbr==2.0.0`
(Empresa Milionária, leitura de NFS-e, Task 5, decisão DPN8).

**Medido:** `CNPJ().validate("12ABC34501DE35")` → `True` (o exemplo da Receita); `CNPJ().validate("12ABC34501DE36")` →
`False` (a biblioteca confere o DV com letra, não só aceita a forma); `CNPJ().validate("1144477700016A")` → `False`;
`CPF().validate("5299822472A")` → `False`.

**Causa raiz:** a biblioteca já implementa a regra do CNPJ alfanumérico da Receita. A suposição "é antiga e não conhece o
CNPJ novo" é falsa para a 2.0.0, e atualizar a dependência pode mudar o comportamento sem mudar o nosso código.

**Solução:**

1. Quando a regra de negócio é "com letra não confere", escreva a guarda explícita (ex.: `ehAlfanumerico`) antes de
   chamar a biblioteca.
2. Trave com **controle antes**: `assert CNPJ().validate(<alfanumérico válido>) is True` e, logo depois,
   `assert documentoConfere(<o mesmo>) is False`. Se uma versão futura deixar de aceitar, o controle avisa que o teste
   deixou de discriminar.
3. Sabote a guarda: sem ela, o teste tem de ficar vermelho na segunda asserção.
4. Quando a decisão mudar e o produto passar a aceitar CNPJ com letra, a guarda sai e a biblioteca já confere o DV.
