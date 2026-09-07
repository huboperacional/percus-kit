## `[[wikilink]]` entre áreas (`fazer/`↔`resolver/`) não resolvia — e o exemplo que "provava" o bug estava numa linha que o gate ignora {#wikilink-so-resolve-dentro-da-mesma-area}

`tags: gate, percus-gate.sh, conhecimento, wikilink, ancora, fazer, resolver, area, slug, link morto, controle negativo, evidencia que nao reproduz, citacao, fence`

**Sintoma:** um verbete em `conhecimento/fazer/` linka um de `conhecimento/resolver/` (ou
vice-versa) via `[[slug]]`, e o gate acusa:

```
link para '[[alvo]]' nao resolve num arquivo existente (link morto nasce calado)
```

O arquivo **existe**. A mensagem manda procurar um arquivo que não existe, quando o problema
real é outro: o slug existe, só não onde o gate procurou.

**Causa raiz (medida em `v2/gates/percus-gate.sh`):** a resolução do alvo de `[[slug]]` montava
o path relativo ao diretório do **arquivo de origem**, sem nunca buscar nas áreas conhecidas:

```awk
d = FILENAME; sub(/\/[^\/]*$/, "", d)
print FILENAME "\t" d "/" alvo ".md" "\t[[" alvo "]]"
```

Se `FILENAME` é `conhecimento/fazer/X.md`, o alvo testado era sempre `conhecimento/fazer/<slug>.md`
— nunca `conhecimento/resolver/<slug>.md`, mesmo sendo lá que o slug vive. Cross-área era
impossível de resolver por construção, não por bug pontual.

**Corrigido em 6.44.3.** O ramo do wikilink passa a varrer `$_AREAS_CONHECIMENTO` antes de
acusar link morto, com duas regras:

- **precedência da própria área** — o teste no diretório da origem vem primeiro, então passar a
  resolver cross-área não mudou o destino de nenhum link que já resolvia (287 dos 288 na base);
- **ambiguidade é violação** — se o slug existe em mais de uma área fora da origem, o gate diz
  que não sabe qual, em vez de escolher no escuro; a saída é citar por caminho.

Link por caminho (`](x.md)`) **não** ganhou essa busca, e o teste que fixa isso nasceu junto:
`](x.md)` diz onde o alvo está, e afrouxar isso trocaria um falso positivo por um falso negativo.

**O exemplo que "provava" o bug não provava nada — e isto é a parte que vale mais que o fix.**
A primeira versão deste verbete citava como evidência o verbete
`achatar-a-base-antes-da-cadeia-de-delta-build-estourar-125-camadas.md` (em `fazer/`) linkando
`[[docker-build-em-cima-de-imagem-delta-bate-max-depth]]` (em `resolver/`) — "achado
independentemente por uma segunda sessão no mesmo dia". Rodando o gate **da versão anterior**
contra aquele arquivo: `EXIT=0`. Ele nunca foi barrado. A linha é esta:

```
> Irmão de [[docker-build-em-cima-de-imagem-delta-bate-max-depth]], que descreve o SINTOMA e o
```

Começa com `>`. Linha de citação é **excluída de propósito** pelo bloco de links
(`linha ~ /^[[:space:]]*>/ { next }`), junto com fence e code span, porque esta base documenta a
si mesma o tempo todo e sem essas exclusões o gate se barraria pelos próprios exemplos. Medindo a
base inteira com o gate — os ~830 verbetes, inclusive os não commitados — o total de wikilinks
acusados é **1**, e é um link genuinamente morto (o slug não existe em área nenhuma), que o gate
novo continua barrando. Casos cross-área reais hoje: **zero**.

Ou seja: a classe de defeito é real e está no código (os testes de unidade a reproduzem em
segundos), mas a frequência medida era falsa, e a investigação "confirmada por duas sessões"
confirmou uma leitura do código, não um bloqueio observado.

**O controle negativo que faltou:** antes de creditar um bug a um arquivo concreto, rode a
**versão anterior** da guarda contra aquele arquivo e veja-a falhar. É o mesmo movimento de
[[a-sabotagem-prova-o-que-voce-imaginou]] e de [[zero-so-vale-como-prova-com-controle-positivo]],
aplicado à direção oposta: não "o teste passa por coincidência?", e sim "este exemplo realmente
dispara o defeito, ou eu inferi que dispararia lendo o código?". Custa um `git show HEAD:<guarda>`
num diretório temporário.

**Princípio geral:** uma guarda com exclusões (fence, citação, code span) tem duas populações
diferentes — o que ela **poderia** acusar e o que ela **acusa**. Ler o código dá a primeira;
só rodar dá a segunda. Um exemplo colhido pela leitura pode cair inteiro dentro de uma exclusão —
e aí a evidência não é fraca, é inexistente. Vale também para o inverso, que é como esta classe
costuma aparecer: uma mensagem de erro que diz "X não existe" quando na verdade "X existe, mas eu
não sei procurar lá" mente sobre a causa e manda quem lê investigar o lugar errado.
