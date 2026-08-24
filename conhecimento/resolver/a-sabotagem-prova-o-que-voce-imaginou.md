## A sabotagem prova o que você imaginou, não o que esqueceu {#a-sabotagem-prova-o-que-voce-imaginou}

`tags: guarda, sabotagem, mutation testing, falso verde, vacuidade, regex, cobertura, leitura linha a linha, teste de teste, disciplina`

**Contexto:** guarda nova (teste que varre código procurando uma classe de defeito) só merece
confiança depois de ser vista **falhando**. A prática correta é sabotar: plantar o defeito de
propósito, uma amostra por vez, e exigir vermelho. Isso mata o verde por vacuidade — recorte vazio,
regex que não casa, arquivo que mudou de lugar.

**O limite, e ele é estrutural:** as amostras de sabotagem saem da **mesma cabeça** que escreveu o
padrão. Elas testam as classes que você imaginou. Elas **não inventam a classe que você esqueceu**.

**Caso medido (2026-08-24):** uma guarda proibia a área logada de chamar o usuário de "familiar"
(vocabulário herdado de um produto de pessoa física). O padrão exigia **determinante** antes do
substantivo, para não casar o adjetivo legítimo (*"uma interface familiar"*):

```
\b(adicionar|editar|novo|nenhum|um|uma|o|a|do|da|ao)\s+familiar(es)?\b
```

Cinco sabotagens, **5/5 vermelhas**: determinante+parente em outro arquivo do recorte, "sua família"
sem acento, a persona de IA herdada, a regressão exata do texto corrigido, e dois falsos positivos
que tinham de passar. Guarda aprovada.

Depois do verde, **lendo o arquivo linha a linha**, apareceu:

```ts
toast.error('Erro ao carregar familiares')
```

Texto visível, no caminho de erro, **na mesma tela que a guarda existia para proteger**. Verbo, não
determinante — uma construção que nenhuma das cinco amostras tinha.

**A regra prática:** sabotagem **e** leitura, sempre, e nessa ordem.
- A **sabotagem** responde *"a guarda enxerga?"*
- A **leitura linha a linha** responde *"a guarda enxerga o suficiente?"*

Nenhuma das duas substitui a outra, e a segunda é a que costuma ser pulada porque a primeira já
deu verde — que é exatamente quando ela é mais necessária.

**Onde ler:** o arquivo que a guarda protege, inteiro, procurando o **conceito** e não o padrão.
Se a guarda proíbe uma palavra, leia todas as ocorrências dela no alvo — inclusive nas que o padrão
não casaria. Cada ocorrência que o padrão deixa passar é uma decisão: ou entra no padrão, ou vira
exceção **escrita** com a razão.

⚠️ **Sinal de que você parou cedo demais:** a contagem de amostras é redonda e todas vermelhas na
primeira tentativa. Padrão bom costuma produzir pelo menos um falso positivo que obriga a estreitar
— e estreitar é onde as classes esquecidas aparecem.

**Corolário:** quando a leitura achar o caso esquecido, **acrescente-o à sabotagem** antes de
corrigir o padrão. Senão a próxima versão do padrão volta a ser provada só contra o que você já
sabia.

Relacionado: [[comentario-sobre-a-regra-desliga-a-regra]], [[o-screenshot-pega-o-que-a-guarda-nao-ve]].
