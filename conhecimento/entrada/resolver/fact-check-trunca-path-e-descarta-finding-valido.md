## Fact-check trunca o path do finding e descarta como INFUNDADO um achado que estava certo {#fact-check-trunca-path-e-descarta-finding-valido}

`tags: fact-check, F3, R11, INFUNDADO, finding filtrado, path truncado, sem path verificavel, falso negativo de guarda, review teatro, latest.jsonl, .deepseek/reviews, ler o bruto`

**Sintoma:** a review R11 termina com `total=N confirmado=0 infundado=N` e o relatório principal sai
**vazio**. A tabela de Audit justifica tudo com *"não foi possível verificar (sem path verificável ou
arquivo ausente)"*. Parece que o modelo alucinou N vezes seguidas — e a leitura natural é seguir em
frente.

**Causa raiz:** o finding **tinha** o caminho certo. O pipeline é que o corrompeu ao extrair. Caso
medido em 2026-08-17: o `.jsonl` bruto trazia
`plugin/percus-review/hooks/external-action-guard.ps1`, e a tabela de audit mostrava
`external-action-guard.ps` — **sem o `1` final**. Com o caminho truncado o arquivo não existe, o
fact-check não consegue confirmar nada, e o veredito vira `INFUNDADO`. O achado era real e foi
corrigido depois de lido à mão.

🔑 **Por que é pior que um falso positivo:** o F3 existe para filtrar alucinação, então errar para o
lado de **descartar** é a direção que não tem alarme. Finding inventado que passa incomoda alguém e é
rejeitado na leitura; finding real que é filtrado sai do relatório e **ninguém sabe que existiu**. A
review continua "passando" com 0 findings, que é indistinguível de código limpo.

**Diagnóstico:** compare o relatório com o registro bruto, que é onde o texto original sobrevive:

```powershell
$j = Get-Content '.deepseek/reviews/latest.jsonl' -Raw -Encoding UTF8 | ConvertFrom-Json
$j.findings   # texto do provider, ANTES do fact-check
```

Se o caminho no bruto existe no disco e o da tabela de audit não, é este defeito — não alucinação.

**Solução, enquanto o pipeline não for corrigido:**
1. **`infundado == total` é sinal de alerta, não de aprovação.** Todos os findings serem descartados
   pelo mesmo motivo genérico é padrão de falha de extração, não de N alucinações independentes.
2. **Leia o `.jsonl` bruto sempre que o relatório principal vier vazio** com findings no audit. Custa
   um comando.
3. **Verifique o caminho à mão** (`Test-Path`) antes de aceitar "arquivo ausente" — o arquivo pode
   estar lá, com outro nome no relatório.

⚠️ **Não conclua "o provider está ruim" a partir de `confirmado=0`.** Nesta medição o provider acertou
um achado de concorrência (backoff de retry curto demais para contenção de lock) que o filtro jogou
fora.

**Ref:** percus-kit 6.36.7, 2026-08-17 — review do próprio commit da 6.36.7. Relacionado:
[[causa-declarada-em-achado-e-hipotese]] (mesma disciplina: a etiqueta não é a medição).
