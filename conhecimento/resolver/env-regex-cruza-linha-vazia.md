## `_env()` de `.env` com regex `\s*` cruza quebra de linha quando o valor está vazio {#env-regex-cruza-linha-vazia}

`tags: parser .env, regex value bleed, chave duplicada, valor vazio, \s inclui \n, dotenv custom, N8N_URL vira nome de outra chave, MULTILINE`

**Sintoma:** um cliente Python que lê `.env` via regex customizada (não biblioteca dotenv) devolve,
pra uma chave X, o VALOR LITERAL DO NOME da próxima chave no arquivo (ex.: `_env("N8N_URL")` devolve
`"N8N_USER="`), quando o `.env` tem a chave X duplicada com a primeira ocorrência vazia (`N8N_URL=`
sem nada depois) seguida de outra linha com o valor real mais adiante no arquivo.

**Causa raiz:** regex do tipo `^\s*NOME\s*=\s*(.+?)\s*$` com `re.MULTILINE` — o `\s*` ENTRE o `=` e o
grupo de captura inclui `\n`. Quando a linha da chave termina logo após o `=` (valor vazio), esse
`\s*` engole a quebra de linha e o motor de regex continua tentando casar `(.+?)` a partir do INÍCIO
da próxima linha — que é o texto de outra chave (`NOME_SEGUINTE=`). Como `(.+?)` só exige 1+ caractere
não-newline, ele casa com o nome da próxima chave inteiro, e o `$` (fim de linha em modo MULTILINE)
fecha o match exatamente no fim daquela linha. O bug só aparece quando (a) a chave tem uma ocorrência
VAZIA no arquivo E (b) existe uma próxima linha com conteúdo — passou despercebido em testes porque
eles sempre faziam monkeypatch da função `_env()` inteira, nunca exercitavam a regex contra um
arquivo real com esse padrão de duplicação.

**Solução:** trocar `\s*` por `[ \t]*` nos dois lados do valor
(`^[ \t]*NOME[ \t]*=[ \t]*(.+?)[ \t]*$`) — exclui `\n` da classe de espaço, então o match nunca
atravessa linha. Uma chave com valor vazio simplesmente NÃO CASA (o `(.+?)` exige 1+ char), e
`re.search` continua escaneando até achar a próxima ocorrência (populada) da mesma chave — preserva
o comportamento desejado de "pular vazia, achar a preenchida" sem o vazamento pra chave errada.
Escrever teste de regressão direto contra um arquivo `.env` real (via `tmp_path`), não só mockando
`_env()`, é o que teria pego isso antes.

**Ref:** Kommo-Disparo-WhatsApp, sessão 2026-08-05 (`lib/kommo_client.py` + `lib/n8n_client.py`,
mesma função duplicada nos dois arquivos por design do projeto).
