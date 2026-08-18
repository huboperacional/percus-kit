## O teste que deveria pegar o defeito nasceu verde porque o regex casou o bloco errado {#teste-nasce-verde-vazio-regex-primeiro-match}

`tags: teste vazio, falso verde, regex, primeiro match, Match vs Matches, anti-vacuidade, guarda de paridade, teste que nao afere nada, ancorar regex, dois blocos iguais`

**Sintoma:** você escreve um teste que extrai algo do código-fonte por regex e compara. Ele passa.
Você injeta o defeito de propósito e ele **continua passando** — ou passa limpo mas com zero itens
comparados.

**Causa raiz:** o regex casou a **primeira** ocorrência, e a primeira não é a que interessa.
Arquivos reais têm blocos parecidos: dois `case "$MODE" in` (um é o parser de argumentos), dois
`[ValidateSet(...)]` (um é de outro parâmetro), dois `switch` no mesmo script. `Match` devolve o
primeiro; o bloco certo é o segundo. O laço então itera sobre nada, e **iterar sobre nada passa em
qualquer asserção de "todos os itens satisfazem X"**.

**Solução — duas regras juntas, uma não vale sem a outra:**

1. **Ancore na coisa específica, não no formato genérico.** Ancore no identificador que só existe no
   bloco certo (`...\)\]\s*\r?\n\s*\[string\]\$CrossClaudeModel`, ou o próprio nome da variável
   atribuída), em vez de no delimitador que se repete.
2. **Guarda anti-vacuidade obrigatória.** Antes de comparar, afirme que extraiu algo:
   `$itens.Count | Should -BeGreaterThan 0`. Sem isso, o dia em que o regex parar de casar (porque
   alguém reformatou o arquivo) o teste vira decoração silenciosa.

**Verificação que fecha:** teste de mutação. Injete o defeito no arquivo, rode, confirme que
**falha**, restaure, confirme que passa. Um teste de guarda que nunca foi visto falhando não é
guarda — é esperança. Cuidado ao roteirizar a mutação: se o script que restaura o arquivo usar uma
variável de nome comum (`$p`, `$m`), o Pester pode sobrescrevê-la e o arquivo fica mutado.

**Ref:** percus-kit 6.36.3, 2026-08-16. Aconteceu **duas vezes no mesmo dia**: primeiro numa
verificação ad-hoc do `ValidateSet` (casou o `[ValidateSet]` do `$Mode`, acusou falha falsa), depois
no teste de paridade `.ps1` ↔ `.sh` (casou o primeiro `case "$MODE" in`, nasceu verde com zero
modos comparados).
