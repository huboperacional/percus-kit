## Validador que confirma a STRING não confirma o SISTEMA {#validador-confirma-string-nao-o-sistema}

`tags: validador, monitor verde, tracking, snippet, loader.js, dominio de terceiro, 404, check decorativo, prova de sistema, string presente nao e sistema vivo`

**Sintoma:** um monitor diz `ok` sobre algo que está quebrado há semanas, e ninguém desconfia
porque "o check existe e está verde".

**Caso concreto (paid-media, 2026-08-11):** o validador de snippet de tracking procurava
`/scripts/loader.js?t=<id>` no HTML da página. O site do cliente carregava exatamente esse
caminho — só que de `track.imoveismude.com.br`, um domínio de TERCEIRO que devolvia **HTTP 404**.
O cliente passou **14 dias sem coletar um único evento** e o painel teria ficado verde o tempo
todo. A régua confirmava que a string existia; não que a tag funcionava.

**Como achar isto num validador seu:** pergunte *"o que exatamente esta asserção prova?"* e
depois *"consigo construir um caso onde ela passa e o sistema está morto?"*. Se conseguir em
menos de um minuto, o validador é decorativo. Prove rodando a função REAL contra o HTML/payload
quebrado antes de consertar — foi assim que a suspeita virou fato aqui (a função devolveu `True`).

**A classe:** identificador presente ≠ identificador ALCANÇÁVEL. Vale pra URL (host além do
caminho), import (módulo existe ≠ é o que roda), env var (definida ≠ com o valor certo), feature
flag (existe ≠ ligada), webhook (cadastrado ≠ entregando).

**Armadilha do conserto:** ao apertar a régua, não confunda DEGRADADO com QUEBRADO. Aqui o host
compartilhado continua aceito — chamá-lo piora o cookie mas a coleta funciona, e recusá-lo faria
o painel gritar "pixel ausente" sobre página que está medindo. Quem denuncia degradação é outro
elo.

**Bônus medido na mesma sessão:** a MESMA regra existia duas vezes (job Python que alerta + botão
TypeScript) e as duas **já discordavam** — a mesma página dava `ok` num lugar e "ausente" no
outro. Quando uma regra vive em duas linguagens, extraia os casos pra um **contrato JSON** que as
duas suites leem, com um teste que roda a implementação ANTIGA e exige que ela REPROVE (gate
visto reprovando). Sem isso a divergência é invisível até um cliente pagar por ela.

**Ref:** paid-media, commit `64127a7a`, contrato em `docs/contracts/snippet-validation-cases.json`.
Relacionado: "Ausência do sinal ≠ ausência do sistema" (o inverso desta). R23.
