# R20 — autorização em lote para ações externas — Design

**Data:** 2026-08-06 · Brainstorm com `percus-review:council-brainstorm` ativo (DeepSeek + Groq-Llama).

## Motivação

O operador estava batendo em limite de rate do GitHub fazendo `git push` a cada commit, em vez de
uma vez por dia. A raiz do problema não é a regra R20 em si (push exige aprovação explícita) — é
que a aprovação, hoje, só pode ser **executada** pelo operador digitando o comando no terminal,
mesmo quando ele já autorizou verbalmente. O objetivo deste design é permitir que o **agente**
execute a ação depois de uma autorização concedida uma vez, sem recriar o problema original que a
R20 existe para evitar (agente decidindo sozinho que uma ação pública é segura).

## Por que a variável de ambiente não resolve

`external-action-guard.ps1` já tem um escape hatch — `PERCUS_EXTERNAL_OVERRIDE=1` — mas ele não
atravessa a fronteira de processo: o hook `PreToolUse` roda como processo Git Bash separado,
disparado pelo harness *antes* da chamada de ferramenta do agente, não dentro dela. Uma variável
setada pela sessão do Claude nunca chega ao processo do hook. Achado já registrado em memória
(sessão de 2026-07-31, confirmado de novo nesta sessão via `plugin/percus-review/tests/external-action-guard.tests.ps1`,
que só passa porque o teste seta a env var no MESMO processo que invoca o hook — cenário que não
existe na prática real do harness).

## Arquitetura

Arquivo em disco substitui a variável de ambiente como sinal de autorização, porque arquivo
**atravessa** a fronteira de processo — o próprio hook já prova isso, lendo
`.deepseek/council-log/*.jsonl` pra outra checagem (`premise_validity`).

```
Operador autoriza na conversa
        │
        ▼
Agente ecoa confirmação explícita ("confirma que autorizo X por 60min?")
        │
        ▼ (operador confirma)
Agente escreve .percus/acao-externa-autorizada.json
        │
        ▼
Hook PreToolUse (processo separado, disparado pelo harness)
lê o arquivo, confere idade por LastWriteTime
        │
        ├─ idade < 60min → permite a ação externa (loga motivo)
        └─ idade ≥ 60min ou ausente → cai no fluxo normal do R20 (bloqueia sem aprovação)
```

## Escopo da autorização

Cobre **todas** as ações externas que o R20 já lista (`git push`, `gh pr comment`, `gh pr
close/merge`, `gh issue close`, `slack-cli`, `mailto:`) — não só push. Decisão do operador,
tomada com essa amplitude em mente: o mesmo arquivo libera qualquer uma delas até expirar.

**Por-projeto, não global.** Autorizar no `percus-kit` não libera nada em outro repositório —
cada projeto tem seu próprio `.percus/acao-externa-autorizada.json`.

## Formato do arquivo

`.percus/acao-externa-autorizada.json` (pasta já existe, já está no `.gitignore` — mesma
convenção de `.deepseek/`):

```json
{
  "motivo": "texto livre -- o que o operador pediu/confirmou",
  "autorizado_em": "2026-08-06T14:32:00-03:00"
}
```

`autorizado_em` é informativo (aparece no log quando a autorização é usada). A janela de
validade real é calculada pelo `LastWriteTime` do arquivo em disco, não por um campo de
expiração dentro do JSON — mesmo padrão que o hook já usa para checar frescor do council log, e
mantém os dois "quão recente é isso" do mesmo arquivo (`external-action-guard.ps1`) consistentes
entre si (ambos 60 minutos).

## Mudança no hook

Em `plugin/percus-review/hooks/external-action-guard.ps1`, novo escape hatch **ao lado** do
`PERCUS_EXTERNAL_OVERRIDE` existente (os dois convivem — qualquer um dos dois libera; nenhum
substitui o outro):

```powershell
# Escape hatch: autorizacao em lote via arquivo (janela de 60min por LastWriteTime).
# Arquivo atravessa a fronteira de processo do hook; env var da sessao do Claude nao atravessa
# (achado 2026-07-31, confirmado 2026-08-06 -- ver docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md).
$authFile = Join-Path $cwd ".percus/acao-externa-autorizada.json"
if (Test-Path $authFile) {
    $idadeMin = ((Get-Date) - (Get-Item $authFile).LastWriteTime).TotalMinutes
    if ($idadeMin -lt 60) {
        $motivo = "?"
        try { $motivo = (Get-Content $authFile -Raw | ConvertFrom-Json).motivo } catch {}
        [Console]::Error.WriteLine("[percus:hook external-action-guard] autorizacao em lote ativa (motivo: $motivo, idade: $([math]::Round($idadeMin,1))min) -- permitindo.")
        exit 0
    }
}
```

Posição no arquivo: antes da checagem de `PERCUS_EXTERNAL_OVERRIDE` ou depois — ordem não importa
(são checagens independentes, qualquer uma que passar libera). Vai logo após a checagem de
`$isExternalAction`, no mesmo lugar onde o escape de env var já está hoje.

Falha ao ler/parsear o JSON (arquivo corrompido) não deve travar o hook — `try/catch` em volta da
leitura do `motivo`, com fallback `"?"` — o `Test-Path` + idade já bastam pra decidir permitir ou
não; o `motivo` é só para o log, não para a decisão.

## Comportamento do agente (não é código, mas é a parte que carrega o risco real)

1. **Nunca cria o arquivo na primeira mensagem.** Mesmo quando a intenção parecer óbvia
   ("autoriza push e o que mais precisar hoje"), o agente sempre ecoa de volta uma confirmação
   explícita antes de escrever o arquivo — decisão do council-brainstorm (2/2 rejeitaram
   reconhecimento livre sem confirmação; DeepSeek preferia frase-gatilho fixa, Llama preferia
   confirmação explícita — operador escolheu o segundo).
2. Ao criar, anuncia: motivo registrado + hora de expiração.
3. Toda vez que o agente **usa** a autorização em lote para rodar uma ação — não só quando ela é
   concedida — anuncia antes de rodar: `"usando autorização de HH:MM (motivo: X), expira HH:MM —
   rodando: <comando>"`. Nunca silencioso.
4. Revogação antecipada: se o operador pedir pra desligar antes da janela acabar, o agente apaga
   o arquivo.
5. Autorização concedida numa sessão/projeto não vale para outro (arquivo é por-projeto — decisão
   arquitetural, não só comportamental, já garantida pelo `Join-Path $cwd`).

## Testes

Seguindo o padrão já existente em `plugin/percus-review/tests/external-action-guard.tests.ps1`
(invocação direta do hook via stdin + `pwsh -File`), adicionar:

- Arquivo fresco (`LastWriteTime` recente) libera ação externa que seria bloqueada.
- Arquivo velho (`LastWriteTime` > 60min — setável via `(Get-Item $f).LastWriteTime = (Get-Date).AddMinutes(-61)`)
  é tratado como ausente — continua bloqueando.
- Arquivo ausente — comportamento atual inalterado (regressão).
- As duas escapes (env var e arquivo) funcionam independentemente — uma presente sem a outra já
  libera; nenhuma depende da outra.
- Arquivo presente mas JSON corrompido: ainda libera (idade decide, não o conteúdo), loga motivo
  como `"?"` em vez de quebrar.
- Mensagem em stderr ao usar a autorização em lote inclui o motivo registrado.
- Autorização criada num diretório não vale quando o hook roda com `cwd` diferente (prova do
  escopo por-projeto).

Testes rodam em pasta temporária isolada (nunca tocam o `.percus/` real do repo), mesmo padrão
usado em `renomear-kit-local.tests.ps1` e `registrar-hooks-settings.tests.ps1`.

## Documentação a atualizar (fora do escopo de código, mas parte do trabalho)

- `01_REGRAS_INEGOCIAVEIS.md`, seção R20 (`### Gate verificável`) — hoje só documenta a env var
  como escape hatch; precisa passar a documentar os dois mecanismos (env var pra setar fora da
  sessão do Claude, arquivo pra autorização concedida dentro da conversa).
- Memória `git-push-sempre-bloqueado-r20.md` (auto-memória da sessão percus-kit) — está
  desatualizada e afirma "Claude nunca consegue empurrar sozinho neste repo, nem com aval prévio".
  Corrigir depois que o mecanismo estiver implementado e comprovado funcionando ponta a ponta —
  não antes, para não registrar algo ainda não verificado.

## Não-objetivos (fora de escopo deste design)

- Não mexe na lógica de `premise_validity`/council check já existente no hook — continua valendo
  como está, independente deste mecanismo novo.
- Não cria comando/skill novo para o operador conceder autorização — o gatilho continua sendo
  conversa natural (com confirmação explícita), não um script separado.
- Não resolve o rate-limit do GitHub diretamente — resolve o sintoma (operador tendo que digitar
  push manualmente), não a causa (frequência de push). Cadência de push (uma vez por dia vs. a
  cada commit) continua sendo decisão do operador, não enforced por este mecanismo.
