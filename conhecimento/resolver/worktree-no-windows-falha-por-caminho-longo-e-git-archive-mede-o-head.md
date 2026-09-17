## `git worktree` falha no Windows com `Filename too long`; para medir o `HEAD`, `git archive` da pasta que interessa {#worktree-no-windows-falha-por-caminho-longo-e-git-archive-mede-o-head}

`tags: git worktree, git archive, filename too long, MAX_PATH, windows, medir o HEAD, falha anterior, regressao, guarda vermelha, core.longpaths, sparse-checkout`

**Contexto:** uma guarda da suíte fica vermelha acusando uma rota que o seu diff não toca. A pergunta certa
é "ela já falhava antes de mim?", e a resposta precisa ser **medida no `HEAD`**, não inferida de "meu diff não
mexe naquela pasta" (coerência não é evidência).

**Sintoma:** `git worktree add --detach <scratchpad>/wt HEAD` para no meio do checkout:

```
fatal: cannot create directory at 'empresa-frontend/src/app/(pj)/empresas/[empresaId]/relatorio/liquidacao/pago-por-cliente-ao-fornecedor': Filename too long
```

O Git **desfaz** a worktree ao falhar — mas o resto do comando encadeado segue: o `cd` para ela falha, e um
`ls` de "controle" roda no diretório ERRADO (a raiz do repositório) e responde algo que parece prova.

**Causa:** o caminho do scratchpad (`C:\Users\...\AppData\Local\Temp\claude\...`) somado a uma rota profunda do
frontend passa do limite de 260 caracteres do Windows.

**Conserto — exportar só o que a medição precisa, num caminho curto:**

```bash
EXP=/d/tmp/em-head-guarda            # caminho curto; em tar do Git Bash, /d/... e não d:/...
mkdir -p "$EXP" && git archive HEAD empresa-api | tar -x -C "$EXP"
ls "$EXP/empresa-api/app/modules/pj/rotas_novas.py"   # controle: AUSENTE prova que é o HEAD
cd "$EXP/empresa-api" && "<venv do repo>/python.exe" -m pytest "<a guarda>" -q
rm -rf "$EXP"
```

Por que `git archive` e não `sparse-checkout` numa worktree: `sparse-checkout set` numa worktree liga
`extensions.worktreeConfig` na config **compartilhada** do repositório — mexe em estado de todo mundo para uma
medição descartável. O `archive` não toca config nem índice. ⚠️ `tar -C d:/tmp/...` no Git Bash trata `d:` como
**host remoto**; use `/d/tmp/...`.

**Reprodução real** (Empresa Milionária, 2026-09-13): a guarda `test_rota_de_escrita_sem_corpo_declara_SemCorpo`
acusava uma rota da produção durante a entrega da Meta PJ. Exportado o `HEAD` anterior (`b7c5c3d`, conferido pela
AUSÊNCIA do arquivo novo), a guarda falhou igual, na mesma rota — falha anterior, provada.

**Relacionados:** [tres-jeitos-de-uma-guarda-produzir-verde-falso](tres-jeitos-de-uma-guarda-produzir-verde-falso.md).
