## `rg` com âncora de fim de linha contou ZERO numa linha que existe — e zero por instrumento é igual a zero por ausência {#rg-com-ancora-de-fim-de-linha-conta-zero-em-linha-que-existe}

`tags: rg, ripgrep, grep, windows, git bash, âncora, regex, medição zero, controle positivo, sabotagem, alvo, busca literal, R23`

**Sintoma:** você confere se um trecho existe antes de mexer nele — alvo de sabotagem, linha citada por um plano,
ocorrência que uma guarda deveria pegar — com `rg` e um padrão ancorado dos dois lados. A saída vem **vazia**, exit 1.
Você conclui "não existe" e muda de estratégia: troca o alvo, declara a sabotagem impossível, ou "corrige" um plano que
estava certo. Medido em 17/09/2026 (Empresa Milionária, Task 14 da leitura de NFS-e, validando o alvo da sabotagem S3),
Git Bash no Windows:

```
rg -c '^    leitura_id: uuid\.UUID \| None = None$' app/modules/pj/schemas.py   # -> nada, exit 1
rg -c '^    leitura_id: uuid\.UUID \| None = None'  app/modules/pj/schemas.py   # -> 1
grep -F -n '    leitura_id: uuid.UUID | None = None' app/modules/pj/schemas.py  # -> 80: ...
```

A única diferença entre a primeira e a segunda é o `$` final. Trocar `\|` por `[|]` não muda nada: com `$` dá zero,
sem `$` dá um.

**Causa:** não medida por dentro do `rg`. O que **está** medido é que a linha existe e termina em LF puro: o `xxd` da
linha 80 fecha em `203d 204e 6f6e 650a` (`= None` + `0a`), sem `0d`, e `cat -A` não mostra `^M`. Ou seja, **não é CRLF**,
que é a explicação intuitiva e teria sido a errada. Não invente a causa: registre o comportamento e o controle positivo.

**Por que é perigoso:** a falha vai na direção ruim. Uma busca que erra para mais deixa você conferindo achado falso —
custa tempo. Esta erra **para menos**, e "saída vazia, exit 1" é exatamente o que uma busca legítima sem resultado
produz. Não há sinal nenhum distinguindo "não existe" de "meu padrão não casou". É a mesma família de
*pipeline quebrado vira medição zero* e de *sabotagem que outra guarda absorve nunca fica vermelha*: o instrumento
devolve o número que confirma a hipótese, e nada acende.

**Solução:**

- Para conferir **existência de trecho literal**, use busca literal: `grep -F` ou `rg -F`. Regex só quando você precisa
  de regex de verdade.
- Precisou de âncora? Rode **a mesma busca sem a âncora como controle positivo**. Contagens diferentes acusam o
  instrumento, não o arquivo.
- Antes de declarar "o alvo não existe" — em sabotagem, em varredura de guarda, em contagem de ocorrências —
  **confirme com um segundo instrumento**. Um `grep -F -n` custa segundos e devolve a linha, que é prova, não contagem.
- Em script de sabotagem, prefira comparar **bytes** (`conteudo.count(alvo)`) a chamar `rg`: o script já precisa
  do byte exato para substituir, e a mesma comparação serve de conferência de unicidade.

**Verbetes relacionados:** `rg-minusculo-r-e-replace-nao-recursivo.md`, `rg-com-barra-inicial-no-git-bash-conta-vazio.md`,
`grep-c-cr-no-git-bash-mente.md`, `sabotagem-que-nao-aplica-reporta-verde.md`.
