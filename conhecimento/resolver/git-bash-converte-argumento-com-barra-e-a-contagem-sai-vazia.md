## Git Bash converte argumento iniciado por `/` em caminho do Windows — e a contagem do `rg` sai vazia, não zero {#git-bash-converte-argumento-com-barra-e-a-contagem-sai-vazia}

`tags: git bash, msys, msys2, MSYS_NO_PATHCONV, conversao de caminho, rg, grep, contagem vazia, medicao zero, pipeline quebrado, windows, controle positivo`

**Sintoma:** uma conferência por contagem — `echo "rotas: $(rg -c '/metas' app/core/tenancy_rotas.py)"` —
imprime **nada** num arquivo que tem a string oito vezes. As contagens vizinhas, na mesma linha de comando,
saem certas. Lido às pressas, "vazio" parece "zero", e zero parece "a entrada não foi feita".

**Reprodução real** (Empresa Milionária, Task 5 da Meta PJ, 2026-09-13): o checklist do plano mandava
conferir `rg -c '/metas'` = 8. Saiu vazio; `MSYS_NO_PATHCONV=1 rg -c '/metas'` deu 8, e um controle positivo
sem a barra inicial (`rg -c 'empresas/\{empresaId\}/metas'`) também deu 8.

**Causa raiz:** o Git Bash (MSYS2) reescreve, antes de chamar um executável **nativo do Windows**, todo
argumento que parece caminho POSIX absoluto: `/metas` vira algo como `C:/Program Files/Git/metas`. O `rg` é
nativo, recebe o padrão convertido, não acha, e `rg -c` **não imprime linha nenhuma** quando não há
ocorrência. Os padrões sem barra inicial passam intactos — por isso só aquela contagem mentiu.

**Conserto:**

```bash
MSYS_NO_PATHCONV=1 rg -c '/metas' arquivo        # desliga a conversão só neste comando
rg -c 'empresas/\{empresaId\}/metas' arquivo     # ou um padrão que não começa com /
```

📌 **O que fecha a classe, e não só este caso:** toda contagem de checklist leva **controle positivo na mesma
rodada** — uma segunda medição, por outro caminho, que tem de dar o número esperado. Vazio sem controle é
indistinguível de zero.

**Relacionados:** [aspa-simples-ssh-bash-c](aspa-simples-ssh-bash-c.md) (outra reescrita silenciosa de
argumento no caminho até o executável), [tres-jeitos-de-uma-guarda-produzir-verde-falso](tres-jeitos-de-uma-guarda-produzir-verde-falso.md).
