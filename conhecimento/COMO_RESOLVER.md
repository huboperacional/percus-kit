# Como Resolver — registro de problemas → solução (cross-projeto)

> **Antes de gastar tempo debugando, consulte aqui.** Esta é a base de "já vimos esse problema".
> A skill `percus-review:consult-knowledge` lê este arquivo e casa por **classe de sintoma** (não
> string literal) — por isso cada entrada tem uma linha `tags:` com termos locale-independentes.
>
> **Depois de resolver um problema novo**, adicione uma entrada aqui (gate no `CHECKLIST_ENCERRAR_SESSAO`
> e no `/checkpoint`). Fonte da verdade = git; sincroniza pra todas as máquinas via `git pull`.
> Regra: **R23** (`01_REGRAS_INEGOCIAVEIS.md`).
>
> **Formato de cada entrada:** `## <sintoma curto>` · `tags:` · **Contexto** · **Causa raiz** ·
> **Solução** · **Ref**. Severidade implícita pela ordem (mais comum/caro primeiro).

---

## Índice

- [Conselho "revisa a coisa errada" / prompt stale entre runs](#conselho-prompt-stale)
- [Hook `.ps1` quebra com erro de parser / acento vira caractere estranho](#ps51-ascii-hooks)
- [Declarei versão errada ao retomar sessão (origin já estava à frente)](#origin-stale-resume)
- [Fix aplicado não funciona / hipótese de root cause estava errada](#reproduzir-antes-de-fixar)
- [Coach/projeto tentou commitar arquivo no canon (write cross-repo)](#cross-repo-write)
- [Editar JSON (plugin.json) via sed/CLI quebra a string com aspas](#json-sed-aspas)
- [Ambiguidade de dado (2 formas válidas do mesmo identificador) — classificar por formato corrompe](#classificar-formato-corrompe)
- [Codei o fix que o spec/HANDOFF mandava, mas mirava o alvo errado (target stale)](#alvo-do-spec-stale)
- [Design travado num primitivo que a infra de teste não suporta (Lua no fakeredis) — probe antes](#infra-teste-suporta-primitivo)
- [Devolutiva cross-time escrita da MEMÓRIA acusa o bug errado — reverificar no código](#devolutiva-reverificar-no-codigo)
- [Device GOWA (número novo/cold) banido "toda hora" com volume baixo](#gowa-device-ban-usync)

---

## Conselho "revisa a coisa errada" / prompt stale entre runs {#conselho-prompt-stale}

`tags: council, conselho, orchestrator, prompt stale, /tmp, arquivo fixo, windows path, revisa errado, repetido`

**Contexto:** ao rodar o `council-orchestrator` duas vezes seguidas, a 2ª rodada "revisa a pergunta
antiga" — o conselho responde sobre o prompt anterior, não o novo.

**Causa raiz:** command docs salvavam a pergunta num **nome de arquivo FIXO** (`/tmp/council-q.txt`).
No Windows `/tmp/...` resolve pra `d:\tmp\...`; se a 2ª escrita não sobrescreveu, o orchestrator leu o
prompt VELHO. NÃO era cache do orchestrator (ele lê `Get-Content -Raw` fresco) nem o
`prompt_cache_hit_tokens` da DeepSeek (red herring de cache de prefixo server-side).

**Solução:** arquivo temp **único por invocação** — `Join-Path $env:TEMP "council-q-$([guid]::NewGuid().ToString('N')).txt"`
(Windows) ou `mktemp` (Unix), escrito e consumido na mesma invocação, com cleanup. Idem pro
`-CrossClaudeFile`. Alternativa à prova de stale: passar o prompt por **stdin**. Corrigido em v6.16.1.

**Ref:** `CANON_VERSION.md` changelog v6.16.1; memória `project_council_stale_prompt_bug`.

---

## Hook `.ps1` quebra com erro de parser / acento vira caractere estranho {#ps51-ascii-hooks}

`tags: powershell, ps1, hook, parser error, encoding, cp1252, em-dash, emoji, acento, BOM, cmd`

**Contexto:** um hook `.ps1` do canon falha com erro de parse, ou strings com acento/emoji aparecem
corrompidas, **só quando rodado via `.cmd`** (não no pwsh direto).

**Causa raiz:** PowerShell 5.1 (invocado via `powershell.exe` dentro de um `.cmd`) lê `.ps1` **sem BOM**
como **cp1252**, não UTF-8. Em-dash (—), emoji ou qualquer não-ASCII num literal string quebra o parser.

**Solução:** mantenha os hooks `.ps1` do canon **100% ASCII** no código-fonte. Sem em-dash, sem emoji,
sem acento em string literal. Use `Voce`/`nao`/`-` em vez de `Você`/`não`/`—`. (Os system-prompts e
docs `.md` podem ter acento; a regra é só pros `.ps1` executados via `.cmd`/PS 5.1.)

**Ref:** memória `feedback_ps51_ascii_hooks`. Exemplo: os prompts inline do `council-orchestrator.ps1`
usam "Voce e revisor..." de propósito.

---

## Declarei versão errada ao retomar sessão (origin já estava à frente) {#origin-stale-resume}

`tags: git, origin, retomar, resume, versao, version, fetch, behind, stale local, declarar errado`

**Contexto:** ao retomar trabalho, declarei "estamos na vX.Y.Z" mas o `origin/main` já tinha uma versão
mais nova — trabalhei em cima de estado defasado.

**Causa raiz:** confiei no estado local sem comparar com o remoto.

**Solução:** **sempre `git fetch` + comparar com `origin/main`** antes de declarar versão/estado ou
retomar. Em projeto canon, ler `.percus-version` local **e** `origin/main:.percus-version`.

**Ref:** memória `feedback_check_origin_before_resume`.

---

## Fix aplicado não funciona / hipótese de root cause estava errada {#reproduzir-antes-de-fixar}

`tags: debug, root cause, hipotese errada, fix nao funciona, curl, argv, mangling, reproduzir, tooling`

**Contexto:** apliquei um fix baseado numa hipótese plausível e o problema continuou — a causa real era
outra. (Incidente v6.8.4: hipótese inicial "AGENTS.md em CP1252" estava parcialmente certa, mas o root
cause real — `curl` argv mangling — só apareceu rodando o script local de tooling.)

**Causa raiz:** declarar fix sem **reproduzir** o problema com a ferramenta real primeiro.

**Solução:** antes de declarar qualquer fix de tooling, **rode o script/comando que reproduz** o
problema localmente e confirme a causa observada — não a inferida. Reproduzir > teorizar.

**Ref:** memória `feedback_reproduce_tooling_before_fix`.

---

## Projeto tentou commitar arquivo no canon (write cross-repo) {#cross-repo-write}

`tags: cross-repo, canon, write, commit, outro projeto, protocolo, bloqueado, mover arquivo`

**Contexto:** um projeto (ex.: Coach) tentou escrever/commitar um arquivo dentro do canon
(`_Novo_Projeto`) ou o canon tentou `git mv/cp/rm` pra fora dele.

**Causa raiz:** violação do protocolo cross-repo. O canon **nunca escreve em outro repo** e nenhum
projeto escreve no canon diretamente.

**Solução:** o **único** mecanismo é entregar uma **caixa de texto pro operador colar manualmente** no
repo de destino. Leitura cross-repo é permitida; escrita não. Se precisa propagar algo do canon pra um
projeto (ou vice-versa), gere o bloco de texto e peça pro operador aplicar.

**Ref:** memória `feedback_cross_repo_write_protocol` (reforçado 2026-05-30).

---

## Editar JSON (plugin.json) via sed/CLI quebra a string com aspas {#json-sed-aspas}

`tags: json, sed, plugin.json, aspas, quote, string invalida, ConvertFrom-Json, jq, parse error, CLI, bump`

**Contexto:** ao bumpar/editar um `.json` (ex.: `plugin.json`) com `sed`/replace via CLI, o arquivo fica
inválido — `ConvertFrom-Json` falha com "unexpected character" / "After parsing a value...".

**Causa raiz:** a string de substituição continha **aspas duplas literais** (ex.: `"atualizar projeto"`)
dentro de um valor JSON que já é delimitado por aspas duplas → a aspa fecha a string no meio e o resto
vira lixo sintático.

**Solução:** (1) nunca ponha aspas duplas no texto inserido num valor JSON — use aspas simples ou nenhuma;
(2) para edição não-trivial de JSON, **reescreva o arquivo inteiro** (Write com JSON bem-formado) em vez
de `sed`; (3) **sempre valide antes de commitar**: `Get-Content x.json -Raw | ConvertFrom-Json` (PS) ou
`jq . x.json` (Unix). O hook de commit não pega JSON inválido — a validação é sua.

**Ref:** incidente v6.25.0 (`plugin.json` description). Relacionado: lição de validar tooling antes de
declarar pronto.

---

## Ambiguidade de dado (2 formas válidas do mesmo identificador) — classificar por formato corrompe {#classificar-formato-corrompe}

`tags: ambiguidade, telefone, 9 digito, identity, dedup, classificacao, formato, ATO, merge, probe, ground-truth, ninth digit, phone number`

**Contexto:** um identificador tem 2 formas válidas de representar a MESMA entidade (ex.: telefone BR
com/sem 9º dígito), e o sistema precisa decidir se duas formas são "a mesma pessoa" pra fins de
dedup/login/merge. Sintoma: usuário legítimo travado (`no_account`/login falha) porque a conta foi
gravada numa forma e o sistema não reconhece a outra forma como a mesma pessoa.

**Causa raiz:** a tentação óbvia é "classificar o formato" (ex.: `libphonenumber.number_type()`) pra
decidir se uma forma ambígua deveria convergir pra outra. **Isso corrompe dados silenciosamente**: testado
empiricamente (auth-service, 2026-07-06/07) — 8/8 números fixos brasileiros reais, ao inserir o 9º dígito,
passam a classificar como MOBILE no libphonenumber (a formatação estrutural bate, o dado real não). Um gate
"promove se a forma-B classificar como tipo-X" promove **praticamente tudo**, incluindo dado que não deveria
convergir → risco de merge cross-pessoa (classe ATO/vazamento de identidade).

**Um "probe" sozinho (ex.: sondar se o WhatsApp responde numa forma) também NÃO fecha o problema:**
"não há resposta agora" não prova "não há dono nunca" (dono real pode estar com o dispositivo desligado no
momento do probe) — abre uma classe de risco mais sutil (sequestro adiado: quando o dono real aparecer
depois, o sistema já atribuiu o identificador a outra pessoa).

**Solução:** nunca decidir convergência por classificação/formato. Confiar SÓ em **prova real e positiva**
já observada pelo sistema (ex.: entrega confirmada, autenticação bem-sucedida completada) como sinal de
"essas duas formas são a mesma entidade" — nunca inferir a partir do dado em si. Quando essa prova real
também alimenta um mecanismo de escrita/aprendizado automático, adicionar uma trava de colisão (nunca
gravar um valor que já pertence a OUTRA entidade) antes de persistir, mesmo que o sinal pareça confiável.

**Ref:** `D:\Claud Automations\auth-service\docs\superpowers\specs\2026-07-07-delivery-confirmed-identity-matching-design.md`.
Memória: `phone_write_canon_9digito_2026-07-06`. 3 achados adversariais reais na mesma sessão (conselho
pre-mortem + 2× Cross-Claude CRÍTICO) até chegar nessa formulação — não pule a revisão adversarial em
domínio de identidade/auth.

---

## Codei o fix que o spec/HANDOFF mandava, mas mirava o alvo errado (target stale) {#alvo-do-spec-stale}

`tags: spec stale, handoff stale, alvo errado, reproduzir antes, persona, fixture, teste evoluiu, medir antes de codar, convosim`

**Contexto:** um spec/plano/HANDOFF diz "o próximo passo é X pra resolver o problema Y" (ex.: "echo-confirm
pra consertar D2/D3/D4 do convoSim"). Você quase implementa X direto porque veio autorizado/priorizado.

**Causa raiz:** o alvo declarado no doc estava **stale**. Entre a escrita do spec e agora, o que o
identificador aponta MUDOU — no caso real, as personas de teste (`scripts/convoPersonas.py`) foram
renumeradas/redefinidas: o spec descrevia "D2/D3/D4 = declaração incompleta/pronome/inexistente" e mirava
echo-confirm na persona de **declaração**, mas essa persona (agora D1) **já passava**; os FAILs reais
(D2 imagem / D3 link / D4 incremental) tinham OUTRAS causas. Construir echo-confirm não moveria nada.
Docs descrevem o mundo no momento em que foram escritos; fixtures/IDs/nomes derivam com o tempo.

**Solução:** antes de codar pro alvo que um doc aponta, **reproduza e meça o alvo AGORA** — rode o teste/
persona/repro e confirme que o sintoma descrito ainda é o sintoma real, com os mesmos nomes. Se for
conversa/LLM, **leia o transcript real, não confie na nota** (juiz LLM é ruidoso — o mesmo caso dá PASS
numa run e FAIL noutra). Casa com [#reproduzir-antes-de-fixar](#reproduzir-antes-de-fixar), mas um passo
antes: aqui a hipótese nem é sua, é herdada do doc — e docs envelhecem.

**Gotcha operacional junto:** ao rodar um harness in-container num container throwaway (`docker run`),
lembre que **configs bind-montadas em prod NÃO estão na imagem** — ex.: `docker run ... -v /opt/tiatendo/tenants:/app/tenants:ro`,
senão a flag do tenant fica off e o caminho que você quer testar (CALM) nem executa, mascarando tudo.

**Ref:** Ondas 2+3 tiatendo (commits `4c05c5c`+`21b463f`, PROD 0.193.0). Memória:
`project-conversa-rotina-dono-llm-first-2026-07-08`. 4 causas-raiz reais achadas nos transcripts, não a do spec.

---

> **Nova entrada?** Copie o bloco-modelo abaixo, preencha, e adicione no Índice.
>
> ```
> ## <sintoma curto> {#ancora-kebab}
> `tags: termo1, termo2, classe-de-erro, componente`
> **Contexto:** quando/onde aparece.
> **Causa raiz:** o porquê real (não o sintoma).
> **Solução:** o que fazer, com comando se aplicável.
> **Ref:** commit / memória / arquivo.
> ```

---

## Design travado num primitivo que a infra de teste não suporta (ex.: Lua no fakeredis) {#infra-teste-suporta-primitivo}
`tags: fakeredis, lua, EVAL, EVALSHA, token-bucket, redis, design, testabilidade, TDD`
**Contexto:** ao desenhar um rate-limiter compartilhado (auth+FM) travei o design num token-bucket via script **Lua** (`register_script`/`EVAL`) achando que seria "o jeito correto e atômico". Spec aprovado, revisado por cross-Claude adversarial (que apontou até o bug de drain do refill do Lua). Só na hora de escrever os testes descobri, empiricamente, que **`fakeredis` (2.35.1, a infra de teste do projeto inteiro) NÃO suporta `EVAL`/`EVALSHA`** ("unknown command 'eval'") — o Lua seria **100% não-testável** com a stack de testes existente.
**Causa raiz:** não validar que a **infra de teste executa o primitivo** antes de cravar o design em cima dele. Design bonito no papel ≠ design testável na sua stack.
**Solução:** (1) **Antes de fixar o design, escreva um probe de 15 linhas** que roda o primitivo contra a infra de teste real (`fakeredis`, o mock de HTTP, etc.) e prove que funciona. (2) Se não funciona, troque por um primitivo que a infra suporta E que idealmente **simplifica** o problema. No caso: troquei Lua por **fixed-window `INCR`+`EXPIRE NX` num pipeline `MULTI`** — atômico, suportado pelo fakeredis, e que **eliminou o blocker de drain por construção** (sem matemática de refill). Fixed-window com burst-de-fronteira 2× é aceitável pra proteção de device com sizing conservador.
**Ref:** rate-limiter usync auth+FM 2026-07-09 (commit `4a74adc`, deploy `deploy-1783643242`). Memória `autonomo_limiter_paidmedia_2026-07-09`. Spec v3 `docs/superpowers/specs/2026-07-09-device-usync-rate-limiter-design.md`.

---

## Devolutiva cross-time escrita a partir da MEMÓRIA acusa o bug errado {#devolutiva-reverificar-no-codigo}
`tags: devolutiva, cross-product, memoria, hipotese, verificacao, canonicalizacao, phonenumbers, consumer, 422`
**Contexto:** ao escrever a devolutiva pro consumer `gestao`/ads4pros (incidente de login 2026-07-10), a memória da sessão anterior listava **3 fixes**. Um deles — *"o consumer manda o destino formatado `+55 (67) 93300-XXXX` em vez do E.164, e o `/otp/validate` casa por igualdade exata → `otp_wrong`"* — era **FALSO**. O `/otp/validate` chama `canonical_destination()` → `phonenumbers.parse(raw,"BR")` → E.164 **antes** de qualquer comparação. Todas as variantes formatadas canonizam pro mesmo número. Se a devolutiva tivesse saído assim, um time inteiro passaria o dia caçando um bug inexistente — e a nossa credibilidade técnica com o consumer iria junto.
**Causa raiz:** memória de incidente registra **hipóteses de trabalho** com a mesma tipografia de **fatos provados**. Ao redigir o artefato final (devolutiva, post-mortem, doc de propagação), a hipótese é copiada como se fosse conclusão. É o mesmo modo de falha da "doc Evolution fabricada" (2026-07-09).
**Solução:** **antes de escrever qualquer devolutiva/doc que acusa um bug de outro time, reverifique CADA acusação contra o código-fonte e, se possível, execute-a.** Barato e definitivo: um probe de ~20 linhas que roda a função real do contrato (schema Pydantic, canonizador, validador) contra as variantes de entrada suspeitas, e imprime o resultado. O probe desta sessão refutou 1 dos 3 fixes e **fortaleceu** outro — revelou que `code` com espaços explica os DOIS sintomas do log (11 chars → 422 de schema; 7 chars → passa o schema e falha no bcrypt → `otp_wrong`), ou seja, causa única em vez de duas.
**Corolários:**
- Um `422` pode ter **várias origens** no mesmo endpoint (schema Pydantic · erro de canonicalização · erro semântico tipo `otp_wrong` · `invalid_audience`). Nunca trate "422" como diagnóstico — **olhe o corpo**: erro semântico tem `error_code` + `detail` string; schema-422 **não tem** `error_code` e `detail` é uma **lista** (por isso `render(data.detail)` cru imprime `[object Object]`).
- Se um sintoma aparece num endpoint que **não tem o campo acusado** (ex.: 422 no `/otp/request`, que não recebe `code`), a acusação **não explica** aquele sintoma. **Diga "não sei" e peça o corpo cru** em vez de esticar a teoria.
- Escreva a refutação **dentro** da devolutiva ("levantamos X, testamos, é falso, não mexam nisso"). Transparência metodológica compra confiança e evita que o outro time persiga o fantasma por conta própria.
**Ref:** devolutiva gestao/ads4pros 2026-07-10 (commit `9905fa5`), `docs/cross-product/2026-07-10-auth-reply-gestao-otp-payload.md`. Memória `gowa_device_lifecycle_e_consumer_payload_2026-07-10`. Irmão: incidente doc Evolution fabricada, memória `backlog_auditoria_zerado_2026-07-08`.

---

## Device GOWA (número novo/cold) banido "toda hora" com volume baixo {#gowa-device-ban-usync}

`tags: gowa, whatsapp, whatsmeow, device banido, LoggedOut, usync, 429, rate-overlimit, cold number, numero novo, healthcheck, /user/info, /devices, limiter, wa:devrate, redis db, prewarm, envio em massa, jitter, cloud api, reach-out 463`

**Sintoma:** o device GOWA (go-whatsapp-web-multidevice / whatsmeow) de um número **novo/cold** cai (deslogado, `LoggedOut`) diariamente, mesmo mandando **pouquíssimas mensagens**. O operador pergunta "por que bane com volume tão baixo?".

**Causa-raiz:** NÃO é volume de mensagem — é **`usync` 429 `rate-overlimit`**. WhatsApp rate-limita as queries **usync** (`GET /user/info`, `GET /user/check` — checagem de número / info de contato) **por-conexão-de-device**, muito mais agressivo que envio; um número cold tem orçamento minúsculo. As fontes de usync são **invisíveis ao "volume de mensagem"**:
- **Healthcheck/watchdog** que sonda liveness com `GET /user/info` a cada 5 min = ~288 usync/dia, 24/7. **Esta costuma ser a maior fonte fixa.**
- **Prewarm / probes de entrega** (checar 9º dígito, `is_on_whatsapp`) — 1+ por cadastro; letais em **rajada**.
- **Contact-sync do whatsmeow no reconnect** — cada re-link por QR dispara um burst interno de usync.

**Como confirmar (evidência):** `docker logs --since 48h <gowa> | grep -iE 'usync|429|rate-overlimit|not connect'`. Um burst de `usync query ... status 429: rate-overlimit` imediatamente antes de um drop = ban por usync. Cruze com o **crontab** da VPS pra achar quem sonda a cada 5 min.

**Fix (em camadas, sem tocar no WhatsApp):**
1. **Healthcheck NÃO pode usar `/user/info`.** Trocar por listagem LOCAL do store (`GET /devices` ou `/app/devices`, que retornam `state`/`jid` sem gerar usync). Corta a maior fonte fixa. (o `device_health.py` do auth-service já era assim — modelo a copiar.)
2. **Serializador por-processo NÃO basta** se >1 serviço manda pro MESMO device (ex.: auth manda OTP + FM manda bot pelo mesmo device). Precisa de **limiter compartilhado**: token/janela-fixa no **mesmo Redis logical DB** (chave `wa:devrate:{device_id}`), consultado por TODOS os lados antes de cada usync. ⚠️ **Logical DBs do Redis são keyspaces ISOLADOS** — prefixo de chave NÃO cruza DB; os dois lados têm que bater o MESMO `db=N` (abrir conexão dedicada se o resto do tráfego usa outro DB). Fail-open absoluto (nunca bloquear OTP).
3. **Envio em massa** (broadcast/notificação) = jitter **6-12s + ≥2 variações** de mensagem (uniforme/rápido é assinatura de spam). Nunca fazer "blast" de agradecimento pós-wipe num número cold (foi o que baniu o device da FM em 2026-07-06 — 463 reach-out timelock).
4. **Fix definitivo:** migrar pro **WhatsApp Cloud API oficial** (Graph API). Não usa whatsmeow/linked-device nem usync → zera a classe inteira.

**Ref:** FM 2026-07-09/10, commits `99947ba` (healthcheck) + `d490ae4` (limiter FM). Memórias `project_snapshot_2026_07_09_usync_rootcause_limiter_compartilhado`, `incident_2026_07_06_gowa_familia_banido_antispam_463`, `convencao_envio_em_massa_antispam`. Contrato do limiter: `auth-service/docs/cross-product/2026-07-09-auth-reply-familia-fresh-start-e-usync.md`.
