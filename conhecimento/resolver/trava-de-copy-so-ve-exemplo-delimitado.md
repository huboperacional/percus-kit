## Trava que varre COPY precisa de regra crisp, não de heurística de fim de frase {#trava-de-copy-so-ve-exemplo-delimitado}

tags: trava, copy, bot, ast, regex, r11

**Problema.** Você quer uma trava que garanta *"todo exemplo que o bot oferece na copy, o gate
aceita na entrada"* (FR-8.1). Para isso precisa EXTRAIR os exemplos do código. E aí a varredura
erra dos dois lados ao mesmo tempo.

**Erro 1 — capturar demais.** Varredura ingênua por `Ex.:` devolveu **94 achados**, e 75 não eram
promessa nenhuma: docstring (uma função documenta o padrão que detecta), prompt de LLM (few-shot
dirigido ao MODELO, não ao usuário), chave de JSON. Tratar isso como promessa gera falso-vermelho em
massa e a trava é desligada na semana seguinte.

*Solução:* dois cortes **exatos**, nunca heurísticos — docstring por **identidade do nó AST**
(`body[0]` de Module/FunctionDef/ClassDef) e literal atribuído a nome de prompt. 94 → 19. O que uma
regra exata não classifica **não é adivinhado**: sobe para uma tabela explícita com veredito humano.

**Erro 2 — tentar capturar exemplo sem delimitador.** Um review pediu que a trava também visse
`Ex.: define um teto de 500` (sem aspas). A tentativa foi "capturar do marcador até o ponto". **Não
converge:** a copy real emenda emoji, negrito e parênteses, e a varredura passou a devolver lixo
como `'35,00*) ou a nova forma de pagamento (ex: *pix'`. Cada entrada nova exigiria uma exceção
nova — o "poço sem fundo".

*Solução:* **regra crisp** — exemplo em copy tem de vir DELIMITADO (aspas, itálico, negrito). E o
vão ganha um teste próprio: literal que ANUNCIA exemplo e não delimita nenhum vira vermelho, com
teto que só encolhe. A trava deixa de depender de adivinhar português e passa a depender de uma
convenção que o autor da copy consegue seguir.

**Erro 3 — amarrar o detector a uma CONJUGAÇÃO.** Aconteceu três vezes no mesmo dia:
- `diga algo como` deixou invisíveis 5 sítios que escrevem *"basta me enviar algo como:"*;
- `exemplo\s*:` deixou invisível a copy *"Dois exemplos pra começar:"* — a trava passou VERDE sobre a
  primeira promessa escrita **depois** dela;
- no detector irmão, faltava `\b` e `envie` casava dentro de `enviei` (pretérito de quem narra).

*Solução:* marcador por **radical** + fronteira de palavra. E **fonte única**: havia duas listas de
marcador (uma para detectar o literal, outra para capturar), alarguei só uma e a trava continuou
cega — o defeito dos normalizadores duplicados em escala de duas linhas.

**Limitação que fica, e precisa ser dita.** Exemplo montado por interpolação
(`f"Ex.: {verbo} o {nome}"`) não é literal e a varredura não o vê. Avaliar `JoinedStr` inventaria
texto que nunca é enviado — pior que não ver. Documente no código.

**Teste de aceitação da própria trava.** Se ela **não reclamar** de uma copy que você acabou de
escrever com exemplo novo, **desconfie da trava, não comemore**. Foi exatamente assim que a copy
nova passou.

Ver também: [trava-vermelha-no-dia-1](trava-vermelha-no-dia-1.md) ·
[trava-por-substring-aceita-mencao](trava-por-substring-aceita-mencao.md) ·
[premissa-de-plano-tambem-e-medicao](premissa-de-plano-tambem-e-medicao.md)
