## "Limitação conhecida" é como um defeito verde se chama {#limitacao-conhecida-e-como-defeito-verde-se-chama}

`tags: teste que congela defeito, limitacao conhecida, residuo, suite verde, red, contrato, revisao, disciplina de teste, mutacao, falso rigor`

**Sintoma:** a suíte passa inteira, a mutação mata tudo, o tracking está atualizado — e mesmo assim
o revisor reprova apontando um desfecho que o próprio projeto já tinha proibido por escrito. Ao
procurar, o desfecho está **coberto por teste**: um teste que o fixa como comportamento esperado,
muitas vezes com "LIMITACAO"/"CONHECIDO"/"RESIDUO" no nome.

**Causa raiz:** rotular como *limitação* algo que uma régua já escrita proíbe. A partir daí o teste
para de ser prova e vira proteção: ele mantém o defeito verde, some da revisão (tudo passa) e ainda
**aparenta rigor** — pior que não ter teste, porque agora existe evidência de que "foi analisado".

**O caso (tiatendo, frente N23, 2026-08-30):** dois desfechos do fluxo de pagamento —
gravar um método explicitamente negado pelo cliente, e escolher um método quando ele citou dois —
foram registrados por mim em `PENDENCIAS.md` como "limitação conhecida", com
`test_LIMITACAO_CONHECIDA_...` e asserts `intent == 1` fixando o resultado errado. Apresentei
`40/40` verdes. O revisor derrubou: a preservação autorizada era de **outra** coisa (um terceiro
intento numa frase específica), e uma spec anterior dizia literalmente *"não chamar com método
inventado/negado"*. Duas rodadas de devolutiva depois, os asserts foram **invertidos** e viraram os
REDs do conserto.

**Como distinguir limitação legítima de defeito congelado.** Antes de escrever a palavra
"limitação", procure se **alguma régua já escrita** (spec, devolutiva, ADR, requisito) proíbe aquele
desfecho. Se proíbe, não é limitação — é defeito, e o teste tem que ser **RED**.

É limitação legítima só quando o conserto exige algo **explicitamente vedado no escopo**. E aí o
teste tem obrigação de provar isso, não de afirmar: mede-se o conserto óbvio e mostra-se que ele
quebra outro contrato. No mesmo caso, o teste que sobreviveu à revisão faz exatamente isso — o corpo
dele registra a medição de que fechar a negação no primeiro token desconhecido reintroduziria o
defeito que outra trava existe para matar. Nome útil para essa família: `CUSTO_DECLARADO`, não
`LIMITACAO_CONHECIDA`.

**Por que a mutação não pega isto:** mutação mede a qualidade dos **testes**, não a do código. Um
alvo que morre prova que algum teste observa aquela linha — inclusive quando o que ele observa é o
comportamento errado. `27/27 mortos` sobre uma matriz que não contém o caso é um número sobre a
matriz, não sobre o sistema. Ver [[fixture-que-mente-faz-a-mutacao-mentir-junto]].

**Sinal de alarme barato:** teste cujo nome contém "LIMITACAO", "CONHECIDO", "ESPERADO_FALHAR",
"POR_ORA" ou "TODO", e cujo assert fixa o valor que o cliente/usuário **não** queria. Vale reler a
régua antes do próximo commit.
