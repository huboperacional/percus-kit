## Numerar seção nova buscando `§00x` não acha a colisão — o cabeçalho não usa o sigilo {#buscar-a-ancora-com-o-sigilo-nao-acha-o-cabecalho-sem-sigilo}

`tags: ancora, secao, numeracao, colisao, grep, sigilo, pendencias, handoff, doc longo, R23`

**Sintoma:** você vai abrir uma seção nova num doc longo (`PENDENCIAS.md`, `PLANO.md`, um RFC),
procura se o número está livre com `grep -c "§00x"`, recebe **0** (ou só as suas próprias
referências recém-escritas), conclui "livre" — e cria uma seção que **colide** com outra já
existente. Duas seções passam a ter o mesmo rótulo e conteúdos diferentes, e toda referência
`§00x` no resto do repositório fica **ambígua**.

**Por que a checagem não podia funcionar:** o doc usa o sigilo (`§`) só nas **referências**
(`ver §00x`, `→ PENDENCIAS §00x`), nunca no **cabeçalho**, que é escrito
`## 🟡 00x. Título da seção (02/09)`. Buscar `§00x` varre exatamente o conjunto que **não**
contém a definição. A checagem parece rigorosa e mede o lado errado.

🔑 **A pergunta certa não é "esse texto aparece?" e sim "onde mora a DEFINIÇÃO?"** — âncora,
número de migration, porta, ID: o que decide se está livre é o lugar que **declara**, não o que
**referencia**.

**Como resolver — varra por CABEÇALHO, não por referência:**
```bash
# lista as definições de seção que existem hoje (a fonte que decide)
grep -nE "^#{2,3} .*[[:space:]]00[a-z]+\." docs/PENDENCIAS.md
```
Só depois escolha o próximo. Confirme que o escolhido dá **zero** nos três lugares que vão citá-lo
(`grep -c "00aa" HANDOFF.md docs/PLANO.md docs/PENDENCIAS.md`) e, ao renumerar, conte as
referências e prove que **nenhuma órfã** sobrou:
```bash
grep -n "§00x" HANDOFF.md docs/PLANO.md || echo "  zero -- correto"
```

⚠️ **Numeração já colidida costuma existir antes de você chegar.** Na varredura que produziu este
verbete, `00i` aparecia **duas vezes** (20/08 e 27/08) — colisão pré-existente, de outra sessão.
Achar uma dessas **não** é motivo para reciclar o número: é motivo para registrar e escolher um
livre de verdade.

⚠️ **Letra "livre" pode ser lacuna arquivada, não vaga.** `00a` não existia como seção, mas o
alfabeto ia de `00b` a `00z` — o mais provável é que tenha sido fechada e movida pro histórico, e
referências antigas a ela ainda existirem fora do arquivo atual. Prefira **estender** a
numeração (`00aa`) a reciclar uma lacuna no meio.

**Não faça:** confiar num `grep -c` que voltou `0` sem olhar QUAL padrão você buscou; nem contar
as suas próprias linhas recém-escritas como evidência de que o número é seu (elas inflam o
contador e mascaram o zero real — foi assim que a colisão passou).

**Família:** mesma classe de `proximo-numero-de-migration-nao-e-max-da-main` (o número livre tem
mais de uma fonte) e de `migration-numero-reciclado`. Quem erra numeração raramente erra a
aritmética — erra **onde procurou**.

**Ref:** tiatendo, 2026-09-04 — deploy `0.340.0` (fix do `og:image`). A colisão passou pela minha
checagem e foi pega pela review Cross-Claude antes do commit; corrigida renumerando `00x` → `00aa`
com as 6 referências atualizadas (commit `93ac39a`).
