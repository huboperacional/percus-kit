# R20 — autorização em lote para ações externas — Design

**Data:** 2026-08-06 · Brainstorm com `percus-review:council-brainstorm` ativo (DeepSeek +
Groq-Llama) · Revisado com `percus-review:council-consult` (DeepSeek + Groq-Llama + Cross-Claude).

## Risco aceito conscientemente (revisão do conselho, 2026-08-06)

O DeepSeek, na revisão do documento já escrito, apontou uma falha estrutural: o arquivo de
autorização é criado pelo **mesmo agente** cujo comportamento o R20 existe para conter, no mesmo
filesystem que o hook lê. Nada no mecanismo *verifica* que a confirmação do operador realmente
aconteceu — só a promessa comportamental do agente de sempre confirmar antes de escrever. Isso é
estruturalmente mais fraco que a variável de ambiente atual: hoje, `PERCUS_EXTERNAL_OVERRIDE`
exige uma ação humana genuinamente fora do alcance do agente (ele não consegue fazê-la valer
sozinho, mesmo que quisesse); o mecanismo de arquivo substitui essa garantia estrutural por
confiança comportamental.

Isso reabre a decisão do Bloco 2 do brainstorm original, onde foi escolhido "o agente cria o
arquivo quando reconhece autorização na conversa" em vez de "o operador roda um comando curto ele
mesmo" (que fecharia esse gap). **Decisão explícita do operador, ciente do risco (2026-08-06):
manter "o agente cria o arquivo".** Registrado aqui por transparência — não é ausência de risco,
é risco visto e aceito, no espírito do próprio escape hatch R5/R20 ("ciente do risco, prosseguir
com motivo declarado").

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
lê o arquivo, confere idade por timestamp_unix gravado no JSON
        │
        ├─ idade < 60min → permite a ação externa (loga id + motivo)
        └─ idade ≥ 60min, ausente, ou erro de leitura → cai no fluxo normal do R20 (bloqueia)
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
  "id": "a1b2c3d4-e5f6-...",
  "motivo": "texto livre -- o que o operador pediu/confirmou",
  "autorizado_em": "2026-08-06T14:32:00-03:00",
  "timestamp_unix": 1722964320
}
```

**Revisão do conselho (Cross-Claude) mudou a fonte da janela de validade.** A versão original
deste design usava `LastWriteTime` do arquivo (metadado do filesystem) para calcular a idade —
mesmo padrão do council-log. O Cross-Claude apontou que isso é mais frágil que necessário:
metadado de filesystem pode ser alterado por operações que não são a criação original (cópia,
touch, sincronização), sem que o conteúdo mude. A versão final usa `timestamp_unix` **gravado
dentro do próprio JSON no momento da criação** como fonte da idade — o hook compara contra
`Get-Date` no momento da checagem, não contra metadado externo ao conteúdo. Continua sendo uma
janela de 60 minutos, só a fonte do "quando" mudou.

`id` é um UUID gerado a cada criação — não faz parte da decisão de permitir/bloquear (isso
continua sendo só idade < 60min), serve pra correlacionar no log de auditoria (ver "Comportamento
do agente") qual autorização especificamente liberou qual ação.

## Mudança no hook

Em `plugin/percus-review/hooks/external-action-guard.ps1`, novo escape hatch **ao lado** do
`PERCUS_EXTERNAL_OVERRIDE` existente (os dois convivem — qualquer um dos dois libera; nenhum
substitui o outro):

```powershell
# Escape hatch: autorizacao em lote via arquivo (janela de 60min por timestamp_unix DENTRO do
# JSON, nao LastWriteTime do filesystem -- achado do council-consult 2026-08-06: metadado de
# filesystem pode mudar sem o conteudo mudar; o timestamp gravado na criacao e mais confiavel).
# Arquivo atravessa a fronteira de processo do hook; env var da sessao do Claude nao atravessa
# (achado 2026-07-31, confirmado 2026-08-06 -- ver docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md).
#
# IMPORTANTE: try/catch AQUI, LOCAL -- nao deixar erro desta checagem cair no catch generico do
# fim do script. O catch generico do hook e fail-OPEN de proposito (erro interno do script nao
# pode travar a maquina). Mas erro NESTA checagem especifica (arquivo ilegivel, JSON corrompido,
# campo faltando) tem que continuar pro fluxo normal do R20 -- ou seja, tem que poder BLOQUEAR.
# Fail-open aqui seria: permissao negada no arquivo = "ah, deu erro, libera geral" -- exatamente
# o oposto do que devia acontecer (achado Cross-Claude, caso 3 de permissoes).
try {
    $authFile = Join-Path $cwd ".percus/acao-externa-autorizada.json"
    if (Test-Path $authFile) {
        $auth = Get-Content $authFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        # Comparacao em epoch puro, NUNCA converter pra hora local antes de subtrair -- achado
        # do R11/DeepSeek no review deste plano: subtracao de DateTime local e aritmetica de
        # relogio de parede, nao tempo real decorrido. Numa transicao de horario de verao isso
        # podia fazer autorizacao EXPIRADA parecer fresca (perigoso) ou fresca parecer expirada.
        # Epoch (segundos desde 1970 UTC) e monotonico e imune a fuso/DST por definicao.
        $agoraUnix = [DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
        $idadeSeg = $agoraUnix - $auth.timestamp_unix
        if ($idadeSeg -ge 0 -and $idadeSeg -lt 3600) {
            [Console]::Error.WriteLine("[percus:hook external-action-guard] autorizacao em lote ativa (id: $($auth.id), motivo: $($auth.motivo), idade: $([math]::Round($idadeSeg/60,1))min) -- permitindo.")
            exit 0
        }
    }
} catch {
    # Qualquer falha nesta checagem especifica (arquivo ilegivel, JSON invalido, campo faltando,
    # relogio no passado) NAO libera -- so significa "nao consegui confirmar autorizacao", cai
    # pro fluxo normal do R20 abaixo. Fail-closed desta checagem, mesmo com o resto do hook
    # sendo fail-open pra erro interno inesperado.
    #
    # Loga o motivo do erro (achado do R11/DeepSeek): sem isto, um arquivo de autorizacao
    # corrompido bloqueia do mesmo jeito que "nunca autorizado", e ninguem descobre que o
    # motivo real era um erro tecnico, nao ausencia de autorizacao.
    [Console]::Error.WriteLine("[percus:hook external-action-guard] falha ao processar autorizacao em lote: $($_.Exception.Message)")
}
```

Posição no arquivo: antes da checagem de `PERCUS_EXTERNAL_OVERRIDE` ou depois — ordem não importa
(são checagens independentes, qualquer uma que passar libera). Vai logo após a checagem de
`$isExternalAction`, no mesmo lugar onde o escape de env var já está hoje.

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
4. **Registro de auditoria.** Cada vez que o agente usa a autorização em lote, acrescenta uma
   linha em `.percus/autorizacoes-usadas.jsonl` (append-only): `{id, motivo, comando, quando}`.
   Achado do council-consult (Cross-Claude): o log em stderr do hook é efêmero (ninguém garante
   que chega ao operador ou fica registrado em algum lugar revisável depois); o `.jsonl`
   centralizado permite auditoria posterior de "o que foi liberado, por qual autorização, quando".
5. Revogação antecipada: se o operador pedir pra desligar antes da janela acabar, o agente apaga
   o arquivo.
6. Autorização concedida numa sessão/projeto não vale para outro (arquivo é por-projeto — decisão
   arquitetural, não só comportamental, já garantida pelo `Join-Path $cwd`).

**Limite conhecido, não resolvido por este design:** existe uma janela entre o agente anunciar
"vou rodar X" e o comando de fato disparar, dentro do mesmo turno de conversa — se o operador
tentar revogar nesse intervalo exato, a mensagem de revogação só é processada no próximo turno do
agente (propriedade de como a conversa funciona por turnos, não um bug deste mecanismo
especificamente). O `id` no arquivo dá rastreabilidade de qual autorização foi usada, mas não
elimina essa janela — o anúncio prévio (item 3) é a mitigação prática: dá ao operador uma chance
visível de reagir antes da execução, mesmo sem ser uma garantia absoluta.

## Testes

Seguindo o padrão já existente em `plugin/percus-review/tests/external-action-guard.tests.ps1`
(invocação direta do hook via stdin + `pwsh -File`), adicionar:

- Arquivo com `timestamp_unix` recente (< 60min) libera ação externa que seria bloqueada.
- Arquivo com `timestamp_unix` velho (≥ 60min) é tratado como expirado — continua bloqueando.
- Arquivo ausente — comportamento atual inalterado (regressão).
- As duas escapes (env var e arquivo) funcionam independentemente — uma presente sem a outra já
  libera; nenhuma depende da outra.
- **Arquivo presente mas JSON corrompido ou sem `timestamp_unix`: BLOQUEIA** (não libera) — essa
  é a mudança de comportamento em relação à primeira versão deste design; erro na checagem cai
  pro fluxo normal do R20, nunca libera por acidente (achado do council-consult sobre fail-open
  incorreto).
- Arquivo com permissão de leitura negada: bloqueia (mesmo caso acima, via exceção capturada).
- Mensagem em stderr ao usar a autorização em lote inclui `id` e `motivo`.
- Uso da autorização acrescenta uma linha em `.percus/autorizacoes-usadas.jsonl`.
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

## Outros achados do council-consult — aceitos como limitação documentada, ou corrigidos

- **Achado do Cross-Claude verificado e invertido: worktrees NÃO compartilham o arquivo.** A
  preocupação original era autorizar num worktree vazar pra outro do mesmo repositório. Testado
  direto (esta sessão já criou e removeu um worktree real via `EnterWorktree` em
  `.claude/worktrees/<nome>/`): `$cwd` do hook é o diretório de trabalho de onde a ferramenta é
  chamada, e cada worktree tem sua **própria árvore de arquivos** no disco — `.percus/` é
  conteúdo não-versionado (gitignored), então não é compartilhado entre worktrees nem entre um
  worktree e o checkout principal, só o `.git` (histórico/refs) é. Na prática é o oposto do risco
  levantado: autorizar no checkout principal **não vale** dentro de um worktree, e vice-versa —
  cada árvore de trabalho precisa da própria autorização. Isso é seguro por padrão (superfície
  menor, não maior), só potencialmente inconveniente se o operador esperar uma autorização só
  cobrir trabalho espalhado por vários worktrees do mesmo projeto — aceito como comportamento
  documentado, sem mudança de design necessária.
- **`catch` silencioso — achado do R11/DeepSeek no review do plano de implementação (segunda
  rodada).** O bloco `catch` bloqueava certo mas sem logar nada — arquivo de autorização
  corrompido/ilegível resultava em bloqueio indistinguível de "nunca autorizado", dificultando
  diagnóstico. Corrigido: `catch` agora escreve em stderr o motivo técnico do erro, preservando
  o fail-closed (continua bloqueando, só passou a explicar por quê).
- **Comparação de idade em hora local em vez de epoch puro — achado do R11/DeepSeek no review
  do plano de implementação.** A versão anterior deste hook convertia `timestamp_unix` pra
  `DateTime` local (`.LocalDateTime`) e subtraía de `Get-Date` (também local) pra calcular a
  idade em minutos. Subtração de `DateTime` com `Kind=Local` é aritmética de relógio de parede —
  numa transição de horário de verão entre a criação e a checagem, o resultado diverge do tempo
  real decorrido, podendo fazer uma autorização expirada parecer fresca. Corrigido: comparação
  direta em epoch (segundos desde 1970 UTC dos dois lados, nunca convertidos pra hora local),
  imune a fuso/DST por definição — ver "Mudança no hook" acima, já atualizado.
- **Escrita concorrente no log de auditoria — achado do R11/DeepSeek no re-review deste
  documento.** `.percus/autorizacoes-usadas.jsonl` é append-only sem lock; duas sessões do agente
  rodando ao mesmo tempo no mesmo checkout (cenário já registrado como real neste projeto — ver
  memória `checkout-compartilhado-entre-sessoes`) poderiam intercalar linhas. Aceito sem lock: o
  pior caso é uma linha de log corrompida/ilegível, não uma falha de segurança — a decisão de
  permitir ou bloquear a ação externa nunca depende deste arquivo, só do
  `.percus/acao-externa-autorizada.json` (escrita única, não append). Mesma escolha de
  simplicidade que o resto deste design já faz (ex.: janela fixa de 60min em vez de
  parametrizável).
- **`git clean -fd` apagar o arquivo — achado do Cross-Claude verificado e corrigido.** Testado
  diretamente (repo descartável, `git clean -fd --dry-run` contra pasta listada no `.gitignore`):
  o comportamento **default** do `git clean -fd` (sem `-x`/`-X`) já **respeita** `.gitignore` —
  `.percus/` não seria removida. Só `git clean -fdx` (flag explícita pra também remover arquivos
  ignorados) apagaria — comando raro e deliberado, que qualquer operador já trata como "vou
  apagar tudo que não é rastreado, inclusive lixo de build". Não é um risco real do design;
  registrado aqui só para não ser redescoberto como dúvida depois.

## Não-objetivos (fora de escopo deste design)

- Não mexe na lógica de `premise_validity`/council check já existente no hook — continua valendo
  como está, independente deste mecanismo novo.
- Não cria comando/skill novo para o operador conceder autorização — o gatilho continua sendo
  conversa natural (com confirmação explícita), não um script separado.
- Não resolve o rate-limit do GitHub diretamente — resolve o sintoma (operador tendo que digitar
  push manualmente), não a causa (frequência de push). Cadência de push (uma vez por dia vs. a
  cada commit) continua sendo decisão do operador, não enforced por este mecanismo.
