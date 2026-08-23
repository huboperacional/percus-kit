## Hook que lê o cwd bloqueia por arquivo que existe um diretório acima {#hook-le-o-cwd-nao-a-raiz-do-git}

`tags: hooks, PreToolUse, cwd, R11, R20, pre-commit-check, external-action-guard, latest.jsonl, autorizacao, monorepo, falso bloqueio, git bash, /tmp`

**Contexto:** repositório com o backend numa subpasta (`empresa-api/`, `services/api/`, `packages/x`).
Os scripts do kit gravam e leem `.deepseek/reviews/latest.jsonl` e
`.percus/acao-externa-autorizada.json` com caminho **relativo ao diretório atual**; os hooks
`PreToolUse` os procuram **a partir do cwd da sessão**. Enquanto tudo roda na raiz, funciona.

**Os dois sintomas, e nenhum acusa a causa:**

| Hook | Mensagem | O que parece | O que é |
|---|---|---|---|
| `pre-commit-check` (R11) | *"último review tem N min (max 5)"*, e **N cresce a cada tentativa** | TTL curto demais, review lento | o review gravou em `empresa-api/.deepseek/`, e o hook lê na raiz |
| `external-action-guard` (R20) | *"ação externa pública requer aprovação explícita"* | ninguém autorizou | a autorização existe, na raiz, e o guard procura no cwd |

O primeiro é o mais enganoso: rodar o review de novo **não** resolve, e a idade subindo (7 → 8 → 20
min) faz parecer que o gate está quebrado. O segundo é intermitente por comando — o guard só casa
alguns padrões, então vários `ssh` passam e de repente um é barrado, o que joga a suspeita no comando.

**Como o cwd escorrega sem ninguém mudar de pasta:** o diretório do shell **persiste entre chamadas**,
e um comando em background ou um `cd` numa chamada anterior o move. O harness até avisa
(*"Session cwd remains …\empresa-api"*), e a linha passa batida porque parece informativa.

**Correção:** deixe o cwd da sessão **na raiz do repositório** — um `cd` sozinho, em chamada própria,
para que persista. Confira o efeito, não a intenção:

```powershell
(Get-Item ".deepseek\reviews\latest.jsonl").LastWriteTime   # na RAIZ; se não mudou, foi para outro lugar
```

**Armadilha vizinha, mesma família:** `/tmp` não é o mesmo `/tmp`. No Git Bash ele mapeia para o Temp
do Windows; em Python no Windows vira `\tmp` da unidade corrente. Arquivo escrito por `>` no shell e
lido por `open('/tmp/...')` em Python **não se encontram**, e o erro é `FileNotFoundError` sobre um
arquivo que o `wc -l` acabou de contar. Use caminho absoluto.

**Princípio geral:** hook que resolve caminho por cwd trata "onde você está" como se fosse "qual é o
projeto". Quando os dois divergem, a mensagem descreve a **política** (*"requer aprovação"*) e nunca a
**localização** — e é a localização que está errada. Ao ver um gate recusar algo que você acabou de
satisfazer, **confira de onde ele está lendo antes de refazer o que já fez**.
