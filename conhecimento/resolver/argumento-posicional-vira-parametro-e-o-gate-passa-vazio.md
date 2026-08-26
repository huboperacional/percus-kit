## Argumento posicional vira parâmetro e o gate passa vazio — valide o parâmetro, não confie no chamador {#argumento-posicional-vira-parametro-e-o-gate-passa-vazio}

tags: R11, gate de commit, falso verde, powershell, param posicional, git diff, silencio nao e sucesso, exit code, deepseek-review, skill, LASTEXITCODE

**Sintoma:** o gate de review do R11 **satisfaz o hook de pre-commit sem ter revisado nada**. A saída é
amigável e o código de saída é 0:

```
$ deepseek-review.ps1 "diff staged: teste do gate"
[deepseek-review] Nada pra revisar (diff vazio).
exit=0
```

E havia arquivo staged — medido antes de rodar. "Diff vazio" era falso.

**Causa raiz — são DUAS coisas somadas, e nenhuma sozinha causaria o problema:**

1. `$Base` é o **primeiro parâmetro posicional** do script, e o próprio skill manda o texto de
   contexto **posicionalmente**. Então `"diff staged: ..."` virou `-Base`, e o script foi montar
   `git diff "diff staged: ...HEAD"`.
2. O helper que chama o git **silenciava stderr (`2>$null`) e ignorava `$LASTEXITCODE`**. O comando
   falhava, devolvia vazio, e o chamador leu isso como "não há diff".

A segunda é a que transforma erro em silêncio: com o stderr visível **ou** o exit code checado, a
falha teria aparecido. Silenciar o erro *e* ignorar o código de saída torna **a falha
indistinguível do caso legítimo** — e o caso legítimo ("não há o que revisar") sai 0.

**Por que passou tanto tempo:** a invocação sem argumento — a que um humano digita ao testar —
funcionava. Só a forma **documentada no skill** (com contexto) é que passava vazio. O caminho
testado e o caminho usado eram diferentes.

**Conserto (medido nos dois sentidos):**

- o helper **propaga** a falha do git em vez de devolver vazio;
- `$Base` é validado com `git rev-parse --verify --quiet "<ref>^{commit}"` antes do uso — ref
  inválido sai **2** com mensagem que diz o que fazer, nunca 0;
- stderr vai para **arquivo** e só é lido quando o comando falha. Com `2>&1` os avisos do git
  (`LF will be replaced by CRLF`) entram no texto do diff enviado ao modelo, e o portão passa a
  revisar ruído junto com o código.

```
contexto posicional -> exit 2, mensagem clara
-Base HEAD~1        -> exit 0, review real acontece
```

**A review do próprio patch achou dois defeitos no conserto**, e os dois valem como aviso: consertei
só um dos dois ramos do script bash e deixei o **mais usado** com o `2>/dev/null || true` — três
linhas abaixo do comentário que denuncia o padrão; e o `2>&1` acima. Consertar uma cópia não
conserta a classe: **grepe os ramos irmãos antes de dar o item por fechado.**

**Como aplicar em qualquer gate:**

- **Portão que não consegue medir REPROVA.** Um que sai 0 dizendo que não havia o que medir é pior
  que portão nenhum — ele produz o *registro* de uma revisão que não houve.
- Valide o parâmetro no início e falhe alto quando ele não é o que o nome promete. Não confie em
  como o chamador monta a linha: o chamador aqui era o próprio skill do kit.
- Teste a forma **documentada**, não só a que você digita. Elas divergiram por meses.
- Irmãos desta família: [runner de teste que sai 0 sem rodar nada](runner-de-teste-sai-zero-sem-rodar-nada.md)
  e [arquivo vazio escapa de checagem por awk](arquivo-vazio-escapa-de-checagem-por-awk.md).

**Medido em:** Micro Investors, 2026-08-25. Conserto em `percus-kit@14ae5d8`
(`plugin/percus-review/scripts/deepseek-review.{ps1,sh}`).
