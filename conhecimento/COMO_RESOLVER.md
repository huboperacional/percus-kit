# Como Resolver — registro de problemas → solução (cross-projeto)

> **Antes de gastar tempo debugando, consulte aqui.** Esta é a base de "já vimos esse problema".
> A skill `percus-review:consult-knowledge` lê este arquivo e casa por **classe de sintoma** (não
> string literal) — por isso cada entrada tem uma linha `tags:` com termos locale-independentes.
>
> **Depois de resolver um problema novo**, adicione uma entrada aqui (gate no `CHECKLIST_ENCERRAR_SESSAO`
> e na skill `checkpoint`). Fonte da verdade = git; sincroniza pra todas as máquinas via `git pull`.
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
- [Skill do plugin referida como slash command (`/percus-review:checkpoint`) — não existe](#skill-nao-e-slash)
- [Cross-Claude do conselho retorna 400 — `temperature` num modelo Opus 4.7+](#cross-claude-400-sampling)
- [Imagem local em Docker Swarm crash-loopa com "pull access denied" (sem registry)](#swarm-local-image-resolve)
- [Hook pre-commit (R11) é PreToolUse: "review && commit" numa chamada só sempre bloqueia](#pretooluse-review-commit)
- [`importlib.reload(config)` num teste polui a suite inteira (quebra testes que rodam depois)](#reload-config-polui-suite)

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

---

## Imagem local em Docker Swarm crash-loopa com "pull access denied" (sem registry) {#swarm-local-image-resolve}

`tags: docker swarm, stack deploy, imagem local, resolve-image never, pull access denied, repository does not exist, single node, sem registry, vps, 161.97.129.138, network_swarm_public, redis_redis, worker healthcheck, container parents, IndexError, config.py, deploy`

**Contexto:** deploy de um backend novo no VPS Swarm compartilhado (`161.97.129.138`, 1 nó, ~30 stacks, Traefik+Postgres+Redis compartilhados). Sem Docker local na máquina do dev e git **local-only** (sem remote) → build tem que rodar NO VPS.

**Sintomas e causas (cada um custou um ciclo):**
1. **Task fica `0/1`, container em "created"/"Starting", crash-loopa, `docker service logs` VAZIO.** `journalctl -u docker` mostra `pull access denied for <img>, repository does not exist`. **Causa:** imagem construída LOCAL no nó não tem digest de registry; o Swarm tenta puxá-la de `docker.io` a cada (re)start de task. O `create` inicial pode rodar do local, mas os restarts pullam → nega. **Fix:** `docker stack deploy --resolve-image never -c stack.yml <stack>` (obrigatório p/ imagem local). Se o spec já quebrou, `docker stack rm` + redeploy limpo com a flag. Alternativa: referenciar a imagem pelo ID `sha256:...` (não pulla).
2. **App não boota — `IndexError` em `Path(__file__).resolve().parents[N]`.** Código calcula a raiz do repo por profundidade de path; no container a árvore é achatada (`/app/app/core/config.py` tem menos `parents` que o layout de dev `services/api/app/core/...`). **Fix:** guardar o índice — `_p = ...parents; root = _p[N] if len(_p) > N else Path("nonexistent")`. Em prod a config vem de env vars, não do `.env` em disco.
3. **Worker ARQ fica `0/1` pra sempre (mesmo rodando e conectado ao Redis).** O serviço herda o `HEALTHCHECK` do Dockerfile (que bate em `:8000/health`), mas o worker não sobe HTTP → unhealthy eterno, nunca vira Running. **Fix:** `healthcheck: test: ["NONE"]` no serviço worker do stack.
4. **Reachability das deps compartilhadas:** Redis desse VPS NÃO publica porta no host — só service-DNS na overlay (`redis://...@redis_redis:6379`); então TODOS os serviços que usam Redis (inclusive worker) precisam entrar na rede **`network_swarm_public`** (external). Postgres publica `161.97.129.138:5432` (dá pra usar via host). Traefik: entrypoint `websecure` + `certresolver=letsencryptresolver` (espelhar labels de um service irmão como `auth_service_api`).

**Diagnóstico geral:** quando o container "created"/log-vazio confunde, **rode a imagem à mão** (`docker run --rm --env-file .env --network network_swarm_public <img> <cmd>`) — separa "app/env quebrado" de "problema de orquestração do Swarm".

**Ref:** Scraper-prospeccao deploy 2026-07-10 (backend LIVE em `scraper.huboperacional.com.br`), commits `9b1da80`+`450a636`; `docs/DEPLOY.md` §Deploy executado; memória `reference_deploy_swarm_local_image_gotchas`.

---

## Skill do plugin referida como slash command (`/percus-review:checkpoint`) — não existe {#skill-nao-e-slash}

`tags: skill, slash command, checkpoint, feature-flow, consult-knowledge, plugin, percus-review, namespace, invocacao, command not found, autocomplete, SKILLS_VS_COMMANDS`

**Sintoma:** um HANDOFF/doc/agente manda "rode `/percus-review:checkpoint`" (ou `/percus-review:feature-flow`, `/percus-review:consult-knowledge`…) e o command **não existe** — não aparece no autocomplete, "command not found".

**Causa-raiz:** `checkpoint` e cia. são **skills**, não **slash commands**. No plugin `percus-review`, só o que está em `commands/*.md` é slash (review, milestone-review, deepseek-review, cross-claude-review, spec-analyze, install-git-hooks, version → `/percus-review:<nome>`; os 4 do conselho declaram `name: council:*` no frontmatter e têm namespace próprio a confirmar — ver `comandos/SKILLS_VS_COMMANDS.md`). O que está em `skills/<nome>/SKILL.md` (checkpoint, feature-flow, consult-knowledge, close-milestone, delegate-impl, auth-consumer, security-audit, tracking-audit, cookie-audit, pages-scan, port-allocate, catalog-publish) **não tem slash**. Agrava: o namespace de skill é **instável** — numa instalação real apareceu como `6.28.0:checkpoint` (a **versão** como namespace, não `percus-review:`), então nem `/6.28.0:checkpoint` é confiável entre bumps. O erro nasce de extrapolar `/percus-review:review` (que É command) pras skills.

**Solução:** skill invoca-se por **linguagem natural** — o user descreve a intenção ("faça o checkpoint deste milestone", "consulte o que já sabemos sobre X") e o **agente invoca via `Skill` tool**. Nunca escreva "rode `/percus-review:<skill>`" num doc/HANDOFF/template. Inventário completo (11 commands × 12 skills) + regra de ouro: `comandos/SKILLS_VS_COMMANDS.md`.

**Ref:** confusão diagnosticada 2026-07-11 (operador não achou `/percus-review:checkpoint`); inventário em `comandos/SKILLS_VS_COMMANDS.md`; regra R23.

---

## Cross-Claude do conselho retorna 400 — `temperature` num modelo Opus 4.7+ {#cross-claude-400-sampling}

`tags: council, conselho, cross-claude, pre-mortem, 400, temperature, sampling params, top_p, top_k, opus-4-7, sonnet-5, fable-5, anthropic api, orchestrator, model id, catalogo`

**Sintoma:** no conselho 3-membros (`council-orchestrator`), o **cross-claude falha com 400** — tipicamente no modo **pre-mortem**; consult e review passam. O agente cai no fallback (coleta a 3ª voz via subagent Sonnet, marker `__PERCUS_NEEDS_CROSS_CLAUDE__`).

**Causa-raiz:** o wrapper `providers/cross-claude.ps1` enviava `temperature` no body da chamada à Anthropic. A família **Opus 4.7 / Opus 4.8 / Sonnet 5 / Fable 5 REMOVEU os sampling params** (`temperature`/`top_p`/`top_k`) — a API retorna **400 `invalid_request_error`** ("temperature: Extra inputs are not permitted") se recebê-los. O router escolhe o modelo por modo: pre-mortem → `claude-opus-4-7` (**rejeita**), review/analyze → `claude-sonnet-4-6` (aceita), consult → `claude-haiku-4-5` (aceita). Por isso só o pre-mortem quebrava "toda hora". ⚠️ **Os model IDs em si são VÁLIDOS** — `sonnet-4-6` e `opus-4-7` estão ativos no catálogo; a armadilha é acusar o ID de "inválido" quando o problema é o *parâmetro*.

**Solução:** (1) **não enviar `temperature`/`top_p`/`top_k`** — o mais simples e à prova de futuro é remover do body de vez (steering vai por prompt, não por sampling); assim o router pode migrar pra Sonnet 5 / Opus 4.8 sem quebrar. (2) O `catch` do wrapper deve expor `$_.ErrorDetails.Message` (corpo JSON do erro da Anthropic), não só `$_.Exception.Message` — que num 400 é o cego "(400) Bad Request". (3) **Antes de acusar um model ID de inválido, conferir no catálogo autoritativo** (skill `claude-api` → seção "Current Models" / `shared/models.md`), **nunca de memória**.

**Ref:** fix 2026-07-11, commit `adbe3a4` (`plugin/percus-review/providers/cross-claude.ps1`); cópia instalada patchada por `cp` na mesma sessão. Router de modelo por modo: `council-orchestrator.ps1` (F.2, `$CrossClaudeModel` switch).

---

## Next `next build` quebra ("Failed to collect page data") com client instanciado no top-level {#next-build-eager-client}

`tags: next, nextjs, app router, build, docker, stripe, collect page data, useContext, standalone, route handler, env, secret, lazy, getStripe`

**Sintoma:** `next build` (produção/container) falha com `Failed to collect page data for /api/<rota>` (às vezes acompanhado de stack em `webpack-runtime`). O `next dev` funciona normal, e por isso "verifiquei no dev, tá 200" **não** garante que o build passa. Frequente em deploy de container (1º build real).

**Causa-raiz:** o `next build` **avalia (importa) os módulos das rotas** na fase "collect page data" — **sem os secrets de runtime**. Se uma lib importada pela rota **instancia no top-level** um client que **joga quando falta credencial**, o import explode e o build morre. Caso clássico: `export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)` — no build `STRIPE_SECRET_KEY` é undefined e o construtor do Stripe joga. Vale pra qualquer SDK que exija credencial no construtor (Stripe, alguns clients GHL/AWS/etc.).

**Solução:** **lazy-init** — construir sob demanda, nunca no import.
```ts
let _stripe: Stripe | null = null;
export function getStripe(): Stripe {
  if (!_stripe) _stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '...' });
  return _stripe;
}
```
e trocar `stripe.x` → `getStripe().x` nos call-sites. Constantes que só **leem** env (`const PRICES = process.env.X!`) não jogam no import → não precisam de lazy. **Não confundir** com o outro modo de falha ("useContext null" no prerender sob Node ≥22/24 — esse resolve buildando em Node 20; ver memória `reference_next14_node24_build_usecontext`). Se der "collect page data", suspeite primeiro de client eager, não de versão de Node.

**Ref:** ads4agencies-site 1º build de container 2026-07-12 (`lib/stripe.ts` → `getStripe()`); commit `ee8b7d6`; memória `reference_next_build_eager_stripe_client`.

---

## Gate de confirmação/escolha nunca pode ter dead-end infinito (cancel-escape + retry→escala)

**Sintoma:** um "micro-confirm" ou gate de escolha (bot pergunta "Confirma? sim/troca") trata como erro qualquer resposta que não seja o esperado — o usuário corrige/cancela/pergunta ("eu não pedi X, pedi Y") e leva um template "Não reconheci essa opção" em loop. É "conversa burra" nascida DA PRÓPRIA feature de confirmação.

**Causa-raiz:** o gate tem só 2 saídas (sim | re-tentar a mesma extração) e a saída de falha é um `return template` sem estado — nenhum ramo pra cancelamento/correção-fora-de-banda, e nenhum contador que quebre o loop.

**Solução (padrão, tiatendo `restaurantOrderFlow.py` gate de sabor, smoke 2026-07-12):** todo gate de confirmação/escolha ganha 3 propriedades, espelhando um gate já-robusto do mesmo código se existir (aqui o disambig de tamanho):
1. **Cancel-escape** ANTES do match: regex de cancelamento ("cancela/deixa pra lá/não quero mais") tira o item/encerra o passo, em vez de re-extrair.
2. **Retry-counter que ESCALA** pro humano na Nª tentativa seguida (ex. 3), em vez de repetir o template pra sempre. Contador no estado persistido, zerado no sucesso.
3. **Re-ask que ECOA o contexto** (ex. o tamanho já escolhido) — dissolve o mal-entendido na origem, não só repete a pergunta.

Corolário de wording: em domínio com dimensões colidentes (pizza P/M/**G** onde M=Média), NUNCA use a mesma palavra ("média") pra outra coisa (método de preço) — o usuário lê como a dimensão. Ecoe sempre a dimensão fixada no readback.

**Ref:** smoke WhatsApp 2026-07-12 (Bug A/B); commit `ef74467`; memória `project-pizza-smoke-fixes-e-loja-web-2026-07-12`.

## Hook pre-commit (R11) é PreToolUse: "review && commit" numa chamada só sempre bloqueia {#pretooluse-review-commit}

`tags: pre-commit, hook, PreToolUse, percus-review-auto, marker stale, R11, git commit bloqueado, review antes de commit, chamada separada`

**Contexto:** o hook `pre-commit-check` bloqueia `git commit` se o último `.deepseek/reviews/*.jsonl` tem >5min. A tentação é encadear `git add ... && pwsh percus-review-auto.ps1 && git commit` numa **única** chamada Bash — e ela é bloqueada mesmo depois do review rodar.

**Causa-raiz:** o hook é **PreToolUse** (inspeciona o comando Bash e barra ANTES de executá-lo), não um git hook nativo. Ele vê o `git commit` no comando e checa a freshness do marker **no instante do pre-check** — quando o `percus-review-auto.ps1` do mesmo comando ainda NÃO rodou. Marker velho → bloqueia o comando inteiro (o review nem chega a rodar). (Observado também: ele barra `cat >>`/writes a arquivos tracked do repo com marker velho.)

**Solução:** rodar o review em uma chamada Bash **SEPARADA** do commit:
1. `git add <arquivos>`
2. (chamada separada) `pwsh -File "...\percus-review-auto.ps1"` — escreve o marker fresco.
3. (chamada separada) `git commit ...` — agora o pre-check vê o marker <5min e passa.
Corolário: o review com **diff vazio** (nada staged/tracked) NÃO escreve marker — stage o arquivo antes de rodar o review. O marker vale ~5min: em features com muitos commits, re-rode antes de cada commit fora da janela.

**Ref:** sessão Session Resume auth-service 2026-07-12; memória `session_resume_implementado_2026-07-12`.

## `importlib.reload(config)` num teste polui a suite inteira (quebra testes que rodam depois) {#reload-config-polui-suite}

`tags: pytest, pollution, poluicao, importlib reload, get_settings, lru_cache, ordem de testes, falha fantasma, webhook, teste isolado passa suite falha, Settings, dependency_overrides`

**Contexto:** um teste novo passa isolado, mas rodando a suite completa aparecem N falhas **fantasma** em arquivos NÃO relacionados (ex.: webhook signature tests) que rodam DEPOIS dele. Remover só o teste novo → suite verde de novo.

**Causa-raiz:** o teste faz `importlib.reload(app.core.config)` (ou de outro módulo core) pra reler env. Reload cria um **novo** objeto `get_settings`/`Settings`, mas todos os módulos já importados (`app.main`, routers, handlers) seguram a referência ANTIGA de `get_settings` (bound no import-time). Ficam DUAS caches `lru_cache` dessincronizadas + um `Settings` novo ≠ o que o app usa. Testes posteriores que leem settings (ex. um secret de webhook) pegam valores inconsistentes → assert falha.

**Solução:** **nunca `importlib.reload` de módulo core no meio da suite.** Pra testar binding de env/flags, instancie `Settings()` **direto** (fresh, lê o env no construtor), sem tocar o singleton nem a cache:
```python
def test_flag(monkeypatch):
    monkeypatch.setenv("MY_FLAG", "true")
    from app.core.config import Settings
    assert Settings().my_flag is True
```
`monkeypatch` reverte o env no teardown; zero estado compartilhado mutado. **Triagem:** teste isolado passa + suite falha em arquivo alheio ⇒ suspeite de poluição (reload / `dependency_overrides` não limpo / cache mutada), não do produto.

**Ref:** sessão Session Resume auth-service 2026-07-12 (11 falhas fantasma em webhook tests); fix commit `603759e`.
