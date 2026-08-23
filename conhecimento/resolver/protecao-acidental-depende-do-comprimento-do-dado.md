## Quando a barreira é fuzzy por RAZÃO, a proteção depende do COMPRIMENTO do dado {#protecao-acidental-depende-do-comprimento-do-dado}

`tags: difflib, get_close_matches, cutoff, similaridade, protecao acidental, sonda com nome curto, falso verde, corpus por comprimento, escrita indevida, anotacao envelhecida`

**Sintoma.** Uma anotação diz: *"essa frase não escreve por acidente — a extração devolve um nome
embaralhado e o fuzzy não casa"*. Você confere com uma sonda, ela não escreve, e o item vira dívida
de baixa prioridade. Em produção, ele escreve todo dia.

**Causa raiz.** `difflib.get_close_matches(cutoff=0.6)` compara por **razão de caracteres**. O lixo
que sobra na extração precisa ser pequeno **em relação ao alvo** para a razão passar do corte. Ou
seja: a proteção existe ou não conforme o **comprimento do dado real**, não conforme a frase.

Medido, com frase e valor idênticos:

```
alvo "Banco"          -> extraído "Errei Banco"          -> 0 matches   (parece protegido)
alvo "Financiamento"  -> extraído "Errei Financiamento"  -> 1 match     -> ESCREVE
```

Onze de onze frases da mesma família escreveram contra o alvo longo. E os nomes reais do produto
eram longos ("Financiamento", "Empréstimo", "Cartão Nubank") — em produção **não havia proteção
nenhuma**.

**Por que engana com tanta força.** A primeira sonda que qualquer um escreve usa o nome mais curto e
óbvio: `Banco`, `Teste`, `X`. Ela passa. A conclusão "protegido por acidente" nasce de um corpus de
tamanho **um**, e sobrevive porque ninguém tem motivo pra variar o comprimento do dado.

**Solução.**
1. Barreira fuzzy → **varra o corpus por comprimento do alvo**, não por uma amostra. Uma linha de
   sweep (frases × alvos de tamanhos diferentes) responde em segundos e derruba a suposição.
2. No teste E no smoke, escolha o dado que **derruba** a proteção acidental — o nome longo, nunca o
   curto — e **escreva por que ele está ali**. Sem isso, o próximo leitor "simplifica" pra `Banco` e
   o verde volta a ser falso.
3. Meça o **pior caso**, não o primeiro que aparece. Aqui o pior não era "registra um pagamento": era
   **quitar a dívida inteira**, porque com valor ≥ saldo o handler decidia quitação total sozinho.

**Corolário.** Anotação envelhece e às vezes envelhece **para pior**: ela descrevia como acidente
inofensivo o que era escrita destrutiva alcançável. Trate "não acontece por acidente" como hipótese
a medir, nunca como estado.
