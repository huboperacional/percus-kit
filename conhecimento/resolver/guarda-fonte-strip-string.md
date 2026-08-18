## Guarda que lê o FONTE some junto com a string que ela procura {#guarda-fonte-strip-string}

tags: teste-guarda, guarda estrutural, regex no source, tokenize, docstring, falso-negativo,
mutation testing, anti-regressão, python, ast, teste-espelho

**Sintoma.** Você escreve um teste-guarda que lê o código-fonte e reprova a reintrodução de um
padrão proibido. Ele passa. Você reintroduz o defeito de propósito — e **ele continua passando**.
Falso-negativo silencioso: a guarda existe, dá verde, e não guarda nada.

**Contexto.** Guarda de fonte quase sempre precisa ignorar comentário e docstring, senão ela reprova
pela **explicação** do defeito que mora ao lado do código (e a reação natural de quem vê o vermelho é
apagar a documentação para "consertar"). A forma óbvia de ignorar é tokenizar e descartar
`tokenize.COMMENT` e `tokenize.STRING`.

**Causa raiz.** O padrão proibido normalmente **contém uma string literal** — `headers.get("referer")`,
`os.environ["PROD"]`, `execute("DROP ...")`. Descartar todo token `STRING` remove justamente o
argumento que a regex procura. A guarda passa a olhar `headers . get ( , )`.

Uma segunda armadilha na mesma família: reconstruir o fonte por `tok.line` **não** remove nada —
`.line` devolve a **linha física inteira**, então o comentário volta de carona em qualquer outro token
da mesma linha.

**Solução.**
1. Reconstrua a partir de `tok.string`, nunca de `tok.line`.
2. Descarte `COMMENT` sempre, mas descarte `STRING` **só quando for docstring** — string sozinha numa
   linha lógica: o token significativo anterior é `NEWLINE`/`NL`/`INDENT`/`DEDENT`/`ENCODING` e o
   seguinte é `NEWLINE`. String usada como **argumento** fica.
3. **Prove por mutação, sempre:** reintroduza o defeito, veja o vermelho, restaure, veja o verde.
   E prove o outro lado: confirme que a guarda **passa** com o comentário explicativo presente.
   Guarda que nunca foi vista reprovando não é guarda — e esta classe de defeito só aparece assim.

**Ref.** Achado em 2026-07-29 em `Paid Midia Automation`, `services/tracking/tests/test_guarda_referer_header.py`
(guarda contra a volta do fallback do header `Referer`). Ver também `#red-nunca-visto-embarca-fossil`.
