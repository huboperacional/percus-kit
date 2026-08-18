## Guard que varre o repo acusa o seu próprio git worktree como violação {#guard-acusa-o-proprio-worktree}

`tags: teste-guarda, scanner de repo, rglob, git worktree, falso positivo, suite lenta, lista de exclusao, varredura de codigo-fonte`

**Sintoma.** Um teste-guarda que varre o código-fonte do repo (procurando chave legada, mock,
import proibido, o que for) começa a falhar acusando dezenas de arquivos que você não tocou. O
conteúdo acusado é legítimo — são cópias do código real. Na mesma rodada, a suíte fica muito mais
lenta sem motivo aparente.

**Causa.** O scanner usa `Path.rglob("*")` (ou `find` equivalente) e filtra por uma lista de
diretórios ignorados **depois** de já ter caminhado. Se o procedimento do projeto manda criar git
worktree isolado **dentro** do repo (`.worktrees/<frente>`), o scanner enxerga a árvore duplicada
como fonte: cada arquivo do worktree vira "violação nova" contra a allowlist, e a caminhada dobra
(ou pior, se houver `node_modules` linkado lá dentro).

**Por que engana.** O sintoma não tem relação nenhuma com a causa. O guard reporta "chave legada do
Meta lida fora da allowlist" quando o problema é *um diretório no disco*. Dá pra perder uma
investigação inteira lendo o conteúdo acusado antes de olhar o **caminho** dele.

**Solução.** Duas coisas, e a segunda é a que resolve:
1. Adicionar `.worktrees` (e o diretório de worktree de subagente, ex. `.claude/worktrees`) à lista
   de ignorados.
2. **Trocar `rglob` + filtro por `os.walk` com poda de `dirnames` in-place** — é a poda que impede a
   descida. A lista de ignorados sozinha evita o falso-positivo mas não a varredura.

```python
for dirpath, dirnames, filenames in os.walk(REPO_ROOT):
    dirnames[:] = [d for d in dirnames if d not in SKIPPED_DIRS]   # poda, não filtro
```

**Medido (paid-media, 2026-08-11):** guard 31s-falhando → 0,74s-passando; suíte do worker inteira
5min52 → 27,9s.

**Padrão pra generalizar.** Guard que anda pelo diretório do repo em vez de perguntar ao git quais
arquivos são rastreados vai, mais cedo ou mais tarde, brigar com worktree/venv/cache/build. Ao ver
um scanner de fonte acusando arquivo que você não escreveu, **leia o CAMINHO antes do conteúdo**.
Prova barata: rode o mesmo teste DENTRO do worktree — ele passa lá, porque de lá não enxerga o pai.

**Ref:** achado 2026-08-11, sessão paid-media (frente nomenclatura). Fix em
`worker/tests/test_meta_action_type_consumers.py`, commit `9a806512`. R23.
