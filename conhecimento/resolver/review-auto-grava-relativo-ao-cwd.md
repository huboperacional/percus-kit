## Hook pre-commit bloqueia por "review velho" logo depois de você rodar o review {#review-auto-grava-relativo-ao-cwd}

tags: percus-review-auto, pre-commit-check, latest.jsonl, R11, BLOCK, ultimo review tem N min, cwd, Get-Location, diretorio corrente, .deepseek/reviews, git root, hook nao acha registro, review fresco ignorado

**Contexto:** você roda `percus-review-auto.ps1`, ele imprime findings e termina bem — e o commit
em seguida é bloqueado pelo hook com `BLOCK: ultimo /percus-review:review tem N min (max 5)`,
apontando para um `latest.jsonl` antigo.

**Causa raiz:** `deepseek-review.ps1` grava `.deepseek/reviews/latest.jsonl` **relativo ao
diretório corrente** (`Get-Location`), enquanto o hook `pre-commit-check` procura **na raiz do
git**. Rodar o review de um subdiretório (ex.: `empresa-api/`) grava o registro fresco em
`<subdir>/.deepseek/reviews/` — que o hook nunca lê. O review rodou de verdade; o registro é que
ficou no lugar errado.

**Diagnóstico em um comando:** procure todos os registros e compare timestamps —

```bash
find . -name "latest.jsonl" -path "*deepseek*" | while read f; do ls -la "$f"; done
```

Um `latest.jsonl` fresco fora da raiz confirma a causa.

**Solução:** rode o review **sempre da raiz do repositório** e apague o `.deepseek/` órfão do
subdiretório (senão vira lixo e confunde o próximo diagnóstico). Em PowerShell:

```powershell
Set-Location "<raiz do repo>"
& pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:PERCUS_CANON_DIR\scripts\percus-review-auto.ps1"
```

**Armadilha associada:** a janela do hook é de 5 minutos — rode o review COLADO no commit, e nos
commits em blocos, conte que cada bloco pode precisar de review novo.

**Ref:** Empresa Milionária, Fase A, 2026-08-12. O review tinha rodado 2 min antes do commit e o
hook acusava 73 min — o registro fresco estava em `empresa-api/.deepseek/reviews/`.
