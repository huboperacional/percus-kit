## A marca de "já aplicado" derivada do TEXTO NOVO pula a edição em silêncio — e o script termina verde {#marca-de-ja-aplicado-derivada-do-texto-novo-pula-a-edicao-em-silencio}

`tags: idempotencia, sentinela, patch idempotente, ja aplicado, edicao pulada, instrumento de medida, controle de saida, falso verde, script de migracao de texto, tracking files, R23`

**Origem:** Empresa Milionária, 2026-09-19 — script que adotava o delta do canon Percus
(6.44.0 → 6.62.3) em `CLAUDE.md`, `AGENTS.md` e `.percus-version`.

**Contexto:** você escreve um patch idempotente de texto. Para poder rodar duas vezes sem duplicar,
ele precisa saber se a edição já está no arquivo. A tentação é **derivar a marca do próprio texto
novo** — a primeira linha dele, os N primeiros caracteres, um hash do bloco. Parece elegante:
uma fonte só, nada para manter em sincronia.

**O defeito:** quando a edição *insere no meio de um bloco* em vez de acrescentar ao fim, o texto
novo **começa pela linha original**. A marca derivada dele é então um texto que já estava no
arquivo antes de qualquer edição — e o script conclui "já aplicado" e **pula**.

Medido: das quatro edições, duas eram desse formato (uma reescrevia o cabeçalho de uma seção
inserindo um parágrafo antes do corpo; outra trocava uma linha de tabela e acrescentava outra).
As duas foram reportadas como `PULA (já aplicado)` na **primeira execução**, sobre arquivos que
nunca tinham sido tocados. O script imprimiu `VERDE` e saiu `rc=0`.

É pior do que falhar: o dry-run existia justamente para dar confiança antes de escrever, e ele
**confirmou** um estado que nunca mediu. Duas das cinco mudanças simplesmente não aconteceriam, e o
único sinal seria uma linha `PULA` no meio de outras `OK`.

**A regra:** a sentinela de idempotência é **escolhida à mão** e tem de ser texto que **só existe
depois** da edição. Nunca derivada do texto novo, porque o texto novo contém o antigo sempre que a
edição for uma inserção. Se a sentinela não estiver contida no texto novo, o script deve morrer no
próprio `assert` — a marca que não entra pelo patch nunca vai casar depois.

**E não basta a sentinela: o script precisa de CONTROLE DE SAÍDA.** Depois de escrever, releia do
**disco** e exija cada sentinela presente. Sem isso, "escrevi" é uma afirmação sobre o que você
pretendia, não sobre o que o arquivo tem — e é exatamente a mesma distância que o defeito acima
explora. O controle custa uma releitura e fecha a classe inteira.

**Como pegar:** rode o dry-run contra um arquivo que você **sabe** que não tem a edição, e exija
`OK` em todas. Qualquer `PULA` na primeira execução é suspeita de instrumento, nunca resultado —
mesma leitura que se dá a uma tabela parseada com zero colunas ou a uma suíte com zero testes.

Relacionado: [[a-guarda-que-nao-pode-falhar-mora-no-instrumento]] (o aparelho de medir é o último
lugar onde se olha), [[suite-pulada-sai-zero-e-e-lida-como-verde]] (pulado lido como verde),
[[controle-positivo-por-dominio-de-falha-do-medidor]] (o controle tem de atravessar o ponto frágil),
[[conte-os-vermelhos-guarda-que-passa-vazia]].
