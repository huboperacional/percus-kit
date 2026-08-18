## "Corrigir a fixture enfraqueceria o teste" é meia-verdade — pergunte o que ele passa a medir {#fixture-corrigida-nao-enfraquece-troca-o-que-mede}

tags: corrigir enfraqueceria o teste, fixture com formato errado, golden desatualizado, glifo diferente do produtor, teste mede mundo inexistente, divida de teste, revalidar LLM pago, o que sobra depois da correcao

**Situação.** Um teste (golden, snapshot, fixture de integração) usa um dado que **não bate com o
formato que produção realmente emite** — glifo diferente, campo a mais, encoding antigo. Alguém
percebe, mede o custo de corrigir, e conclui: "corrigir muda o que o teste mede e exige revalidar;
fica como dívida". Parece disciplina (não fazer edição de carona). Muitas vezes é o contrário.

**O erro de raciocínio.** "Enfraquece" pressupõe que o que o teste mede HOJE é valioso. Se a fixture
usa um formato que produção nunca emitiu, o teste está medindo um **mundo inexistente** — o valor
dele já era zero, só que ninguém tinha olhado. Corrigir não tira valor: revela que não havia.

**A pergunta que resolve.** Antes de aceitar a dívida, calcule **o que sobra depois da correção** e
pergunte: *isso é mais próximo ou menos próximo do que produção faz hoje?*

Caso real (tiatendo, C17, 10/08): a fixture de um golden com LLM real trazia
`1x Carne Assada G - R$ 30,00` (x e hífen ASCII) enquanto o produtor emitia `1× … — R$` (U+00D7,
U+2014) havia 2 meses. A avaliação inicial foi não mexer, porque a poda de histórico recém-criada
passaria a casar aquelas linhas e "sobraria menos" pro LLM ver. Ao corrigir, o que sobrou foi
justamente o `diffPreamble` — um **quarto formato de eco que um review tinha apontado como
"não medido"**. O golden deixou de medir um cenário impossível (readback templatado na janela, que
produção agora poda) e passou a medir o vetor residual real. 5 rodadas de LLM confirmaram que ele
não contamina — e o teste virou o detector permanente daquele vetor.

**Regra prática.** Fixture divergente do produtor real é **sempre** um achado, nunca só dívida
estética. Se corrigir "muda o que o teste mede", isso é informação sobre o teste, não argumento
contra a correção.
