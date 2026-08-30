## Guarda que parseia código-fonte com regex lê o FORMATO, não o código — e a formatação nova cega a guarda {#guarda-com-parser-de-fonte-le-o-formato-nao-o-codigo}

`tags: guarda, teste estatico, regex, parser, migration, alembic, enum, largura, formatacao, multilinha, DOTALL, falso verde, R23`

**Sintoma:** a guarda estática (um teste que lê arquivos-fonte com regex — largura de enum em
migration, presença de DDL, padrão de import) reprova código NOVO dizendo que a coluna/declaração
"não foi encontrada em migration nenhuma" — mas ela está lá, correta, na frente dos seus olhos. Ou
pior, o modo silencioso: a guarda passa VERDE medindo só o subconjunto que o parser entendeu, e a
declaração invisível fica sem cobertura nenhuma.

**Causa raiz:** parser de fonte por regex casa um FORMATO, não uma sintaxe. Um `re.finditer`
sem `re.DOTALL` para em `\n`: `sa.Enum("a", "b", name="x", length=40)` escrito em UMA linha casa;
o MESMO código quebrado em três linhas (como qualquer formatador faz com linha longa) fica
invisível. O caso medido (Empresa Milionária, 30/08): `tests/pj/test_largura_de_enum.py` casa
`sa\.Column\(\s*["'](\w+)["']\s*,\s*sa\.Enum\((.*?)\)\s*,` — três migrations novas escreveram o
enum multilinha e as três colunas sumiram da guarda. A sorte foi a guarda ter a asserção de
completude ("toda coluna de enum do modelo tem de aparecer em alguma migration"), que transformou
o silêncio em vermelho.

**Correção:** escreva a declaração no formato que o parser lê (enum de migration em linha única,
com comentário dizendo POR QUÊ), ou ensine o parser a ler o formato novo — nunca deixe os dois
divergirem calados. E o desenho que salvou o caso vale como regra: **toda guarda-parser precisa da
asserção de completude no outro lado** (comparar o conjunto parseado contra o conjunto real do
metadata/modelo). Sem ela, formatação nova não reprova — só desliga a cobertura em silêncio, que é
o pior dos dois mundos.

**Como reconhecer a classe:** a guarda lê `read_text()` + `re.findall/finditer` sobre fonte?
Então o contrato dela é o FORMATO do texto, e esse contrato não está escrito em lugar nenhum além
do próprio regex. Documente no ponto de escrita (o comentário na migration) e confie na asserção
de completude para pegar o drift — é ela que separa "guarda que reprova errado" (irritante,
consertável) de "guarda que aprova errado" (invisível até produção).

Relacionado: [[guarda-casa-a-mensagem-nao-a-acao]] — a mesma família de defeito: a guarda casa um
TEXTO (mensagem, formato de fonte) e não o comportamento; a metade de completude é o que a mantém
falseável.
