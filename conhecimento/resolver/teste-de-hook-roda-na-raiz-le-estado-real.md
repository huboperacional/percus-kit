## Teste que executa um hook sem isolar o `cwd` afere o estado da máquina, não o hook {#teste-de-hook-roda-na-raiz-le-estado-real}

`tags: teste nao isolado, cwd, Get-Location, Push-Location, hook, pester, suite vermelha sem mudanca de codigo, estado real do repo, .percus, autorizacao viva, falso verde, R20, external-action-guard, pasta temporaria`

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

**Ref:** percus-kit 6.36.7, 2026-08-17 — `hardening-2026-05-18.tests.ps1:100` era o único teste do
`external-action-guard` sem `Push-Location`, entre 20 que já isolavam. Relacionado:
[review-auto-grava-relativo-ao-cwd](review-auto-grava-relativo-ao-cwd.md) (mesma família de `cwd`, do lado da escrita) e
[causa-declarada-em-achado-e-hipotese](causa-declarada-em-achado-e-hipotese.md).
