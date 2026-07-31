# Enforcement que não consegue sumir calado — plano 2

**Branch:** `plano2-enforcement-nao-silencioso` · **Origem:** §3.2/§4.4 do spec
`2026-07-29-migracao-percus-kit-casa-unica-design.md` (migração dos 11 hooks pro `settings.json`).

O spec pedia "mover os hooks de lugar". O diagnóstico dele estava certo e era estreito: os cinco
incidentes registrados deste kit têm a mesma forma, e não é entrega — **a coisa não aconteceu e
ninguém soube**. Gate cego vendo 33 de 105 verbetes. Três guardas respondendo verde sem rodar. Fix
inerte por cache dessincronizado. Path do catalog-publish morto desde o rename. Matcher cobrindo um
caminho de dois. Mover de lugar não fecha essa classe — só troca o lugar do próximo silêncio.

---

## ESTADO DA EXECUÇÃO (2026-07-31)

| Task | Estado | Evidência |
|---|---|---|
| 1 — medir a semântica do harness | ✅ **fechada** | `ef73a1f` · 11 itens medidos por observação · `docs/superpowers/medicoes/2026-07-31-semantica-hooks-harness.md` |
| 1b — `revalidar-medicao.ps1` | ✅ **fechada** | `ef73a1f` · provado nas 3 direções (bate / diverge / snapshot ausente) |
| 2 — manifesto como fonte única | ✅ **fechada** | `cec1a20` · `hooks-manifest.json` + 8 testes · provado por 4 mutações |
| 3 — trampolim nos wrappers | ✅ **fechada** | `ba6d294` · publicada 6.33.0 |
| 3b — publicação | ✅ **fechada** | via CLI `claude plugin update percus-review@percus-tools` |
| 3c — prova de ponta a ponta | ✅ **fechada** | com grupo de controle (ver abaixo) |
| 4 — matcher `Bash\|PowerShell` | ✅ **fechada** | `ed774dd` · na mesma publicação, porque matcher é registro |
| — conserto do conselho (fora do plano) | ✅ **fechada** | `9b28e65` · perna vazia/cortada deixou de ser `ok` |
| 7 — health check `SessionStart` | ✅ **fechada** | `8a9ab1f` · publicada 6.34.0 |
| — versão no painel de plugins | ✅ **fechada** | `5d70914` · 6.34.1 |
| **5 — canário** | ⏳ **pendente** | metade automatizável feita nos testes; a **observacional exige restart do VSCode** |
| **6 — registro pro `settings.json`** | ⏳ **pendente** | é o que faz hook novo parar de custar publicação |

**Suíte:** 253/253. **Gate V2:** `exit 0`. **Instalado:** 6.34.0 (o 6.34.1 aguarda push).

### O que a medição mudou no plano, e me desmentiu duas vezes

A Task 1 mediu 11 comportamentos que a doc oficial marca como não-documentados. Três resultados
contrariam a documentação, e **dois contrariam o que eu havia afirmado com convicção**:

1. **`${VAR}` EXPANDE** no `command` de um hook do `settings.json` — eu disse que não. Expande por
   expansão de shell do **bash** (`/usr/bin/bash` 5.2.37, não PowerShell como a doc afirma).
2. **`CLAUDE_PLUGIN_ROOT` resolve `6.32.0`**, não a `6.28.0` que a §2 do spec registrava.
3. **Plugin e `settings.json` coexistem: os dois rodam**, concorrentes, com união de bloqueios.
   Enforcement duplo saiu da conjectura — para os 3 observadores seria POST duplicado de verdade.
4. **Saída de hook que sai 0 é invisível** (stderr e stdout). Isto **mudou o desenho da Task 3**: o
   "fallback barulhento" que o pre-mortem exigiu não cabe no trampolim, porque barulho no vácuo é
   indistinguível de silêncio. O anúncio migrou para o health check da Task 7, promovendo-a de
   "peça que fecha a classe" para pré-requisito do valor da Task 3.

### Prova de que o trampolim entrega (Task 3c)

Com grupo de controle, mesma máquina, mesmo instante, editando um `.ps1` **só no kit**:

```
wrapper 6.33.0 (com trampolim)   exit=2   marca do kit presente? TRUE
wrapper 6.32.0 (sem trampolim)   exit=2   marca do kit presente? FALSE
kit restaurado, diff vazio        TRUE
```

Conserto de hook deixou de precisar do canal de publicação. Os dois continuaram barrando — o
fail-closed sobreviveu.

### O bug que o review achou e quase passou

`powershell.exe -File` de um arquivo de **0 bytes sai 0**. Script vazio não é "quebrado" para o
parser — é um script válido que não faz nada — e a guarda traduzia isso em **aprovado**. Kit
truncado no meio de um `git pull` faria as 8 guardas aprovarem tudo. O primeiro conserto (comparar
com zero) era estreito demais, e **o próprio teste mostrou**: o arquivo "vazio" tinha 3 bytes porque
a fixture grava com BOM, e arquivo só-BOM também parseia e também sai 0. Virou piso de 200 bytes,
com teste amarrando a folga (o menor hook real tem 1883).

**Resíduo declarado:** truncamento no meio que ainda parseie. Pequeno porque os 11 hooks têm o corpo
dentro de um `try{...}catch{}` — truncar no meio deixa chave desbalanceada e cai no caminho de parse,
que barra.

### A promessa que não sobreviveu

O plano dizia "esta é a única publicação". Foram **três** (6.33.0, 6.34.0, 6.34.1), e o motivo é o
próprio argumento da Task 6: **sob o regime do `hooks.json`, adicionar ou alterar qualquer hook custa
uma publicação**, porque registro só vale depois de publicado. O trampolim resolveu a entrega do
*código*; a do *registro* continua presa.

---

## O QUE FALTA

### Pendente de operação: reiniciar o VSCode

A sessão que fez o trabalho carregou o plugin antigo em memória. Ao reabrir, a linha esperada na
abertura é:

```
[percus:health] enforcement ok -- 12 hooks, codigo vindo do kit, versao 6.34.x
```

**Se aparecer**, ficam provados de uma vez, pelo caminho real do harness: o `SessionStart` novo está
fiado, o trampolim serve código do kit, e o enforcement passou a dizer o que é. **Se não aparecer**,
o health check nasceu morto — o risco nº 1 do pre-mortem — e a Task 7 não fecha de verdade.

### Task 5 — canário

A metade automatizável já vive nos testes (resolução, forma, fail-closed nos dois ramos). Falta a
**observacional**: uma ação real por evento com a **assinatura contada** em stderr. Contar a
assinatura é o que distingue um bloqueio de dois; observar o bloqueio, sozinho, não distingue.

### Task 6 — registro para o `settings.json`

Ramo **decidido pela medição**: coexistência é definida e há sintaxe de caminho confiável, então o
registro vai para o `settings.json`, com **caminho absoluto** escrito por instalador idempotente
(não depende de variável, e o `renomear-kit-local.ps1` já reescreve paths do settings no rename).

Ordem por risco, porque enforcement duplo foi **confirmado real**: as 8 guardas primeiro (duplicar
guarda é decidir duas vezes o mesmo), depois a publicação esvazia o `hooks.json`, e só então os 3
observadores — que não podem rodar em dobro.

**Cuidado medido (item 11):** `command` malformado no `settings.json` **tranca a ferramenta inteira**
(auto-lockout observado; a saída foi pela tool que o matcher não cobria). O instalador valida o JSON
**e** a existência de cada `command` em disco antes de salvar, com backup datado.

### Corrigir 4 erros no spec de 2026-07-29

1. `${PERCUS_CANON_DIR}\hooks\…` (design.md:85) — a sintaxe funciona, **o caminho não existe**: os
   hooks estão em `<kit>\plugin\percus-review\hooks\`.
2. "desativa o equivalente do plugin no mesmo commit" (§4.4 passo 5) — **inexequível**; exige publicação.
3. "sincroniza as 2 pastas de cache" (§4.4 passo 6) — obsoleto; são 4 pastas e as velhas não são
   resolvidas por nada.
4. "provar que UM bloqueio acontece" (§4.4 passo 5) — **inobservável** sem contar assinatura.

### Menores

- Verbete: a guarda R20 barra `git commit` cuja **mensagem** cita ação externa (o matcher casa a
  string inteira do comando, heredoc incluído). Acontecido e contornado por reformulação.
- Avaliar gate no caminho de **escrita** de verbete: em um único dia, 4 vezes trabalho de outra
  sessão apareceu sem `tags:` ou sem índice e travou commit alheio. O gate detecta e barra quem
  chegou depois; não impede quem escreve. O verbete `#licao-em-prosa-reincide` — escrito por uma
  dessas sessões — diz exatamente isto: lição em prosa não impede reincidência.

---

## Bloqueio externo ativo

**A chave da API do DeepSeek está inválida** (`authentication_error`, key `****6032`), desde
~19h de 2026-07-31. Isso derruba o pipeline de review de **todos os projetos Percus**, não só deste
— o R11 não consegue registrar review novo pelo caminho normal.

Contorno usado no último commit, e é o mecanismo que o próprio `percus-review-auto` usa quando o
router decide `cross-claude`: review feito pela perna Cross-Claude e registrado em
`.deepseek/reviews/latest.jsonl` com `deferred: true` e o motivo declarado. **O commit não foi sem
review; foi sem a perna que caiu.** Repor a chave desbloqueia o caminho normal.
