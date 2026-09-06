## Corrigir uma classe de defeito num método NÃO a corrige no vizinho — e o comentário da correção fica visível enquanto o gêmeo passa batido {#corrigir-a-classe-num-metodo-nao-a-corrige-no-vizinho}

tags: defeito repetido, mesma classe, metodo irmao, review, guarda estreita, simbolo vs classe, refatoracao parcial, corrigir num lugar, correcao pela metade, ledger

**Contexto:** um review acha um defeito, você entende o mecanismo, corrige, escreve um comentário
explicando por que aquilo era errado, e ainda escreve uma guarda. Trabalho de primeira.

E o mesmo defeito continua no método ao lado, no mesmo arquivo, às vezes a dez linhas de
distância — com o seu comentário explicando-o visível na tela enquanto você não o vê.

**Aconteceu três vezes numa fatia só**, todas em 24 horas:

1. Corrigi uma leitura que rodava sob o contexto de tenant errado, escrevi guarda estática por
   AST para ela, sabotei, provei que mordia. A leitura **idêntica** da tabela ao lado, 130 linhas
   abaixo, ficou. A guarda procurava `select(Titulo)` — o `select(Movimento)` passou por fora.
2. Um finding apontava dois ramos de `return` mudos. Corrigi **um**, escrevi no ledger que estava
   resolvido. O revisor voltou e apontou o outro.
3. Movi um `try/except` para cobrir uma chamada de banco que escapava, com um comentário de dez
   linhas explicando o mecanismo. **Reintroduzi o mesmo defeito no método irmão**, criado na
   mesma sessão, poucas horas depois.

**Causa raiz:** corrigir é uma operação sobre um **sítio**; entender é sobre uma **classe**. As
duas acontecem ao mesmo tempo e a segunda dá a sensação de ter feito a primeira em todo lugar. E
o comentário que você acabou de escrever piora: ele documenta que a classe é conhecida, o que faz
a releitura do arquivo parecer desnecessária.

### O que fazer

**Depois de corrigir, varra a classe — não releia o arquivo.** Releitura não encontra: o olho
segue o fluxo e o gêmeo não parece novo. Varredura mecânica encontra:

```bash
# o padrao do defeito, nao o nome do sitio corrigido
rg -n 'select\(' app/casos_uso/espelhar_baixa.py     # todas as leituras, nao so a que eu corrigi
rg -n 'except Exception' app/                        # todos os tratadores, nao so o do bug
```

**Escreva a guarda sobre a CLASSE, não sobre o símbolo.** A guarda que procura um nome específico
cobre um sítio; a que procura a **forma** cobre os que ainda não existem. Uma guarda de classe
custa o mesmo e alcança o passado — num caso real, ela ficou vermelha na primeira execução
apontando um defeito idêntico numa migration **já commitada e aprovada por dois reviews**.

**Quando o achado tiver dois ramos, corrija os dois antes de escrever "resolvido".** Julgar um
finding pela metade e registrar como fechado faz o ledger afirmar mais do que o código faz — e o
ledger é o que a próxima pessoa lê.

### O custo de errar

O gêmeo sobrevive com a aparência de território já revisado. Pior: o comentário da correção vira
evidência de que alguém olhou aquilo — quem passar depois lê "isto foi tratado" e não mede.

### Sinal de que está acontecendo

Um revisor apontar duas vezes a mesma classe em lugares diferentes do mesmo diff. Não é o revisor
sendo repetitivo — é a correção tendo sido pontual nas duas vezes.
