## Teste que executa um hook sem isolar o `cwd` afere o estado da máquina, não o hook {#teste-de-hook-roda-na-raiz-le-estado-real}

`tags: teste nao isolado, cwd, Get-Location, Push-Location, hook, pester, suite vermelha sem mudanca de codigo, estado real do repo, .percus, autorizacao viva, falso verde, R20, external-action-guard, pasta temporaria, hooks vivos, PERCUS_CANON_DIR, hooks-manifest.json, salvar e restaurar, corrida, suite em paralelo, check registrado mas ausente`

**Sintoma:** a suíte fica vermelha de manhã e verde à tarde **sem ninguém tocar em código**. Um teste
de hook falha com "esperava bloquear, recebeu liberar" — e o mesmo teste, rodado sozinho mais tarde,
passa.

**Causa raiz:** hooks resolvem os caminhos que leem a partir de `(Get-Location).Path`. Um teste que
invoca o hook **sem trocar o diretório corrente** o executa com `cwd` = raiz do repo, então o hook lê
os arquivos de estado **reais** do checkout (autorização, config, log, cache). O resultado do teste
passa a depender do que existe no disco naquele minuto.

No caso real (percus-kit, 2026-08-17): um arquivo de autorização R20 com janela de 60 minutos estava
vivo. Suíte **361/1**. Depois de expirar, **362/0**. O teste não estava aferindo o hook — estava
aferindo a hora do dia.

🔑 **A assimetria é o que torna a classe perigosa.** Um teste que afirma **BLOQUEIA** falha alto
quando o estado real libera: você descobre. Um teste que afirma **LIBERA** passa por motivo errado —
o estado real da máquina o aprova em vez do fixture, e ele fica verde para sempre, inclusive depois
de a lógica que deveria testar ser removida. Ninguém descobre. Procure os dois, não só o que caiu.

**E há um segundo dano, que só aparece quando o hook passa a ESCREVER:** hook que grava
(log, auditoria, cache) e roda sem isolamento faz a **suíte poluir o arquivo real do repo**. Testes
deixam de ser leitura e viram escrita em produção.

**Diagnóstico:**

```bash
# quem invoca hook sem trocar de diretorio antes
grep -rn "pwsh -NoProfile -File .*hook\|powershell.*-File .*hook" tests/ | grep -v "Push-Location"
```

Confirmação decisiva: rode a suíte duas vezes com o estado real **presente** e **ausente**. Se o
conjunto de falhas muda, o isolamento é o defeito — não a lógica.

**Solução:** todo teste que **executa** um hook o faz de dentro de uma pasta temporária
(`Push-Location`/`Pop-Location` em torno da invocação), com fixture próprio. Teste que só **lê o
fonte** do hook não precisa disso; teste que o **roda**, sempre.

⚠️ **Ao reproduzir, use uma CÓPIA do repositório — nunca plante o estado real "só para testar".** No
caso concreto, plantar a autorização R20 no checkout abriria o portão de ação externa de verdade, e o
checkout é compartilhado entre sessões: a autorização criada para o seu teste valeria para a sessão do
lado. Copiar o repo sem o `.git` custa segundos e remove o risco inteiro.

**Terceiro dano, e o pior: o arquivo real é lido por hooks VIVOS (2026-09-13).** O teste "DOIS checks"
de `dispatch-post.tests.ps1` grava 2 checks sintéticos no `hooks-manifest.json` **do kit** e, no
`finally`, restaura o texto que tinha lido antes. Só que o dispatcher instalado resolve o código pelo
trampolim `PERCUS_CANON_DIR`, então **toda sessão do Claude Code da máquina** lê esse manifesto a cada
tool call. Duas consequências medidas:

1. Mesmo numa execução só, enquanto o teste roda, qualquer sessão viva recebe `check registrado mas
   AUSENTE do disco` no `PostToolUse`.
2. **Com duas suítes em paralelo, a restauração perpetua a corrupção.** A execução B leu, como se fosse
   o original, o manifesto já modificado pela A. A restaurou o verdadeiro, B restaurou o modificado, e
   os `.ps1` sintéticos foram apagados pelas duas. O manifesto ficou registrando 2 checks inexistentes,
   e os hooks de todas as sessões, inclusive a de outra janela no mesmo checkout, passaram a acusar erro
   em toda tool call até o `git checkout --` do arquivo. As duas rodadas saíram contaminadas (falhas em
   `enforcement-health`, `Hardening D1` e `wrapper .cmd`), sem relação com o código testado.

"Salvar e restaurar" não é isolamento: protege contra o próprio teste, não contra outro processo lendo
ou escrevendo o mesmo arquivo. **Enquanto esse teste não usar fixture próprio, a suíte do kit não roda
em paralelo consigo mesma**, e cada execução afeta as sessões vivas por alguns segundos.

**Ref:** percus-kit 6.36.7, 2026-08-17 — `hardening-2026-05-18.tests.ps1:100` era o único teste do
`external-action-guard` sem `Push-Location`, entre 20 que já isolavam. Relacionado:
[review-auto-grava-relativo-ao-cwd](review-auto-grava-relativo-ao-cwd.md) (mesma família de `cwd`, do lado da escrita) e
[causa-declarada-em-achado-e-hipotese](causa-declarada-em-achado-e-hipotese.md) ·
[[harness-de-teste-vaza-estado-de-processo-para-o-arquivo-seguinte]] (o vazamento dentro do mesmo
processo, entre um arquivo de teste e o seguinte).
