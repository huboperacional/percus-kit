## Alvo de mutação que casa 2× não é âncora ruim: é código duplicado {#alvo-de-mutacao-que-casa-duas-vezes-e-codigo-duplicado}

`tags: mutação, PODRE, duplicação, refactor, revisão, âncora`

**Sintoma:** o script de mutação marca `PODRE` porque o trecho-alvo aparece mais de uma vez no
arquivo. A reação natural é alongar a âncora até ela casar 1× e seguir a vida.

**O que fazer:** **abra a outra ocorrência ANTES de re-apontar.** Se o trecho é código que você
acabou de escrever, o desfecho provável não é desambiguar a âncora — é **apagar o seu e reusar o
que já existia**.

Medido: um helper novo de uma linha (`", ".join(labels[:-1]) + " ou " + labels[-1]`) casou 2× — a
mesma junção já existia 400 linhas acima, num produtor que ainda carregava uma nuance que o helper
novo tinha perdido. A duplicação passou por leitura do código, TDD, 38 testes verdes e uma
regressão limpa. **A contagem de ocorrências da mutação foi o único instrumento que a viu.**

**Por que só ela vê:** a mutação lê o arquivo como TEXTO, sem respeitar as fronteiras mentais em
que o autor organiza o código. Duas linhas idênticas em funções diferentes são invisíveis para uma
revisão que lê por função, e óbvias para uma varredura textual.

🔧 **Implementação que habilita isto:** o gate do script tem que ser `texto.count(antes) != 1`, e
não `antes not in texto`. A versão que só testa presença **não detecta este caso** — ela aplica a
mutação no primeiro match e mede a função errada, em silêncio.

Ver também [[alvo-de-mutacao-pode-nascer-podre]].
