## Máscara de CPF, CNPJ ou linha digitável "por sequência de N dígitos" não alcança o número FORMATADO — e o nome de arquivo é onde ele chega formatado {#mascara-de-documento-por-comprimento-nao-alcanca-o-numero-formatado}

`tags: mascara, lgpd, cpf, cnpj, linha digitavel, boleto, nome de arquivo, regex, dado pessoal, registro de uso, separador, FEBRABAN, R23`

**Sintoma:** o requisito diz "mascarar toda sequência de exatamente 11 ou 14 dígitos seguidos (CPF/CNPJ) e de 44, 47 ou
48 (código de barras e linha digitável)". A implementação segue a letra, os testes com número cru passam, e o número
continua indo para o banco — porque ele chegou **com separador**. Nada falha: a função devolve um nome "mascarado" do
mesmo comprimento, e só quem olha o conteúdo percebe que 33 dígitos passaram.

**Reprodução real** (Empresa Milionária, leitura de boleto pelo painel, 2026-09-15 — achado do review cross-provider):
`mascararNomeArquivo("00190.50095 40144.816069 06809.350314 3 37370000000100.pdf")` devolvia
`"00190.50095 40144.816069 06809.350314 3 **************.pdf"`. Os blocos da impressão FEBRABAN têm 5, 5, 5, 6, 5, 6, 1 e
14 dígitos; nenhum bate 11/14/44/47/48, e só o último bloco (14) caiu por coincidência — mascarado como se fosse CNPJ. É
exatamente a forma em que apps de banco nomeiam o PDF e em que o usuário cola a linha no nome do arquivo.

**Causa raiz:** a regra foi escrita pensando no **dado** (quantos dígitos tem um CPF) e não na **forma em que ele aparece**
no canal. A spec lembrou da máscara impressa de CPF e CNPJ (`000.000.000-00`) e esqueceu a da linha digitável, que é a
mais comum de todas no nome de arquivo de boleto.

**Fix:** para cada número protegido, liste as formas impressas conhecidas e casa por **blocos com separador opcional**
(`[ ._-]*` entre eles; `/` não cabe em nome de arquivo), com lookbehind/lookahead de não-dígito nas pontas. Cobrança
5-5-5-6-5-6-1-14; arrecadação (11+1)×4; CPF 3-3-3-2; CNPJ 2-3-3-4-2. Troque só os dígitos por `*` para preservar o
comprimento. Teste com o formato que **o próprio sistema imprime** (se existe um `formatarLinhaDigitavel`, a fixture é a
saída dele) e com sublinhado no lugar de espaço. Sabote cada padrão sozinho.

⚠️ **Limite que não se fecha por regex sem contradizer a regra:** dois documentos colados sem separador
(`5299822472511444777000161`, 25 dígitos) não batem "exatamente 11 ou 14". Mascarar todo bloco ≥ 11 fecha isso e
mascara também o que a regra manda deixar (um número de pedido de 12 dígitos). Declare o limite no código e na spec em
vez de escolher em silêncio.

**Ref:** Empresa Milionária, `empresa-api/app/casos_uso/leitura_boleto_prova.py` (2026-09-15), spec
`2026-09-14-leitura-de-boleto-pelo-painel-design.md` FR-350 e D19. Irmãos:
[mascara-de-segredo-por-regex-vira-caca-a-separador](mascara-de-segredo-por-regex-vira-caca-a-separador.md) (a mesma
caça a separador, para segredo em log) e
[fator-de-vencimento-do-boleto-estourou-em-2025](fator-de-vencimento-do-boleto-estourou-em-2025.md) (formatos do boleto).
