## Guard cego por escape comido em template literal {#guard-cego-por-escape-em-template-literal}

tags: teste, javascript, regex, falso-verde, guard

**Sintoma.** Um teste que varre CSS/config/bundle com `new RegExp(\`...\`)` passa verde
indefinidamente, ou falha com `null` em toda leitura. Nos dois casos ele não está medindo nada.

**Causa.** Em **template literal** do JS, `\s` não é escape reconhecido e vira a **letra `s`**.
`new RegExp(\`--x:\s*(#..)\`)` compila como `/--x:s*(#..)/` — "dois-pontos, zero-ou-mais letras s,
então `#`". Não casa com `--x:   #fff`, e casa por acidente com `--x:#fff`. O mesmo vale para
`\d`, `\w`, `\b`. Em `RegExp` literal (`/--x:\s*/`) o problema não existe; só em template literal.

**O que separa o vermelho honesto do verde cego.** Medido em 2026-08-23 no Micro Investors: três
ocorrências do mesmo erro, no mesmo repo. A que **falhou alto** era a única que contava o que tinha
medido (`expect(medidos).toBe(12)`). As outras duas usavam `.not.toMatch(...)` e
`if (!m) continue`, e passavam verde sendo **incapazes de detectar** o que existiam para detectar —
uma delas afirmava havia meses que tokens duplicados não tinham voltado.

**Conserto.**
1. `\\s` no template literal (ou `RegExp` literal, se não houver interpolação).
2. **Contagem obrigatória** em todo guard que varre: `expect(medidos).toBeGreaterThan(0)` no mínimo,
   e comparado a um inventário quando ele existir. Sem isso, "nada encontrado" e "não olhei"
   produzem o mesmo verde.
3. **Controle positivo** em guard de ausência: antes de afirmar "X não está lá", prove que a mesma
   expressão **acha** um Y que está. Foi o que expôs o defeito.
4. Teste **negativo** real: injete a regressão e veja o guard reprovar. Só isso prova que ele enxerga.

**Segunda cegueira, que costuma vir junto.** No mesmo teste, o recorte era
`slice(indexOf(':root'), indexOf('@layer base'))` — e no arquivo o `@layer base` vinha **antes**, com
o `:root` dentro dele. Fim menor que início ⇒ `slice` devolve **string vazia**, e nem com a regex
certa haveria onde procurar. Todo recorte por dois `indexOf` precisa de guard de ordem que **falhe
alto** (`throw`), nunca degradar para vazio.

**Como caçar a classe** (o grep ingênuo não acha, porque o shell come a barra antes): varra com um
script em arquivo procurando `new RegExp(\`` seguido de `\` + letra, **sem** barra dupla. Escrever o
script em heredoc reintroduz o mesmo bug — o heredoc do bash também come uma barra.

Relacionado: [#guard-checa-intencao-nao-alvo](guard-checa-intencao-nao-alvo.md) ·
[#guard-de-texto-acha-a-mencao-antes-do-uso](guard-de-texto-acha-a-mencao-antes-do-uso.md)
