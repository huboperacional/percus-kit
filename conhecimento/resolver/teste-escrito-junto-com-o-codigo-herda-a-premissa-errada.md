## Teste escrito junto com o código herda a premissa errada dele {#teste-escrito-junto-com-o-codigo-herda-a-premissa-errada}

`tags: review, cross-provider, TDD, teste vácuo, premissa, copy, revisor externo, R11`

**Sintoma:** a suíte da feature está verde — 10 de 10, todos pelo caminho real, nenhum mock — e o
review cross-provider acha um defeito **grave** dentro de um dos testes verdes. Pior: o teste não
só deixava de pegar o defeito, ele **afirmava o defeito como comportamento correto**.

**Caso medido (2026-08-24):** uma regra escolhia qual lembrete de fim de trial enviar. Eu escrevi
"o bucket devido mais urgente ainda não enviado", para transformar 4 dias exatos numa janela
contínua de 5. A copy do catálogo, que eu não reli, **crava o prazo no texto** (*"termina em 5
dias"*, *"expira amanhã"*, *"TERMINA HOJE"*). No dia do vencimento o cliente receberia *"TERMINA
HOJE"* e, na mensagem seguinte, *"faltam 5 dias"* — prazo falso, em ordem anti-cronológica. E o meu
teste assertava `[-5, -3]` como resultado esperado: ele **congelava** o defeito.

**Por que os testes não pegam isso.** O teste nasceu da mesma cabeça, no mesmo dia, com a mesma
premissa ("a regra é escolher o mais urgente não enviado"). Ele verifica fielmente que o código faz
o que eu **pensei**. A premissa errada não está no código nem no teste: está **entre** os dois, no
que nenhum dos dois questiona. TDD protege contra regressão e contra código que não faz o que o
teste diz; não protege contra o teste dizer a coisa errada.

**O que fazer:**

- **Trate o review cross-provider como parte do TDD, não como formalidade pós-fato.** O valor dele
  não é "achar bug de digitação" — é ser o único participante sem a sua premissa.
- **Dê ao revisor o material que a premissa esconde.** Aqui, o que resolveu foi ele abrir o
  catálogo de copy e ler o texto real. Aponte a spec, os dados reais e o conteúdo — não só o diff.
- **Quando um finding disser que um teste seu está errado, releia o teste antes de defender o
  código.** Trava que protege o buraco é pior que trava nenhuma.

🪤 **O sinal de alerta é a suíte verde grande e nova.** Muitos testes verdes escritos na mesma
sessão medem a mesma premissa N vezes — a redundância parece cobertura e é eco.

Irmão: [[xfail-que-xpassa-anuncia-defeito-que-nao-demonstra]]
