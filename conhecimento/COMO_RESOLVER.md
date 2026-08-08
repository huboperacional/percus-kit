# Como Resolver — registro de problemas → solução (cross-projeto)

> **Antes de gastar tempo debugando, consulte aqui.** Esta é a base de "já vimos esse problema".
> A skill `percus-review:consult-knowledge` lê este arquivo e casa por **classe de sintoma** (não
> string literal) — por isso cada entrada tem uma linha `tags:` com termos locale-independentes.
>
> **Depois de resolver um problema novo**, adicione uma entrada aqui (gate no `CHECKLIST_ENCERRAR_SESSAO`
> e na skill `checkpoint`). Fonte da verdade = git; sincroniza pra todas as máquinas via `git pull`.
> Regra: **R23** (`01_REGRAS_INEGOCIAVEIS.md`).
>
> **Formato de cada entrada:** `## <sintoma curto> {#ancora-kebab}` · `tags:` · **Contexto**
> (ou **Sintoma**) · **Causa raiz** · **Solução** · **Ref**. Toda entrada tem âncora e uma linha
> correspondente no Índice — sem âncora ela fica invisível pra quem lê pelo topo. Bloco-modelo
> pronto pra copiar no **fim do arquivo**.

---

## Índice

- [Middleware edge-safe (só shape do cookie) sem 2ª camada real nos route handlers = bypass de auth](#edge-middleware-second-layer-nunca-implementada)
- [`Response`/`fetch` com corpo em status 204/205/304 lança TypeError — mesmo ArrayBuffer vazio não é `null`](#response-204-corpo-lanca-typeerror)
- [Guarda de ação externa barra o COMMIT porque a MENSAGEM cita a ação](#guarda-casa-a-mensagem-nao-a-acao)
- [Hook que sai 0 não consegue avisar ninguém: stderr e stdout são invisíveis no caminho de sucesso](#hook-que-sai-zero-nao-avisa)
- [Guard CERTO sem caminho alternativo produz o OPOSTO do que protege](#guard-sem-caminho-alternativo)
- [Teste que passa EM CIMA do defeito: o exemplo escolhido é o único em que o bug não aparece](#teste-passa-em-cima-do-defeito)
- [Rótulo curto casa DENTRO de outra palavra e escolhe a coisa errada (no caminho do dinheiro)](#rotulo-casa-dentro-de-palavra)
- [`alias.coluna` vira `funcao(alias)` e o erro mente sobre a causa (GROUP BY sem agregado)](#alias-coluna-vira-funcao)
- [Ausência por design não é falha — e o teste sintético não distingue as duas](#ausencia-por-design-vs-falha)
- [O ponteiro estava no PLANO e eu não o segui: improvisar spec sobre design já aprovado](#ponteiro-no-plano-nao-seguido)
- [Conselho: `status: ok` NÃO significa que o membro respondeu (irmão do teto de tokens)](#conselho-status-ok-content-vazio)
- [Pre-mortem de plano: mande o revisor LER o código, não só o plano](#pre-mortem-revisor-le-o-codigo)
- [Org de teste limpa não expõe topologia — só comportamento](#org-limpa-nao-expoe-topologia)
- [Watchdog de confirmação de entrega dispara falso-positivo contra device de teste automatizado (não gera ack)](#watchdog-ack-device-teste-automatizado)
- [Marcar uma entidade como "fora do padrão": filtre os EMISSORES, não só os leitores](#marca-varre-emissores-e-leitores)
- [Brief de design que cita a fonte pelo NOME propaga erro invisível](#brief-cita-token-nao-nome)
- [Layout que depende de menu lateral colapsável: `@container`, não media query](#container-query-menu-colapsavel)
- [Conselho devolve "3 providers ok" com uma perna vazia e outra cortada (teto de tokens × modelo de raciocínio)](#conselho-perna-vazia-teto-tokens)
- [Ferramenta de monitoramento roda INERTE com os testes verdes: `source` de outro script clobrou o entry point](#source-clobra-entry-point)
- [Como saber se um cron/monitor MORREU: batimento periódico não serve — só dead-man's switch](#deadman-switch-nao-batimento)
- [Auditar SPA em produção de fora: bata na ROTA INTERNA, nunca em `/`](#auditar-spa-rota-interna)
- [Lição escrita em prosa não impede reincidência — o conserto tem que morar num gate](#licao-em-prosa-reincide)
- [Alarme falso treina todo mundo a ignorar o alarme de verdade](#alarme-falso-mata-o-alarme)
- [O aviso promete o que o gate não entrega (promessa e decisão em módulos diferentes)](#promessa-e-decisao-separadas)
- [Mock de função de BANCO no arquivo de mocks de REDE → erro que não fala do seu problema](#mock-de-banco-em-arquivo-de-rede)
- [Parser de "1/2" nascido numa pergunta numerada lê quantidade como sim/não no texto livre](#token-lista-numerada-vaza)
- [Fact-check da review marca finding REAL como "INFUNDADO" porque não conseguiu verificar](#fact-check-infundado-e-nao-verificado)
- [Review volta vazia parecendo limpa: o revisor ABORTOU por causa de um binário no diff](#revisor-aborta-com-binario)
- [Teste que verifica ESTADO FINAL não pega regressão de ORDEM entre duas chamadas assíncronas](#teste-estado-final-nao-pega-ordem)
- [Reusar "o mesmo discriminador" de uma função irmã sem copiar TODOS os ramos reintroduz o bug que a irmã já corrigiu](#discriminador-parcial-reintroduz-bug)
- [Postgres reclama de "column X does not exist" onde X é um VALOR seu (aspas comidas pelo ssh)](#ssh-heredoc-come-aspas)
- [404 "por design" transforma erro de tenancy em bug invisível: 3 orgs homônimas e um link que nunca abre](#404-por-design-esconde-tenancy)
- [Módulo fail-open: "quebrado" e "corretamente desligado" ficam idênticos de fora, e o teste passa nos dois](#fail-open-esconde-teste-vacuo)
- [`ORDER BY created_at` não ordena um lote: `now()` é hora da TRANSAÇÃO](#created-at-nao-ordena-lote)
- [Schema `strict` que OBRIGA o campo mas não ENSINA quando preenchê-lo produz silêncio, não erro](#strict-schema-campo-sem-instrucao)
- [Guarda contra ação destrutiva tem que ser testada com PERGUNTAS, não só com comandos](#guarda-destrutiva-testar-com-perguntas)
- [Contrato que manda o LLM REPETIR o estado inteiro copia da fonte errada quando há histórico](#contrato-declarativo-copia-do-historico)
- [`xfail` que sempre xpassa é pior que teste nenhum](#xfail-que-xpassa-anuncia-defeito-que-nao-demonstra)
- [Sessão de login "morre sozinha" em todos os produtos ao mesmo tempo](#sessao-morre-invalidacao-por-pessoa)
- [Flag de "já processei" que mente produz PERDA e DUPLICAÇÃO ao mesmo tempo — e uma esconde a outra](#flag-ja-processei-que-mente)
- [Ao proteger alguém de um envio, o filtro tem que caber na CHAVE de cada emissor](#filtro-cabe-na-chave-do-emissor)
- ["Zerar um campo pra não sobrescrever" em API full-replace na verdade APAGA o campo](#zerar-campo-em-put-full-replace-apaga)
- [`<input type="date">` mostra mm/dd mesmo com a página inteira em pt-BR](#input-date-formato-idioma-navegador)
- [scp pra caminho remoto com colchetes (`[id]` de rota Next) falha por glob no lado remoto](#scp-colchetes-glob-remoto)
- [`docker service inspect | grep VAR` confirma que a CHAVE existe, não que o VALOR é não-vazio — integração ficou meses no-op silencioso](#docker-inspect-presente-nao-e-valor)
- [`console.log(objeto)` trunca aninhamento como `[Object]` e esconde o erro real de uma integração que "falhou sem motivo"](#console-log-objeto-trunca-oculta-erro)
- [Decisão `"council"` do review-router não está nos passos do comando `/review` — e só `deepseek-review.ps1` escreve o marcador de frescor que o hook checa](#council-decision-fora-do-review-doc)
- [Groq/Llama devolve 413 (Payload Too Large) num diff grande que a DeepSeek aceita — reduzir `-MaxInputTokens` só daquela perna](#groq-llama-413-payload-too-large)
- [Teste de presença/ausência de string não prova nada quando o gate é em RUNTIME sobre um template estático](#teste-string-nao-prova-gate-runtime)
- [`git worktree remove` falha com "Invalid argument" (não timeout) quando o worktree tem uma junction do Windows dentro](#worktree-remove-junction-windows)
- [API rejeita "invalid unicode code point" com prompt perfeitamente válido — o argv do curl no Windows corrompeu o texto no caminho](#curl-argv-corrompe-utf8-windows)
- ["Sessão de 30 dias" que morre em 2 segundos: wipe do refresh token em falha transitória](#refresh-wipe-transitorio)
- [Auditoria cross-repo que lê o CHECKOUT LOCAL vira evidência circular](#auditoria-cross-repo-working-tree)
- [Cliente de API que devolve `None` no erro faz o produto achar que ENTREGOU](#provider-none-vira-entrega)
- [Mock do DAO esconde erro de CHAVE e de serialização](#mock-dao-esconde-chave)
- [Endpoint muda o formato do payload pra um consumidor novo e quebra os consumidores antigos, silenciosamente](#endpoint-reshape-quebra-consumidor-antigo)
- [Guarda que o entrypoint real nunca alcança](#guarda-morta-entrypoint)
- [Tirar um produto do superusuário do Postgres (least-privilege) num cluster compartilhado](#least-privilege-cluster-compartilhado)
- [Conselho "revisa a coisa errada" / prompt stale entre runs](#conselho-prompt-stale)
- [QR code de pareamento "não linka" → suspeite do SEU refresh antes de culpar o provedor](#qr-pareamento-expira)
- ["SSH quebrou" depois de rotacionar chaves no Windows — mas a chave está OK, é o `ssh` errado](#ssh-automacao-git-bash-vs-agente-windows)
- [Dois produtos na MESMA conta Stripe → todo webhook chega nos dois; discrimine por preço](#stripe-cross-talk-dois-adapters)
- [Hook fica lento e trava os commits: diretorio de estado que so cresce](#estado-append-only-trava-hook)
- [Comentário `//` na mesma linha de `function nome(){` engole a declaração inteira — nada no app funciona, e o erro aponta pra linha errada](#comentario-engole-function)
- [Review R11 escopada ao WORKING TREE INTEIRO mistura o diff de 2 subagentes rodando em paralelo no mesmo worktree](#r11-mistura-diff-subagentes-paralelos)
- [Tag de plano aberta que já foi entregue sob OUTRO número de migration](#migration-numero-reciclado)
- [Teste que nunca falhou embarca fóssil: o red importa mais que o green](#red-nunca-visto-embarca-fossil)
- [Guarda que lê o FONTE some junto com a string que ela procura (falso-negativo silencioso)](#guarda-fonte-strip-string)
- [`testIgnore`/`testMatch` de PROJETO substitui o do config raiz — não soma](#playwright-testignore-projeto-sobrescreve)
- [Spec vermelha há semanas: o elemento não sumiu, a PÁGINA não abre (guard de perfil)](#spec-vermelha-rota-inacessivel-por-perfil)
- [Declarei hook/gate "instalado" sem rodar no cenario real -> passou defeito](#verificar-runtime-nao-estrutura)
- [Hook `.ps1` quebra com erro de parser / acento vira caractere estranho](#ps51-ascii-hooks)
- [Consertei o hook no repo, a suíte ficou verde, e a máquina continua com o comportamento velho](#plugin-cache-nao-recebe-fix)
- [`subprocess.run(text=True)` sem `encoding=` decodifica stdout como cp1252 no Windows — texto acentuado derruba a thread leitora](#subprocess-text-true-sem-encoding-cp1252)
- [Declarei versão errada ao retomar sessão (origin já estava à frente)](#origin-stale-resume)
- [Fix aplicado não funciona / hipótese de root cause estava errada](#reproduzir-antes-de-fixar)
- [Escrever em outro repo: caixa/arquivo — exceção é a pasta comum `conhecimento\`](#cross-repo-write)
- [Editar JSON (plugin.json) via sed/CLI quebra a string com aspas](#json-sed-aspas)
- [Ambiguidade de dado (2 formas válidas do mesmo identificador) — classificar por formato corrompe](#classificar-formato-corrompe)
- [Codei o fix que o spec/HANDOFF mandava, mas mirava o alvo errado (target stale)](#alvo-do-spec-stale)
- [Design travado num primitivo que a infra de teste não suporta (Lua no fakeredis) — probe antes](#infra-teste-suporta-primitivo)
- [Devolutiva cross-time escrita da MEMÓRIA acusa o bug errado — reverificar no código](#devolutiva-reverificar-no-codigo)
- [Device GOWA (número novo/cold) banido "toda hora" com volume baixo](#gowa-device-ban-usync)
- [Skill do plugin referida como slash command (`/percus-review:checkpoint`) — não existe](#skill-nao-e-slash)
- [Relatório com JANELA de período re-introduz viés de sobrevivência que você "já consertou"](#janela-reintroduz-vies-sobrevivencia)
- [Deploy sobe código VELHO com tag NOVA: diretório de build compartilhado entre serviços](#build-dir-compartilhado-tag-nova)
- [Args com aspa simples atravessando `ssh` + `bash -c` selecionam a coisa ERRADA, sem erro](#aspa-simples-ssh-bash-c)
- [O fix vira o defeito seguinte: 3 CRITICALs em 5 rodadas, cada um filho da correcao anterior](#fix-vira-defeito-seguinte)
- [Suite verde e boot morto: a versao da lib na IMAGEM nao e a da sua maquina](#skew-lib-imagem-vs-local)
- [Log de diagnóstico "no ar" que nunca emitiu: sob uvicorn o root logger é mudo](#uvicorn-root-logger-mudo)
- [Cross-Claude do conselho retorna 400 — `temperature` num modelo Opus 4.7+](#cross-claude-400-sampling)
- [Imagem local em Docker Swarm crash-loopa com "pull access denied" (sem registry)](#swarm-local-image-resolve)
- [Guard `try/except` fail-open esconde import errado: a feature vira no-op silencioso](#fail-open-esconde-import-errado)
- [Conversa escalada pra humano fica MUDA e ninguém percebe (54 msgs em 34 min)](#handoff-mudo-sem-salvaguarda)
- [Hook pre-commit (R11) é PreToolUse: "review && commit" numa chamada só sempre bloqueia](#pretooluse-review-commit)
- [`importlib.reload(config)` num teste polui a suite inteira (quebra testes que rodam depois)](#reload-config-polui-suite)
- [Deploy: `docker build ... | tail && service update` mascara build falho → outage 404](#deploy-pipe-mascara-exit)
- [Cloudflare proxied (laranja) impede Traefik/Let's Encrypt de emitir cert](#cloudflare-proxy-quebra-acme)
- [Canonical absoluto no layout do Next desindexa TODAS as rotas filhas](#next-canonical-layout-herdado)
- [Build no VPS falha puxando imagem PÚBLICA do ghcr.io ("denied") + `${VAR}` do stack deploy é no-op](#ghcr-denied-stale-login)
- [`NEXT_PUBLIC_*` não aparece no bundle client em prod (setei só no compose runtime)](#next-public-baked-build)
- [Preciso verificar que uma página admin/dashboard renderiza, mas o MCP de browser caiu / precisa login](#render-smoke-in-container)
- [Migração de UI+API pra novo domínio: cookie dinâmico por Host não basta, a base da API também](#migracao-dominio-cookie-e-api-dinamicos)
- [Mudar rota/Host do Traefik (label) não pega com `service update --image`](#traefik-label-precisa-stack-deploy)
- [\[5-T\] de mudança no loader/script client-side na página real do cliente sem poluir prod](#loader-5t-sem-poluir-prod)
- [Guard anti-dupla-cobrança com idempotency do Stripe não dispara (a key REPLICA a resposta cacheada)](#stripe-idempotency-replay)
- [Raspando email de contato: JSON-LD é onde mora, e o MX "válido" aceita registro A](#scrape-email-jsonld-mx)
- [Guard de segurança checa a INTENÇÃO e não o ALVO (ex.: `APP_ENV=test` não protege banco nenhum)](#guard-checa-intencao-nao-alvo)
- [Verifiquei a pré-condição, pedi aprovação (R20/R5), e executei quando o operador respondeu — mas a verificação VENCEU na espera](#verificacao-vence-esperando-r20)
- [Migração de schema vai subir e o entrypoint roda `alembic upgrade || continuing` (fail-open)](#migracao-entrypoint-fail-open)
- [Reviewer cross-provider (R11/conselho) acusa "migration ausente"/"campo morto" que JÁ existe — ele só vê o diff staged](#reviewer-so-ve-diff-staged)
- [Kill-switch com gate nos call-sites cobre menos do que promete — o docstring vira mentira](#kill-switch-no-facade)
- [View `SELECT *` congela colunas na criação — prod funciona e instalação fresca quebra](#view-select-star-congela-colunas)
- [Worker precisa de segredo que outro serviço cifrou → sonda roda DENTRO do serviço dono](#sonda-no-servico-dono-do-segredo)
- [Next `next build` quebra ("Failed to collect page data") com client instanciado no top-level](#next-build-eager-client)
- [Fix editado DEPOIS do `add` fica fora do commit — review revisa versão limpa, commit embarca a buggy](#staging-pos-review-drift)
- ["Erro de conexão" no front que é, na verdade, um 500 do backend](#erro-de-conexao-e-500-sem-cors)
- [Consumir `/internal/identities/v2` do auth-service: `name`, não `display_name`](#identities-v2-exige-name)
- [`docker stack deploy` rola serviços pra trás quando o swarm.yml está com pins stale](#stack-deploy-swarm-pins-stale)
- [Bot conversacional re-pergunta info que o cliente já deu FORA DE ORDEM (checkout/wizard)](#parking-info-fora-de-ordem)
- [Validar UMA conta numa API multi-tenant e generalizar o resultado](#validar-uma-conta-generalizar)
- [Feature que depende de LLM ou dado real não fecha `\[5-T\]` sem smoke em prod com a FRASE/DADO EXATO do caso original](#smoke-prod-feature-llm)
- [Coluna usada como critério de ORDENAÇÃO/desempate que ninguém nunca escreveu (NULL em 100% das linhas)](#coluna-ordenacao-nunca-escrita)
- [Lookup por identificador "normalizado" só de um lado — metade da base fica invisível, sem erro](#lookup-normaliza-so-um-lado)
- [SSH "Server accepts key" e logo "Permission denied" — chave com passphrase sem agente](#ssh-key-passphrase-sem-agente)
- [Lista destrutiva datada pelo campo de AUDITORIA em vez do de negócio](#lista-data-auditoria-vs-negocio)
- [Gate de commit (R11) trava com "invalid_request_error: deepseek-chat" — modelo descontinuado](#deepseek-chat-modelo-descontinuado)
- [Transição automática nova torna um status intermediário TRANSIENTE e mata todo leitor por igualdade](#status-intermediario-transiente)
- [Cliente que "degrada gracioso" engole erro de credencial — log limpo não é prova de que conectou](#degrade-gracioso-esconde-noauth)
- [Gate de confirmação/escolha nunca pode ter dead-end infinito (cancel-escape + retry→escala)](#gate-confirmacao-dead-end)
- [Side-effect flag-gated não dispara: cred provavelmente já existe self-hosted no VPS](#cred-selfhosted-no-vps)
- [Falha na suite completa fora do teu diff → triar pollution/pré-existente ANTES de assumir culpa](#falha-fora-do-diff-triagem)
- [Rodar testes que dropam tabelas contra Postgres efêmero isolado (sem Docker/PG local, nunca prod)](#pg-efemero-testes-destrutivos)
- [Um fix commit que não re-roda a suíte de regressão enterra um RED sob "\[5-T\] local verde"](#fix-commit-sem-re-rodar-suite)
- [Resgatar linhas órfãs de migration aditiva (coluna nova NULL) via backfill + path real do coletor](#linhas-orfas-migration-aditiva)
- [Padronizar componente compartilhado: regra por POSIÇÃO vaza + env Jinja é por-rota (tiatendo I6)](#componente-compartilhado-posicao-e-env)
- [Verificar UI: o que "não aparece" no screenshot pode ser artefato da ferramenta, não bug (Micro Investors F2)](#ui-falso-negativo-da-ferramenta)
- [`deepseek-review.sh` morre com "jq: Argument list too long" (diff > ~30KB no Windows)](#jq-argv-too-long-review)
- [Bug de fuso multi-tenant tem 4 camadas — e a mais traiçoeira é o YAML, não o código](#fuso-multi-tenant-4-camadas)
- ["Concluída" decidida pelo TEXTO do status apodrece em silêncio quando o produto deixa renomear](#status-por-texto-apodrece)
- [Escape que atravessa camadas de transporte pode virar troca de X por X — com "ok" mentiroso](#escape-atravessa-camadas-noop)
- [Deploy delta com base defasada REVERTE feature entregue — e o smoke de feature não pega](#deploy-delta-base-defasada)
- [Conselho responde bem à pergunta errada quando o contexto omite uma restrição](#conselho-contexto-incompleto)
- [Scheduler novo sobre tabela velha: dedup por MARCADOR, senão a linha fóssil engole o 1º disparo](#scheduler-dedup-por-marcador)
- ["O backend já aceita X" — repo ≠ imagem em prod (422 silencioso pós-deploy parcial)](#repo-nao-e-imagem-em-prod)
- [Monitor passivo: o erro que você viu no probe ativo pode NÃO existir no pipe](#monitor-passivo-corpo-do-erro)
- [Feature vira no-op DETERMINÍSTICO num caso comum e a suíte inteira fica verde](#fixture-uniforme-esconde-irregular)
- ["Cinto de segurança" extra CORTA o caso legítimo — e alargá-lo vira guarda morta](#guarda-redundante-tesoura-ou-morta)
- [`DROP COLUMN` no rollback falha: uma view `SELECT *` depende da coluna nova](#down-migration-view-select-star)
- [Mesma regra escrita em dois interpretadores (.ps1 + .sh) diverge calada](#regra-duplicada-ps1-sh)
- [Saída de `jq`/`python` no Windows vem com CRLF e o `\r` mata a regex em silêncio](#crlf-mata-regex-git-bash)
- [Hook em PowerShell bloqueia commit legítimo vindo do git-bash (path `/d/...` e `-c` ≠ `-C`)](#hook-ps-path-msys-e-match-case)
- ["Camada velha" que a camada nova referencia N vezes não está velha — está pendente de migração](#camada-velha-ainda-apontada)
- [Depois de um `DROP TABLE`, "voltar a tag" não é rollback](#drop-table-rollback-pareado)
- [Defeito que o serviço remoto ACEITA é latente, não risco](#defeito-latente-aceito)
- [`docker exec` sem `-i` engole o stdin — e vazio parece resposta](#docker-exec-stdin)
- [Magic-link mintado do lado do servidor falha com `context_mismatch`](#magic-link-server-side-context-mismatch)
- [Rota que ainda não existe devolve 404 — e isso deixa o teste VERDE sem implementação](#rota-inexistente-deixa-teste-verde)
- [`service update` diz "converged" mas o serviço continua na imagem VELHA (rollback silencioso)](#swarm-converged-e-rollback)
- [`alembic upgrade head` não vê a migration nova: ela mora DENTRO da imagem](#alembic-head-mora-na-imagem)
- [CHECK bicondicional ACEITA a linha proibida quando o discriminante é NULL (UNKNOWN passa)](#check-bicondicional-unknown)
- [Preflight CORS recusado: o serviço fica verde e só o browser do usuário quebra](#preflight-cors-falha-silenciosa)
- [A mutação sobreviveu: o código está certo e a prova de que precisa estar não existe](#mutacao-sobrevive-predicado-quase-certo)
- [Sessão de 30 dias que "não persiste": como provar de que lado está o defeito](#sessao-30-dias-nao-persiste)
- [Auditar código de OUTRO repo: leia a ref publicada, nunca o working tree](#auditar-outro-repo-ref-publicada)
- [Config que só o browser vê: env stale sobrepondo o default do código](#env-stale-sobrepondo-default)
- [Consumer novo "não consegue enviar OTP": audience nunca foi registrada no auth-service](#audience-nao-registrada-otp-falha)
- ["Atualizei a credencial e continua falhando": env var herdada vence o .env, em silêncio](#env-var-vence-dotenv)
- [Banco novo para um segundo tenant quando a cadeia de migrations não roda do zero](#tenant-novo-cadeia-migrations-quebrada)
- [Task dada como "fechada" com prova que só cobria metade do canal: hook fala por stderr num `SessionStart` que sai 0, e nunca aparece](#sessionstart-stderr-nunca-aparece)
- [Função de "abandonar/encerrar" duplicada sem os irmãos: grava o status terminal mas esquece a trilha E o estado efêmero associado](#abandonar-duplicado-sem-trilha-e-estado-efemero)
- [CLAUDE.md aponta pro caminho ANTIGO do canon (`_Novo_Projeto`) — script não existe mais, renomeado pra `percus-kit`](#claudemd-caminho-canon-stale)
- [Python `round()` (half-to-even) e JS `Math.round()` (half-up) divergem em empate exato — "fonte única" que só cobre a tabela, não a função](#python-js-round-tie-diverge)
- [`Agent` com `isolation:worktree` pode nascer dezenas de commits atrás da `main` — nunca confie no HEAD sem checar](#isolation-worktree-nasce-stale)
- [Loop de "esperar Postgres ficar pronto" pode declarar sucesso durante o servidor TEMPORÁRIO do entrypoint oficial, e falhar segundos depois no restart](#pg-isready-race-entrypoint-restart)
- [Duas sessões trabalham na mesma spec sem saber uma da outra — plano completo já existia, commitado num worktree isolado](#duas-sessoes-plano-duplicado-worktree)
- [`sed` de redação de segredo falha quando a entrada vem de `grep -B`/`-A` (prefixo de número de linha quebra o padrão)](#sed-redact-falha-com-grep-contexto)
- [Teste "travado" via túnel SSH pode ser lento de verdade, não hang — e o túnel morre sob carga sustentada](#tunel-ssh-lento-vs-hang-e-morre-sob-carga)
- [Fix de guard dependente de sinal do LLM passa 100% dos testes (mockados) e reproduz em PROD — o mock provou a hipótese ERRADA sobre o que o LLM extrai](#mock-sig-llm-hipotese-errada-precisa-smoke-real)
- [`[5-T]` manual mostra página vazia/velha: `netstat` mente sobre qual PID escuta a porta, servidor local zumbi de sessão anterior](#servidor-dev-zumbi-porta-netstat-mente)
- [Subagent commita só os arquivos do PRÓPRIO task — docs/spec editados fora do escopo de nenhuma task ficam esquecidos no disco](#docs-fora-escopo-task-ficam-nao-commitados)
- [Script de teste "só código" (.py/.sql) contra Postgres efêmero derruba TUDO que renderiza template ou lê YAML de tenant — 138 falsas-falhas de uma vez](#ephemeral-test-script-so-py-sql-esconde-templates-yaml)
- [Hook R11 (`PreToolUse` de review antes de commit) tem enforcement inconsistente pra subagents via Agent/Task tool](#r11-hook-inconsistente-subagents)
- [`docker stack deploy` atualiza labels do Traefik mas não recria o container quando a tag da imagem não muda — precisa `service update --force` depois](#stack-deploy-nao-recria-container-tag-igual)
- [Next.js: rota de segmento dinâmico compartilhada entre vários "tenants" — `force-dynamic` é por ARQUIVO, não por branch, e desotimiza todos de uma vez](#nextjs-force-dynamic-e-por-arquivo-nao-por-tenant)
- [Prefill de checkbox-group via URL param em form embutido de terceiro (GHL) marca a opção ERRADA, não "não funciona"](#ghl-checkbox-prefill-url-inconsistente)
- [CSS Grid `auto-fit` estica item único/par pra largura total quando sobram poucos itens](#css-grid-autofit-estica-item-unico)
- [CTA novo pra path interno perde `gclid`/`fbclid`/`utm_*` porque `<KeepQuery/>` nunca foi MONTADO nessa página](#keepquery-precisa-estar-montado)
- [`_env()` de `.env` com regex `\s*` cruza quebra de linha quando o valor está vazio](#env-regex-cruza-linha-vazia)
- [Credencial n8n apontando pra hostname interno Docker que nunca vai resolver: n8n e Postgres podem estar em VPS diferentes](#n8n-postgres-vps-diferentes)
- [Upload de arquivo pra VPS via Bash falha com erro de bash confuso mesmo pra arquivo pequeno](#vps-upload-msys-path-mangling)
- [Review R11 (DeepSeek) devolve "Sem findings críticos" mas viu só um pedaço do diff — truncamento silencioso em diffs grandes](#r11-diff-truncation-silent)
- [`docker service inspect | grep VAR` confirma que a CHAVE existe, não que o VALOR é não-vazio — integração ficou meses no-op silencioso](#docker-inspect-presente-nao-e-valor)
- [`console.log(objeto)` trunca aninhamento como `[Object]` e esconde o erro real de uma integração que "falhou sem motivo"](#console-log-objeto-trunca-oculta-erro)
- [Revision id de migration Alembic estoura `alembic_version.version_num VARCHAR(32)` — health check standalone pega ANTES do cutover](#alembic-revision-id-varchar32)
- [Subagente que promete "reporto quando terminar" um comando em background não retoma sozinho — precisa de outro SendMessage](#subagent-background-promise-nao-se-cumpre-sozinho)
- [Rota Next.js (Node runtime) atrás de Traefik redireciona pra `0.0.0.0:PORT` em vez do host público](#nextjs-node-route-handler-req-url-bind-address)
- [Volume nomeado do Docker Swarm nasce `root:root`; container non-root não consegue escrever](#swarm-named-volume-root-owned-vs-nonroot-container)
- [`EnterWorktree` (ferramenta nativa) nasce STALE quando `main` local está à frente de `origin`](#enterworktree-nasce-stale-baseref-fresh)
- [Isolamento multi-tenant por UUID+FK (sem coluna `tenant_id` redundante) gera falso positivo em review automático](#tenant-isolation-uuid-fk-false-positive-r6)
- [Subagent commita trabalho ALHEIO que achou no working tree, mesmo com instrução explícita de não tocar](#subagent-commita-trabalho-alheio-sem-autorizacao)
- [Guard test que proíbe um vocabulário legado (regex `\bword\b`) colide com nome novo legítimo que contém a mesma palavra](#guard-legado-word-boundary-colide-nome-novo)
- [Classe CSS de tema novo perde (ou não) uma queda de especificidade contra Tailwind, dependendo se ela declara a propriedade](#css-cascade-theme-class-vs-tailwind-inconsistent)
- [`position: fixed` renderiza preso dentro de um card em vez da viewport inteira](#position-fixed-trapped-by-ancestor-transform)
- [Elemento preso dentro de card `overflow-hidden`+`rounded-*` não escapa com margin negativo — usa `createPortal`](#portal-escape-overflow-hidden-card)
- [`docker ps --filter name=X` casa por SUBSTRING — pega sidecar cujo nome começa com X](#docker-ps-filter-name-substring-match)
- [Duas sessões Claude no MESMO diretório de trabalho colidem em checkout E em deploy, não só em commit](#sessoes-paralelas-mesmo-diretorio-colidem)
- [Adicionar um arquivo ao índice do git e depois fechar o registro sem restringir o escopo pode levar junto o que outro processo já tinha preparado no mesmo diretório](#indice-git-compartilhado-leva-trabalho-alheio)
- [Backfill manual via CLI (`--account-id`) grava dado real mas não atualiza a tabela de saúde da coleta](#cli-backfill-nao-atualiza-collection-log)
- [Browser MCP (Playwright/Chrome-DevTools) pode estar conectado a um perfil Chrome REAL com sessão AO VIVO do operador, não um perfil isolado](#browser-mcp-sessao-ao-vivo-operador)
- [Smoke test conversacional (webhook + estado de sessão de bot): mandar a próxima mensagem sem confirmar o estado via poll() cascateia falso-negativo](#smoke-conversacional-sessao-presa-cascateia)
- [Hook PowerShell roda sob `powershell.exe` 5.1, não `pwsh` — arquivo produzido sem BOM (ou teste com acento literal no source) corrompe/quebra silenciosamente](#hook-powershell-51-sem-bom-corrompe)
- [Fluxo de confirmação com allowlist fixo cancela silenciosamente em vez de reprompt](#confirmacao-allowlist-cancela-em-vez-de-reprompt)
- [Deploy de sessão paralela sobrescreve o seu sem aviso](#deploy-paralelo-sobrescreve-sem-aviso)
- [Junction de node_modules compartilhada entre worktrees corrompe e trava Turbopack](#junction-node-modules-worktree-risco)
- [Dois hooks de pre-commit diferentes bloqueiam por motivos diferentes](#dois-hooks-pre-commit-r11-mock-scan)
- [API serializa Decimal como STRING no JSON — `typeof x === 'number'` no frontend falha em silêncio](#decimal-serializado-como-string-typeof-number-falha)
- [Deploy `--quick` pula o SCP INTEIRO, não só "arquivo novo" — código antigo compila e roda sem erro](#deploy-quick-pula-scp-inteiro-nao-so-arquivo-novo)
- [Classificador de handoff roda incondicionalmente ANTES do handler de confirmação — fix novo em `_processConfirmation` pode nascer morto](#classificador-handoff-intercepta-antes-do-handler-fix-inalcancavel)
- [Campo novo no contrato JSON entre 2 serviços deployados separadamente fica ausente no frontend se o backend for pra produção primeiro](#contrato-novo-precisa-dos-dois-deploys-juntos)
- [Chrome DevTools MCP recusa `new_page`/`navigate_page` com "browser already running" mesmo quando o próprio MCP perdeu o rastro do processo](#chrome-devtools-mcp-processo-orfao-trava-perfil)
- [Última página do path terminar em dígito é assinatura estrutural de "página de detalhe de catálogo" — genérico, não depende do CMS](#url-trailing-digit-catalog-detail-page)
- [Conversa longa com muitos screenshots: imagem nova passa a ser rejeitada mesmo pequena — é acúmulo, não tamanho do arquivo](#conversa-longa-limite-imagem-cumulativo)
- [Playwright `request.newContext({baseURL})` + rota com `/` no início apaga o path inteiro do baseURL (silencioso, 404 em tudo)](#playwright-baseurl-path-absoluto-apaga)
- [`storageState` cacheado de sessão OTP fica inválido entre rodadas separadas: refresh reativo dentro do browser nunca é gravado de volta em disco](#storagestate-refresh-reativo-nao-persiste)

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
O detalhe que faz o erro parecer insano: em cp1252, o **último byte** do em-dash (`E2 80 94`) é `94`,
que é a **aspa curva** `”` — e o PowerShell aceita aspa curva como delimitador de string. Dentro de uma
string, ela fecha a string cedo e o arquivo inteiro desanda. Os erros de parse apontam para linhas
**sem defeito nenhum**, às vezes dezenas de linhas depois. Em comentário é inofensivo (comentário vai
até o fim da linha) — o que explica por que alguns arquivos com acento nunca quebraram.

**Solução (mudou em 2026-07-30):** o `.ps1` pode ter não-ASCII, **desde que tenha BOM**. Grave como
UTF-8 **com** BOM e o 5.1 lê certo. Para adicionar BOM num arquivo existente, prepend de bytes —
nunca `Set-Content`/`Out-File`, que reescrevem o fim de linha e transformam um diff de 1 linha num
diff de arquivo inteiro:

```powershell
$b = [IO.File]::ReadAllBytes($f); [IO.File]::WriteAllBytes($f, (@(0xEF,0xBB,0xBF) + $b))
```

**A regra anterior era "100% ASCII" e é por isso que ela mudou:** regra sem gate é sugestão. Medido em
2026-07-30, **34** `.ps1` do kit violavam a regra ASCII — 16 deles nem parseavam no 5.1, e **3 eram
guardas de `PreToolUse`** (`external-action-guard`, `auth-import-pre-commit`, `types-check-pre-commit`)
que ficaram semanas **respondendo verde sem rodar**, porque o wrapper `.cmd` da época traduzia "script
morreu" em `exit 0`. A suíte não via nada disso: ela roda em pwsh 7, que lê UTF-8 por default.

Agora quem enforça é teste, não disciplina: `plugin/percus-review/tests/ps51-compat.tests.ps1` tem um
`It` que parseia **todo** `.ps1` do kit sob o `powershell.exe` real, e outro que barra **qualquer** byte
`> 0x7F` sem BOM — inclusive nos arquivos que hoje parseiam e só imprimem lixo, que o primeiro `It` não
enxerga.

**Ref:** spec `docs/superpowers/specs/2026-07-30-guardas-mortas-powershell-51-design.md`. A memória
`feedback_ps51_ascii_hooks` está **desatualizada** neste ponto. Relacionado:
[[guarda-fonte-strip-string]] — a mesma família de "guarda que dá verde sem guardar".

---

## Consertei o hook no repo, a suíte ficou verde, e a máquina continua com o comportamento velho {#plugin-cache-nao-recebe-fix}

`tags: plugin, marketplace, CLAUDE_PLUGIN_ROOT, cache, autoUpdate, hooks, republish, versao instalada, installed_plugins, drift`

**Sintoma.** Você corrige um hook em `plugin/percus-review/hooks/`, roda a suíte, fica verde, commita —
e o comportamento na máquina **não muda**. Pior: a suíte verde vira evidência de que está consertado.

**Causa raiz.** `hooks.json` invoca `${CLAUDE_PLUGIN_ROOT}/hooks/*.cmd`, e `CLAUDE_PLUGIN_ROOT` resolve
para o **plugin instalado em cache** (`<CLAUDE_CONFIG_DIR>/plugins/cache/<marketplace>/<plugin>/<versao>/`),
**não** para a cópia de trabalho do kit. O que você edita e o que roda são artefatos diferentes, e os
testes do repo só enxergam o primeiro.

**Agravante medido em 2026-07-30:** `autoUpdate` vem ligado por padrão **apenas** para marketplaces
oficiais da Anthropic. Para marketplace próprio vem **desligado** — então o cache congela na versão do
último `/plugin update` manual. Aqui ficou **26 dias** parado, e nesse intervalo três guardas de
`PreToolUse` estavam mortas respondendo verde sem ninguém ver.

**Como confirmar em 10 segundos** (o `gitCommitSha` é a prova dura — se não é o do seu commit, o que
roda não é o que você consertou):

```powershell
$j = Get-Content "$env:CLAUDE_CONFIG_DIR\plugins\installed_plugins.json" -Raw | ConvertFrom-Json
$j.plugins.'<plugin>@<marketplace>'[0] | Select-Object version, gitCommitSha, lastUpdated
```

**Solução — publicar, não copiar:**
1. bump da versão em `plugin.json` **e** em `.claude-plugin/marketplace.json`
2. `git push` pro branch default do repo (é dele que o marketplace lê)
3. `/plugin marketplace update <marketplace>`
4. `/plugin update <plugin>@<marketplace>`
5. `/reload-plugins`, ou simplesmente a próxima sessão

No VS Code os slash commands `/plugin` não funcionam; o equivalente é `claude plugin marketplace update <marketplace>`
e `claude plugin update <plugin>@<marketplace>` num terminal.

**E ligue o auto-update de uma vez**, em `extraKnownMarketplaces` no `settings.json`:

```json
"percus-tools": { "source": { "source": "github", "repo": "..." }, "autoUpdate": true }
```

**Não copie arquivo pro cache à mão.** Funciona na hora e apodrece depois: o próximo update
sobrescreve, o cleanup de 14 dias apaga versão órfã, e o `installed_plugins.json` passa a mentir sobre
o que está rodando. Havia precedente disso no changelog do kit — era gambiarra, não referência.

**O que continua manual:** o `git pull` do próprio kit. O auto-update cuida do plugin em cache, não da
cópia de trabalho que o `PERCUS_CANON_DIR` aponta e de onde os gates de commit leem.

**Ref.** spec `docs/superpowers/specs/2026-07-30-guardas-mortas-powershell-51-design.md`;
`CANON_VERSION.md` v6.32.0. Relacionado: [[ps51-ascii-hooks]] — o defeito que ficou escondido atrás
disto.

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

## Escrever em outro repo: caixa/arquivo — exceção é a pasta comum `conhecimento\` {#cross-repo-write}

`tags: cross-repo, canon, write, commit, outro projeto, protocolo, caixa de texto, conhecimento, mover arquivo, exceção`

**Contexto:** uma sessão de um projeto (ex.: Coach, tiatendo) precisa propagar algo pra outro repo —
outro produto, ou o canon (`percus-kit`).

**Regra geral:** pra escrever em **qualquer outro repo**, NÃO edite o repo de destino direto —
entregue **texto numa caixa ou num arquivo** pro outro projeto aplicar nele mesmo. Leitura cross-repo
é livre; escrita não. Vale pros dois sentidos: projeto → projeto **e** canon → projeto (o canon
nunca faz `git mv/cp/rm` pra fora dele).

⚠️ **Exceção única (operador, 2026-07-23):** os **arquivos comuns entre projetos que ficam em
`D:\Claud Automations\percus-kit\conhecimento\`** — esses qualquer sessão **escreve e commita
direto**. É onde mora o conhecimento cross-projeto (R23: este `COMO_RESOLVER.md`), sincronizado via
`git pull`; obrigar caixa de texto pro próprio repositório de aprendizado só perderia o aprendizado.
**A exceção é a pasta `conhecimento\`, NÃO o canon inteiro** — a raiz do canon
(`01_REGRAS_INEGOCIAVEIS.md`, `02..06`, `CANON_VERSION.md`, plugin) segue a regra geral: mudança ali
vai por caixa/arquivo pro operador aplicar. Regra curta: **`conhecimento\` → escreve direto; qualquer
outro alvo → caixa de texto.**

**Ao commitar em `conhecimento\` vindo de outro projeto:** stage **seletivo** — commite só os arquivos
que você tocou; a árvore do canon costuma ter trabalho em voo de outra sessão (em 23/07 havia
`01_REGRAS_INEGOCIAVEIS.md` modificado por outra frente). Gate R11 com `Set-Location` no repo do
canon, em chamada separada do commit (PreToolUse).

**Ref:** memória `feedback_cross_repo_write_protocol` (reforçado 2026-05-30). Exceção adicionada
2026-07-23 (Família Milionária) e **estreitada de "canon inteiro" para `conhecimento\`** na mesma
data a pedido do operador (sessão tiatendo).

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

**Causa raiz:** NÃO é volume de mensagem — é **`usync` 429 `rate-overlimit`**. WhatsApp rate-limita as queries **usync** (`GET /user/info`, `GET /user/check` — checagem de número / info de contato) **por-conexão-de-device**, muito mais agressivo que envio; um número cold tem orçamento minúsculo. As fontes de usync são **invisíveis ao "volume de mensagem"**:
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
1. **Task fica `0/1`, container em "created"/"Starting", crash-loopa, `docker service logs` VAZIO.** `journalctl -u docker` mostra `pull access denied for <img>, repository does not exist`. **Causa raiz:** imagem construída LOCAL no nó não tem digest de registry; o Swarm tenta puxá-la de `docker.io` a cada (re)start de task. O `create` inicial pode rodar do local, mas os restarts pullam → nega. **Fix:** `docker stack deploy --resolve-image never -c stack.yml <stack>` (obrigatório p/ imagem local). Se o spec já quebrou, `docker stack rm` + redeploy limpo com a flag. Alternativa: referenciar a imagem pelo ID `sha256:...` (não pulla).
2. **App não boota — `IndexError` em `Path(__file__).resolve().parents[N]`.** Código calcula a raiz do repo por profundidade de path; no container a árvore é achatada (`/app/app/core/config.py` tem menos `parents` que o layout de dev `services/api/app/core/...`). **Fix:** guardar o índice — `_p = ...parents; root = _p[N] if len(_p) > N else Path("nonexistent")`. Em prod a config vem de env vars, não do `.env` em disco.
3. **Worker ARQ fica `0/1` pra sempre (mesmo rodando e conectado ao Redis).** O serviço herda o `HEALTHCHECK` do Dockerfile (que bate em `:8000/health`), mas o worker não sobe HTTP → unhealthy eterno, nunca vira Running. **Fix:** `healthcheck: test: ["NONE"]` no serviço worker do stack.
4. **Reachability das deps compartilhadas:** Redis desse VPS NÃO publica porta no host — só service-DNS na overlay (`redis://...@redis_redis:6379`); então TODOS os serviços que usam Redis (inclusive worker) precisam entrar na rede **`network_swarm_public`** (external). Postgres publica `161.97.129.138:5432` (dá pra usar via host). Traefik: entrypoint `websecure` + `certresolver=letsencryptresolver` (espelhar labels de um service irmão como `auth_service_api`).

**Diagnóstico geral:** quando o container "created"/log-vazio confunde, **rode a imagem à mão** (`docker run --rm --env-file .env --network network_swarm_public <img> <cmd>`) — separa "app/env quebrado" de "problema de orquestração do Swarm".

**Ref:** Scraper-prospeccao deploy 2026-07-10 (backend LIVE em `scraper.huboperacional.com.br`), commits `9b1da80`+`450a636`; `docs/DEPLOY.md` §Deploy executado; memória `reference_deploy_swarm_local_image_gotchas`.

---

## Skill do plugin referida como slash command (`/percus-review:checkpoint`) — não existe {#skill-nao-e-slash}

`tags: skill, slash command, checkpoint, feature-flow, consult-knowledge, plugin, percus-review, namespace, invocacao, command not found, autocomplete, SKILLS_VS_COMMANDS`

**Sintoma:** um HANDOFF/doc/agente manda "rode `/percus-review:checkpoint`" (ou `/percus-review:feature-flow`, `/percus-review:consult-knowledge`…) e o command **não existe** — não aparece no autocomplete, "command not found".

**Causa raiz:** `checkpoint` e cia. são **skills**, não **slash commands**. No plugin `percus-review`, só o que está em `commands/*.md` é slash (review, milestone-review, deepseek-review, cross-claude-review, spec-analyze, install-git-hooks, version → `/percus-review:<nome>`; os 4 do conselho declaram `name: council:*` no frontmatter e têm namespace próprio a confirmar — ver `comandos/SKILLS_VS_COMMANDS.md`). O que está em `skills/<nome>/SKILL.md` (checkpoint, feature-flow, consult-knowledge, close-milestone, delegate-impl, auth-consumer, security-audit, tracking-audit, cookie-audit, pages-scan, port-allocate, catalog-publish) **não tem slash**. Agrava: o namespace de skill é **instável** — numa instalação real apareceu como `6.28.0:checkpoint` (a **versão** como namespace, não `percus-review:`), então nem `/6.28.0:checkpoint` é confiável entre bumps. O erro nasce de extrapolar `/percus-review:review` (que É command) pras skills.

**Solução:** skill invoca-se por **linguagem natural** — o user descreve a intenção ("faça o checkpoint deste milestone", "consulte o que já sabemos sobre X") e o **agente invoca via `Skill` tool**. Nunca escreva "rode `/percus-review:<skill>`" num doc/HANDOFF/template. Inventário completo (11 commands × 12 skills) + regra de ouro: `comandos/SKILLS_VS_COMMANDS.md`.

**Ref:** confusão diagnosticada 2026-07-11 (operador não achou `/percus-review:checkpoint`); inventário em `comandos/SKILLS_VS_COMMANDS.md`; regra R23.

---

## Cross-Claude do conselho retorna 400 — `temperature` num modelo Opus 4.7+ {#cross-claude-400-sampling}

`tags: council, conselho, cross-claude, pre-mortem, 400, temperature, sampling params, top_p, top_k, opus-4-7, sonnet-5, fable-5, anthropic api, orchestrator, model id, catalogo`

**Sintoma:** no conselho 3-membros (`council-orchestrator`), o **cross-claude falha com 400** — tipicamente no modo **pre-mortem**; consult e review passam. O agente cai no fallback (coleta a 3ª voz via subagent Sonnet, marker `__PERCUS_NEEDS_CROSS_CLAUDE__`).

**Causa raiz:** o wrapper `providers/cross-claude.ps1` enviava `temperature` no body da chamada à Anthropic. A família **Opus 4.7 / Opus 4.8 / Sonnet 5 / Fable 5 REMOVEU os sampling params** (`temperature`/`top_p`/`top_k`) — a API retorna **400 `invalid_request_error`** ("temperature: Extra inputs are not permitted") se recebê-los. O router escolhe o modelo por modo: pre-mortem → `claude-opus-4-7` (**rejeita**), review/analyze → `claude-sonnet-4-6` (aceita), consult → `claude-haiku-4-5` (aceita). Por isso só o pre-mortem quebrava "toda hora". ⚠️ **Os model IDs em si são VÁLIDOS** — `sonnet-4-6` e `opus-4-7` estão ativos no catálogo; a armadilha é acusar o ID de "inválido" quando o problema é o *parâmetro*.

**Solução:** (1) **não enviar `temperature`/`top_p`/`top_k`** — o mais simples e à prova de futuro é remover do body de vez (steering vai por prompt, não por sampling); assim o router pode migrar pra Sonnet 5 / Opus 4.8 sem quebrar. (2) O `catch` do wrapper deve expor `$_.ErrorDetails.Message` (corpo JSON do erro da Anthropic), não só `$_.Exception.Message` — que num 400 é o cego "(400) Bad Request". (3) **Antes de acusar um model ID de inválido, conferir no catálogo autoritativo** (skill `claude-api` → seção "Current Models" / `shared/models.md`), **nunca de memória**.

**Ref:** fix 2026-07-11, commit `adbe3a4` (`plugin/percus-review/providers/cross-claude.ps1`); cópia instalada patchada por `cp` na mesma sessão. Router de modelo por modo: `council-orchestrator.ps1` (F.2, `$CrossClaudeModel` switch).

---

## Next `next build` quebra ("Failed to collect page data") com client instanciado no top-level {#next-build-eager-client}

`tags: next, nextjs, app router, build, docker, stripe, collect page data, useContext, standalone, route handler, env, secret, lazy, getStripe`

**Sintoma:** `next build` (produção/container) falha com `Failed to collect page data for /api/<rota>` (às vezes acompanhado de stack em `webpack-runtime`). O `next dev` funciona normal, e por isso "verifiquei no dev, tá 200" **não** garante que o build passa. Frequente em deploy de container (1º build real).

**Causa raiz:** o `next build` **avalia (importa) os módulos das rotas** na fase "collect page data" — **sem os secrets de runtime**. Se uma lib importada pela rota **instancia no top-level** um client que **joga quando falta credencial**, o import explode e o build morre. Caso clássico: `export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)` — no build `STRIPE_SECRET_KEY` é undefined e o construtor do Stripe joga. Vale pra qualquer SDK que exija credencial no construtor (Stripe, alguns clients GHL/AWS/etc.).

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

## Gate de confirmação/escolha nunca pode ter dead-end infinito (cancel-escape + retry→escala) {#gate-confirmacao-dead-end}

`tags: gate, confirmacao, escolha, dead-end, loop infinito, cancel-escape, retry counter, escalar humano, conversa burra, bot, readback, disambiguacao, tamanho, pizza`

**Sintoma:** um "micro-confirm" ou gate de escolha (bot pergunta "Confirma? sim/troca") trata como erro qualquer resposta que não seja o esperado — o usuário corrige/cancela/pergunta ("eu não pedi X, pedi Y") e leva um template "Não reconheci essa opção" em loop. É "conversa burra" nascida DA PRÓPRIA feature de confirmação.

**Causa raiz:** o gate tem só 2 saídas (sim | re-tentar a mesma extração) e a saída de falha é um `return template` sem estado — nenhum ramo pra cancelamento/correção-fora-de-banda, e nenhum contador que quebre o loop.

**Solução (padrão, tiatendo `restaurantOrderFlow.py` gate de sabor, smoke 2026-07-12):** todo gate de confirmação/escolha ganha 3 propriedades, espelhando um gate já-robusto do mesmo código se existir (aqui o disambig de tamanho):
1. **Cancel-escape** ANTES do match: regex de cancelamento ("cancela/deixa pra lá/não quero mais") tira o item/encerra o passo, em vez de re-extrair.
2. **Retry-counter que ESCALA** pro humano na Nª tentativa seguida (ex. 3), em vez de repetir o template pra sempre. Contador no estado persistido, zerado no sucesso.
3. **Re-ask que ECOA o contexto** (ex. o tamanho já escolhido) — dissolve o mal-entendido na origem, não só repete a pergunta.

Corolário de wording: em domínio com dimensões colidentes (pizza P/M/**G** onde M=Média), NUNCA use a mesma palavra ("média") pra outra coisa (método de preço) — o usuário lê como a dimensão. Ecoe sempre a dimensão fixada no readback.

**Ref:** smoke WhatsApp 2026-07-12 (Bug A/B); commit `ef74467`; memória `project-pizza-smoke-fixes-e-loja-web-2026-07-12`.

---

## Hook pre-commit (R11) é PreToolUse: "review && commit" numa chamada só sempre bloqueia {#pretooluse-review-commit}

`tags: pre-commit, hook, PreToolUse, percus-review-auto, marker stale, R11, git commit bloqueado, review antes de commit, chamada separada`

**Contexto:** o hook `pre-commit-check` bloqueia `git commit` se o último `.deepseek/reviews/*.jsonl` tem >5min. A tentação é encadear `git add ... && pwsh percus-review-auto.ps1 && git commit` numa **única** chamada Bash — e ela é bloqueada mesmo depois do review rodar.

**Causa raiz:** o hook é **PreToolUse** (inspeciona o comando Bash e barra ANTES de executá-lo), não um git hook nativo. Ele vê o `git commit` no comando e checa a freshness do marker **no instante do pre-check** — quando o `percus-review-auto.ps1` do mesmo comando ainda NÃO rodou. Marker velho → bloqueia o comando inteiro (o review nem chega a rodar). (Observado também: ele barra `cat >>`/writes a arquivos tracked do repo com marker velho.)

**Solução:** rodar o review em uma chamada Bash **SEPARADA** do commit:
1. `git add <arquivos>`
2. (chamada separada) `pwsh -File "...\percus-review-auto.ps1"` — escreve o marker fresco.
3. (chamada separada) `git commit ...` — agora o pre-check vê o marker <5min e passa.
Corolário: o review com **diff vazio** (nada staged/tracked) NÃO escreve marker — stage o arquivo antes de rodar o review. O marker vale ~5min: em features com muitos commits, re-rode antes de cada commit fora da janela.

**Ref:** sessão Session Resume auth-service 2026-07-12; memória `session_resume_implementado_2026-07-12`.

---

## `importlib.reload(config)` num teste polui a suite inteira (quebra testes que rodam depois) {#reload-config-polui-suite}

`tags: pytest, pollution, poluicao, importlib reload, get_settings, lru_cache, ordem de testes, falha fantasma, webhook, teste isolado passa suite falha, Settings, dependency_overrides`

**Contexto:** um teste novo passa isolado, mas rodando a suite completa aparecem N falhas **fantasma** em arquivos NÃO relacionados (ex.: webhook signature tests) que rodam DEPOIS dele. Remover só o teste novo → suite verde de novo.

**Causa raiz:** o teste faz `importlib.reload(app.core.config)` (ou de outro módulo core) pra reler env. Reload cria um **novo** objeto `get_settings`/`Settings`, mas todos os módulos já importados (`app.main`, routers, handlers) seguram a referência ANTIGA de `get_settings` (bound no import-time). Ficam DUAS caches `lru_cache` dessincronizadas + um `Settings` novo ≠ o que o app usa. Testes posteriores que leem settings (ex. um secret de webhook) pegam valores inconsistentes → assert falha.

**Solução:** **nunca `importlib.reload` de módulo core no meio da suite.** Pra testar binding de env/flags, instancie `Settings()` **direto** (fresh, lê o env no construtor), sem tocar o singleton nem a cache:
```python
def test_flag(monkeypatch):
    monkeypatch.setenv("MY_FLAG", "true")
    from app.core.config import Settings
    assert Settings().my_flag is True
```
`monkeypatch` reverte o env no teardown; zero estado compartilhado mutado. **Triagem:** teste isolado passa + suite falha em arquivo alheio ⇒ suspeite de poluição (reload / `dependency_overrides` não limpo / cache mutada), não do produto.

**Ref:** sessão Session Resume auth-service 2026-07-12 (11 falhas fantasma em webhook tests); fix commit `603759e`.

---

## Fix editado DEPOIS do `add` fica fora do commit — review revisa versão limpa, commit embarca a buggy {#staging-pos-review-drift}

`tags: git stage staged add diff review commit stale fix hook marker`

**Sintoma:** você roda a review (R11), ela aponta um bug, você corrige o arquivo, mas o commit embarca a versão SEM o fix. O `git status` mostra o arquivo como `MM` (staged + working-tree divergem): o stage capturou o estado ANTES da correção; as edições pós-stage ficaram só no working tree.

**Como pegou (2026-07-12, tiatendo billing):** o Cross-Claude comparou `git diff --cached` (staged) vs `git diff` (working) e viu que o guard de refund/chargeback (não regride `canceled` terminal) existia no working tree mas NÃO no índice → o commit ali embarcaria o bug. O DeepSeek, que só olhou o staged, apontou o mesmo bug como "não corrigido" — porque de fato o fix não estava staged.

**Solução:** depois de QUALQUER edição pós-review (fixes de findings, ajustes), **re-adicione ao índice todos os arquivos tocados ANTES de fechar o commit**. Confirme com `git status --short`: nenhum `MM`/` M` nos arquivos do escopo; tudo `M `/`A ` (staged limpo). Regra: o gate de review roda sobre o MESMO conteúdo que vai pro commit — editou depois, re-stage.

**Generaliza:** vale pra qualquer gate que inspeciona staged (mock-scan, types-check). Editar após o gate e fechar o commit sem re-stage fura o gate silenciosamente. Um 2º revisor (Cross-Claude) que compara staged vs working é o que pega — peça a comparação explícita quando o diff for sensível (pagamento/migrations).

**Ref:** tiatendo billing (2026-07-12) — o Cross-Claude comparou `git diff --cached` vs `git diff` e pegou o guard de refund/chargeback fora do índice.

---

## Side-effect flag-gated não dispara: cred provavelmente já existe self-hosted no VPS {#cred-selfhosted-no-vps}

`tags: side-effect, flag-gated, credencial, env var, gowa, google sheets, ghl, leadconnector, private integration token, docker service update, env-add, portainer, stack deploy, pydantic extra ignore, service account, sheets api disabled`

**Contexto:** huboperacional-site `/new-client` (2026-07-12). Endpoint no Painel tem 3 side-effects best-effort (GOWA WhatsApp, Google Sheets, GHL) gated pela presença da cred no `.env`. Operador reportou "nada veio". Nada estava quebrado — os clientes logam skip por design quando a cred falta.

**Resolução — procure a cred nos containers do VPS antes de pedir ao operador:**
- Listar serviços/containers: `docker service ls`, `docker ps` — procure o serviço da integração (ex: `gowa_whatsapp`, `ghlgowa_adapter`, `evolution_*`).
- Puxar a cred de um serviço-irmão que já usa a integração: `docker exec <adapter> printenv | grep -iE "gowa|ghl|google|token|auth"`. O adapter que já fala com o serviço tem a URL base + auth + o formato exato do request.
- **GOWA aqui é self-hosted:** serviço `gowa_whatsapp` (`gowa-operator`, **multi-device**) em `https://gowa.huboperacional.com.br`. Enviar: `POST /send/message` JSON `{phone, message}` + Basic auth + **header `X-Device-Id: <device>`** (device "Notificador"). Descobrir devices: `GET /devices`. Confirmar formato lendo o código do adapter (`ghlgowa_adapter` → `dist/gowa/gowa.service.js`).
- **Normalização de telefone BR:** GOWA/WhatsApp exige E.164 com país; se o form salvou sem 55, prepend `55` quando `len(digits) in (10,11)`.
- **Setar a cred no service sem stack file:** `docker service update --env-add "VAR=valor" <service>`. **Pega**: sobrevive a `service update --image`, mas **um `docker stack deploy` do Portainer sem a var no compose apaga** — adicionar ao stack canônico depois.

**Google Sheets — armadilha "API disabled":** reusar um service-account de outro projeto (ex: `plexco-backend` `GCP_SA_KEY_JSON`) falha com `403 Sheets API has not been used in project N or it is disabled` se o **projeto do SA não tem a Sheets API habilitada**. Testar acesso ANTES de escrever na planilha de produção: `spreadsheets().get(spreadsheetId=...)` (read-only). Blindagem: SA precisa (1) Sheets API habilitada no projeto dele; (2) a planilha compartilhada como Editor com o `client_email`.

**Persistir a env var no stack (2026-07-13, fecha o gap do `--env-add`):**
- Descobrir se o stack é Portainer ou CLI: `grep -rl "<namespace-ou-host>" /var/lib/docker/volumes/portainer_data/_data/compose`. **Vazio ⇒ CLI-managed** — o arquivo autoritativo é o compose em `/opt/<svc>/docker-compose*.yml` (deploy via `docker stack deploy -c ...`). Se casar, é Portainer e você edita a cópia dele.
- O compose do `ads4pros-api` usa `environment:` **inline** (sem `env_file`) e o container **não tem `.env`** — então `.env` no host ou no repo NÃO chega no app. Persistir = adicionar a linha ao bloco `environment:`.
- **JSON grande (service-account) em YAML:** compacte pra uma linha (`json.dumps(json.loads(x), separators=(',',':'))`) e embrulhe em **single-quote YAML** (`- 'GOOGLE_SA_JSON={...}'`) — JSON só tem aspas duplas, então single-quote é seguro sem escape. Valide sem deployar: `docker stack config -c <compose>` (parseia YAML+schema) + round-trip `json.loads`. NÃO redeploy só pra isso (o service vivo já tem via `--env-add`).

**GHL (LeadConnector) — NÃO existe token estático reusável nos adapters (2026-07-13):** os adapters do marketplace (`ghlgowa_adapter`/`ghlevo_adapter`) são apps **OAuth** — access tokens **por-location que expiram e rotacionam**, guardados no DB do adapter (`whatsapp_ghl.GhlInstallation`). ⚠️ **NÃO refrescar** o token OAuth do adapter pra reusar: o refresh rotaciona e **quebra o próprio adapter em prod** pra aquela location. Um backend que consome a API GHL v2 (`services.leadconnectorhq.com`, `Authorization: Bearer`, `Version: 2021-07-28`) precisa de um **Private Integration Token** estático (`pit-…`) criado pelo operador na sub-account (Settings → Private Integrations, scopes `contacts.write`+`opportunities.write`). Validar + mapear em um passo: `GET /opportunities/pipelines?locationId=<loc>` com o PIT (HTTP 200 confirma token+location e devolve `pipelineId`/`pipelineStageId`; escolher o stage inicial real, ex. "New Lead", não "Desconsiderar").

**Env var setada mas `settings.X` continua vazio → nome errado engolido pelo pydantic:** `SettingsConfigDict(extra="ignore")` faz o pydantic **descartar em silêncio** env vars com nome que não casa com um campo (ex.: operador pôs `GHL_PRIVATE_TOKEN`/`GHL_SUBACCOUNT_ID`, config espera `GHL_TOKEN`/`GHL_LOCATION_ID`). Sem erro, sem log. Diagnóstico definitivo: `docker exec <cid> python3 -c "from execution.core.config import settings as s; print(len(s.ghl_token or ''))"` — se 0 apesar da var "existir", confira (a) o **nome exato** do campo no `config.py`, (b) se o arquivo/env realmente chega no container (`printenv` dentro do container é a verdade, não o `.env` do host).

**Ref:** huboperacional-site `/new-client` (2026-07-12) + persistência da env var no stack e PIT do GHL (2026-07-13).

---

## Falha na suite completa fora do teu diff → triar pollution/pré-existente ANTES de assumir culpa {#falha-fora-do-diff-triagem}

`tags: pytest, suite completa, falha fantasma, ordering pollution, pre-existente, MultipleResultsFound, db de teste sujo, rodar isolado, git checkout base, fixture autouse, seed idempotente`

**Contexto:** auth-service /sso hardening (2026-07-14). A suite full deu `830 passed, 2 failed`, mas as 2 falhas eram em módulos que eu NÃO toquei (`tests/contracts/test_magic_v2.py` TTL + `test_resolve_org_v2.py` audit). Meu diff só mexeu em `redirect.py`/`sso`/`session` + testes deles. Assumir "quebrei algo" teria feito eu perseguir fantasma.

**Resolução — 2 checagens baratas, nesta ordem, antes de tocar em qualquer coisa:**
1. **Rodar as falhas ISOLADAS** (só elas, `pytest path::Class::test`). Se **passa isolada mas falha na suite** → é **ordering-pollution** (estado de DB/singleton deixado por outro teste no mesmo processo), não regressão tua. (Foi o caso do `test_resolve_org_v2` audit.)
2. **Rodar a falha que persiste isolada em `main` LIMPO** (tudo commitado → `git checkout <base>` detached, roda o único teste, `git checkout <branch>` de volta). Se **falha igual em main sem o teu diff** → é **pré-existente**, não tua. (Foi o `test_magic_v2` TTL: `MultipleResultsFound` = linhas duplicadas no DB de teste `percus_auth_test`, presente em `main`.)

**Regra:** `N passed, M failed` numa suite grande NÃO é "quebrei M" — é "M falham NESTE estado de DB/ordering". `MultipleResultsFound`/`.one()`/`scalar_one()` estourando é quase sempre **dado sujo acumulado no DB de teste compartilhado** (INSERTs de testes sem cleanup ao longo do tempo), não código. Um `UPDATE`-only seed (como o meu `_seed_sso_origins`) NUNCA cria duplicata — descarta essa hipótese de cara.

**Blindagem do próprio teste (pre-mortem pegou):** teste DB-gated que depende de estado de linha (origins, ttl) num DB compartilhado é frágil. Semeie o estado que ele assume com um **fixture autouse idempotente (UPDATE)** — remove o acoplamento oculto e evita false-pass/false-fail por drift do DB. Cross-ref feedback_subagent_db_tests_env.

**Ref:** auth-service /sso hardening (2026-07-14) — `830 passed, 2 failed`, ambas alheias ao diff. Memória `feedback_subagent_db_tests_env`.

---

## Deploy: `docker build ... | tail && service update` mascara build falho → outage {#deploy-pipe-mascara-exit}

`tags: deploy, docker build, pipe, exit code, tail, swarm, service update, outage, 404, rollback, ci`

**Contexto:** deploy num VPS Docker Swarm encadeando `docker build ... | tail -25 && docker service update --image X --force`. O `npm install` do build falhou (blip de rede), mas o `service update` rodou mesmo assim → Swarm parou a task antiga pra subir uma imagem inexistente → **404 em prod (~1min)**.

**Causa raiz:** o exit code de um **pipeline** é o do ÚLTIMO comando (`tail`, sempre 0). O `&&` viu "sucesso" e seguiu pro update, apesar do `docker build` ter falhado.

**Solução:** build e `service update` em passos **SEPARADOS**. Capturar `docker build ...; echo BUILD_EXIT=$?` e só atualizar o service se `BUILD_EXIT=0` (nunca `build | tail && update`). Ter o **rollback declarado** antes de deployar (`docker service update --image <versao-anterior> --force <service>` converge ~5s; as imagens antigas ficam no host — `docker image ls`). Blip de npm no build é transitório → retry do build isolado resolve.

**Ref:** huboperacional-site deploy v0.3.4 (2026-07-14); memória de projeto `deploy-vps-gotchas`.

---

## `NEXT_PUBLIC_*` não aparece no bundle client em prod {#next-public-baked-build}

`tags: next.js, next_public, env, build arg, dockerfile, inline, bundle, client, ga4, gtag, compose runtime`

**Contexto:** setei `NEXT_PUBLIC_GA_ID` no bloco `environment:` do docker-compose (runtime) e a feature (banner/GA) ficou **inerte em prod** — o componente client leu `undefined`. (Falha *safe*, mas a feature não funciona.)

**Causa raiz:** `NEXT_PUBLIC_*` é **inlined no bundle em BUILD time** (`next build`), não lido em runtime. Uma env var só presente no compose/runtime nunca chega ao bundle client já compilado.

**Solução:** passar a var no **build** — no `Dockerfile`, `ARG NEXT_PUBLIC_FOO` + `ENV NEXT_PUBLIC_FOO=$NEXT_PUBLIC_FOO` ANTES do `RUN npm run build` (default no ARG pra valores públicos como um GA Measurement ID; `--build-arg NEXT_PUBLIC_FOO=` vazio pra desabilitar em staging). Sintoma de detecção: `curl <chunk _next/static>.js | grep <valor>` — se não achar, não foi baked.

**Ref:** huboperacional-site GA4 (2026-07-14); achado de code-review; memória `deploy-vps-gotchas`.

---

## "Erro de conexão" no front que é, na verdade, um 500 do backend {#erro-de-conexao-e-500-sem-cors}

`tags: cors, fastapi, starlette, 500, fetch, failed to fetch, network error, erro de conexao, unhandled exception, asyncpg, UndefinedColumnError, middleware`

**Contexto:** login (OTP) do painel mostrava "Erro de conexão. Verifique sua internet" com código válido, mas só nesse caminho. `curl` do endpoint com payload dummy dava 401 **com** headers CORS (normal). A tela mentia: não era rede.

**Causa raiz:** o `catch` de um `fetch` cross-origin dispara "Erro de conexão" quando o browser **bloqueia a resposta por falta de CORS** — não só em rede caída. No FastAPI/Starlette, `HTTPException` tratada volta pelo `ExceptionMiddleware` → passa pelo `CORSMiddleware` → **ganha** os headers CORS (fetch lê o status). Mas uma **exceção não-tratada** sobe até o `ServerErrorMiddleware` (o mais externo, acima do CORS) → 500 **sem** headers CORS → o browser rejeita como erro de rede → `fetch` **lança** → cai no `catch`. No caso real: `asyncpg.UndefinedColumnError` (coluna faltando após migration não-aplicada) só no caminho de código válido.

**Solução:** (1) diagnóstico — se o front diz "erro de conexão" mas o endpoint responde via `curl`, cheque o **status + headers CORS** da resposta real do fluxo que falha (dummy vs válido divergem quando o crash é depois da validação). 500-sem-`Access-Control-Allow-Origin` = crash não-tratado. (2) fix na raiz (a exceção). (3) defesa: envolver o trecho arriscado e converter em `HTTPException` (que ganha CORS) pra o erro chegar legível no front, nunca como "erro de conexão".

**Ref:** Painel Gestão admin login B3 (2026-07-14); `execution/api/adminAuth/adminVerifier.py` + `migration008`.

---

## Consumir `/internal/identities/v2` do auth-service: `name`, não `display_name` {#identities-v2-exige-name}

`tags: auth-service, identities, v2, IdentityCreateV2, name, display_name, origin, extra forbid, 422, provisionamento, identity_id`

**Contexto:** provisionamento de identidade no signup falhava **422** silencioso (`{"type":"missing","loc":["body","name"]}`) → `identity_id` ficava NULL → usuário sem login. O cliente mandava `{email, phone, display_name, origin}`.

**Causa raiz:** `IdentityCreateV2` (`app/modules/identity/schemas.py`) exige **`name`** (mapeia pra coluna `display_name`), `email` e `phone` — e tem **`extra="forbid"`**. Então `display_name` e `origin` no corpo geram DOIS erros: `missing name` + `extra_forbidden`. O `origin` é **derivado server-side** do `consumer_id` (anti-impersonation) e não deve ser enviado (use `origin_context` se precisar de sub-contexto).

**Solução:** payload correto do V2 = `{"name": <display>, "email": <e>, "phone": <p>}` (só isso; nada de `display_name`/`origin`). Verificar rápido: `curl` com o payload novo → 200; com o antigo → 422 com os 3 erros. Resposta ainda traz `display_name`/`origin` (só a ESCRITA que mudou).

**Ref:** Painel Gestão affiliate-signup (2026-07-14); `execution/integrations/authServiceClient.py:createOrGetIdentity`.

---

## `docker stack deploy` rola serviços pra trás quando o swarm.yml está com pins stale {#stack-deploy-swarm-pins-stale}

`tags: docker swarm, stack deploy, docker-compose.swarm.yml, image pin, sha, rollback, service update, drift, deploy, ENOMEM, GHCR`

**Contexto:** deploy de um serviço (web) via `docker stack deploy -c docker-compose.swarm.yml <stack>` (comando padrão do runbook). Em vez de só atualizar o web, o comando **rolou web+tracking+worker pra trás** pra versões antigas — o worker ficou 0/1 (down) ~2min. O site continuou de pé (imagem velha), mas foi regressão.

**Causa raiz:** `docker stack deploy` reconcilia **TODOS** os serviços do stack pro que o swarm.yml declara. O swarm.yml estava **stale**: pinava shas antigos (`sha-afb0299`, tag `onda6`) porque deploys recentes foram feitos com `docker service update --image sha-NOVO <svc>` direto — e isso **NÃO atualiza o swarm.yml**. Então o arquivo de deploy divergiu do que rodava em prod, e o stack deploy "corrigiu" tudo pro estado velho do arquivo (incl. uma tag `onda6` que nem existia mais → 0/1).

**Solução:** (1) diagnóstico — comparar `grep image: docker-compose.swarm.yml` com `docker service ls --format '{{.Name}} {{.Image}}'`; se divergirem, o stack deploy vai rolar pro yml. (2) recovery imediato — restaurar cada serviço com `docker service update --with-registry-auth --image ghcr.io/.../paid-media-<svc>:sha-<correto> paid-media_<svc>` (os shas corretos vêm do STATUS.md/últimos deploys; confirmar que são commits reais com `git log --oneline -1 <sha>`). (3) fix da raiz — editar os pins do swarm.yml pros shas que rodam em prod e commitar, pra o `docker stack deploy` voltar a ser seguro. **REGRA: antes de `docker stack deploy`, sempre conferir `docker service ls` vs pins do yml; se for só um serviço, prefira `docker service update --image` (não toca os outros).**

**Ref:** Paid Media Automation deploy da reestruturação da aba Tracking (2026-07-14, cont.100); fix `6192c82`; [[reference_swarm_yml_is_deploy_file]], [[reference_deploy_traps]].

---

## Rodar testes que dropam tabelas contra Postgres efêmero isolado (sem Docker/PG local, nunca prod) {#pg-efemero-testes-destrutivos}

`tags: pytest, integração, TEST_DATABASE_URL, postgres, pgvector, docker swarm, throwaway, ephemeral, setupDatabase, runMigrations, ledger, cash, fixture drop table, in-container, lead_profiles does not exist, working-tree mount`

**Contexto:** fixtures de integração (ledger/caixa) fazem `DROP TABLE ... CASCADE` + `runMigrations()` — precisam de Postgres real mas NUNCA podem tocar prod. Máquina local sem Docker nem PG; a imagem de prod (`ads4pros/tiatendo:0.20x`) não tem pytest e carrega o `execution/` do último deploy (não o working-tree com o código novo/uncommitted).

**Procedimento (via ssh no VPS que tem Docker):**
1. Rede + PG descartável: `docker network create ledgertest-net`; `docker run -d --name pg-ledger --network ledgertest-net -e POSTGRES_PASSWORD=test -e POSTGRES_DB=tiatendo_ledger_test pgvector/pgvector:pg17`; esperar `docker exec pg-ledger pg_isready -U postgres`.
2. **Pré-buildar o schema base ANTES do pytest** — o fixture só dropa+runMigrations e ASSUME a base existente: `docker run --rm --network ledgertest-net -v /root/wt/execution:/app/execution -e DATABASE_URL=<dsn> <img> python -c "import asyncio; from execution.database.setupDb import setupDatabase; asyncio.run(setupDatabase())"`. Sem isso: `relation "lead_profiles" does not exist` (a base vem do `setupDb.SCHEMA`, NÃO das migrations numeradas 030+).
3. Rodar pytest num throwaway com o **working-tree montado** (`-v /root/wt/execution:/app/execution -v .../tests:/app/tests -v .../scripts:/app/scripts`) + `TEST_DATABASE_URL`=`DATABASE_URL`=dsn efêmero + `pip install -q pytest pytest-asyncio` (não vem na imagem prod).
4. Cleanup SEMPRE (mesmo em falha): `docker rm -f pg-ledger; docker network rm ledgertest-net`.

**Gotchas:** (a) working-tree via `tar cf - --exclude=__pycache__ execution tests scripts | ssh 'cd /root/wt && tar xf -'` — `git archive HEAD` NÃO pega uncommitted; (b) `docker run ... | tail` mascara o exit-code do pytest (vira o do `tail`) → redirecionar pra arquivo, checar `$?` e grep do sumário; (c) guard nos fixtures: `pytest.skip` se o nome do db do dsn não contém "test" (defesa contra apontar pra prod); (d) ao delta-deployar, incluir `scripts/` no COPY se o operador for rodar backfill (o delta que só copia `execution/` deixa `scripts/backfillLedger` de fora).

**Ref:** tiatendo ledger F1+F2 `[5-T]` (2026-07-14); `tests/restaurant/test_ledgerService_integration.py`, `test_ledgerDualWrite.py`. [[project-ledger-t3-f1-2026-07-14]]

---

## Preciso verificar que uma página admin/dashboard renderiza, mas o MCP de browser caiu / precisa login {#render-smoke-in-container}

`tags: render smoke container docker admin dashboard browser login template`

tags: render smoke, dashboard, admin page, browser mcp down, playwright, chrome-devtools, sem login, verificar tela, FastAPI, Jinja, TemplateResponse, super_admin, monkeypatch estado

**Contexto:** precisa provar que uma página admin (FastAPI + HTMX + Jinja) renderiza sem erro e contém os elementos esperados, mas (a) o MCP de browser (chrome-devtools/playwright) desconectou na sessão, ou (b) a página exige login/OTP que não dá pra completar headless.

**Causa raiz:** o handler da rota é uma função async normal; o `Depends(requireAuth)` só injeta a `session`. Chamando o handler DIRETO você pula o auth e não precisa de cookie/OTP nem de browser.

**Solução (render smoke in-container, sem browser):**
1. Script Python rodado NO container de prod (`docker cp` + `docker exec python` + `rm`), processo SEPARADO do uvicorn (não afeta o server vivo).
2. Monta um `starlette.requests.Request` mínimo: `Request({"type":"http","method":"GET","path":"/admin/x","raw_path":b"/admin/x","query_string":b"","root_path":"","headers":[(b"host",b"dominio")],"scheme":"https","server":("dominio",443),"client":("127.0.0.1",0),"state":{}})`.
3. Chama `await rotas.handler(request=req, session={"role":"super_admin","tenantId":"<t>"})` — o handler roda `buildPageContext`+render de verdade; `resp.body.decode()` tem o HTML. Assert por marcadores (`'Faturamento' in body`, `'data-tab="x"' in body`, status 200).
4. **Forçar um ESTADO condicional do template** (ex.: caixa fechado, feature-flag off) sem mutar dado real: monkeypatch do data-provider no próprio processo do smoke — ex. `rotas.svc.getRegisterView = lambda tid: {"open": False, ...}`. Só afeta o script, não o server. Renderiza os dois estados e checa cada um.

**Gotchas:** (a) precisa de `session` com `role`/`tenantId` que o `resolveTenantId` da app aceite (super_admin resolve por `?tenant_id`>cookie>session.tenantId); (b) rota com query params (`request.query_params.getlist(...)`) exige `query_string` no scope (use `b""`); (c) para tela que só aparece com um pré-requisito (caixa aberto), OU semeia o pré-requisito OU monkeypatcha o provider como no passo 4; (d) NÃO é substituto de eyeball de pixel — valida render/estrutura/dados, não CSS visual (deixar o eyeball pro operador).

**Ref:** tiatendo F4 "Fechamento do dia" — render smoke de `/admin/caixa`, `/admin/orders`, `/admin/fechamento` (2026-07-15); [[project-f4-fechamento-do-dia-2026-07-15]].

---

## Migração de UI+API pra novo domínio: cookie dinâmico por Host não basta, a base da API também {#migracao-dominio-cookie-e-api-dinamicos}

`tags: dominio migracao cookie host api base-url dinamico frontend cors`

tags: migração domínio, cutover, cookie domain, cross-site, SameSite lax, registrable domain, const API, coexistência, dual-host, huboperacional, ads4pros, 302 vs 301

**Contexto:** migrar uma UI static (`gestao.ads4pros.com`) + sua API (`api.ads4pros.com`) pra outro domínio registrável (`*.huboperacional.com.br`), mantendo o domínio antigo vivo durante a transição (coexistência + rollback barato). O cookie foi feito dinâmico por Host, mas no host NOVO o login "entrava" e os dados davam 401.

**Causa raiz:** cookie dinâmico por Host resolve só METADE. O front tinha `const API` **hardcoded** pro domínio antigo. Como o MESMO bundle serve os dois hosts, o host novo chamava a API antiga **cross-site** (registrable domain diferente) → com `SameSite=lax` o cookie não vai em fetch/XHR cross-site → 401. E hardcodar (`sed`) pro domínio novo quebraria o host ANTIGO pelo mesmo motivo, invertido.

**Solução:** a base da API no front também tem que ser **dinâmica por Host** (espelho do cookie): `const API = location.hostname.endsWith('novo.com') ? 'https://api.novo.com' : 'https://api.antigo.com'`. Cada host chama a API do seu próprio domínio registrável → cookie same-site → os dois convivem. **Regra geral: num cutover de domínio, cookie-domain E api-base precisam ser dinâmicos por Host, juntos.** Além disso: expor a MESMA API também no domínio novo (Host extra no Traefik, não segundo deploy); cutover final com **302, não 301** (301 é cacheado permanente pelo browser → "remover o redirect" não pega quem já cacheou; 302 mantém rollback real).

**Ref:** migração Painel Gestão 2026-07-14; `docs/superpowers/specs/2026-07-14-migracao-gestao-huboperacional-design.md` §5 (furo-1, achado na review do Painel que o conselho tinha perdido).

---

## Mudar rota/Host do Traefik (label) não pega com `service update --image` {#traefik-label-precisa-stack-deploy}

`tags: traefik label host rota service-update stack-deploy swarm routing`

tags: traefik, swarm, label, router rule, Host, docker service update, stack deploy, label-add, rota não aplica, env drop, rollout transiente

**Contexto:** adicionei um `Host()` novo na regra do router Traefik (label no compose) e rodei o deploy padrão (`docker service update --force --image`), mas a rota nova não apareceu.

**Causa raiz:** labels do Traefik vivem no **service spec**, setados no `docker stack deploy`. `docker service update --image` troca só a imagem — **não reaplica labels**. A regra fica a antiga.

**Solução:** pra mudar label/rota: **(a)** `docker service update --label-add "traefik.http.routers.X.rule=..." SERVICE` — cirúrgico, **não mexe em env/secrets** (ideal quando o compose tem token/senha); OU **(b)** editar o compose + `docker stack deploy --resolve-image never -c compose.yml STACK` — ⚠️ o stack deploy **reaplica todo o env do compose**, dropando variáveis que só foram `--env-add` (não escritas no compose). Backtick na regra via SSH: passar por variável single-quoted no remote (`RULE='Host(\`x\`)...'`; expansão de `$VAR` em aspas duplas não reinterpreta backtick). Após `service update`, **esperar convergir** antes de curlar (curl no meio do rollout pega a task velha → 404/conteúdo stale).

**Ref:** migração Painel Gestão Fases 1/4 2026-07-14.

---

## [5-T] de mudança no loader/script client-side na página real do cliente sem poluir prod {#loader-5t-sem-poluir-prod}

`tags: loader script client-side 5t teste prod staging validacao query-param`

tags: loader, tracking, pixel, fbq, gtag, ttq, CAPI, pmaTrack, [5-T] client-side, Playwright, GTM não carrega headless, injetar script, CNAME first-party, stub fetch, disparo real polui conversão, dispatchEvent submit, capture-phase

**Contexto:** preciso verificar ([5-T]) uma mudança num loader de tracking (script client-side servido pelo tracking service) rodando na página real do cliente. Dois obstáculos: (a) o loader é injetado via **GTM**, que **não dispara em Playwright headless** (consent/Cloudflare/anti-bot) → `window.__pma_loaded`/`pmaTrack` ausentes; (b) disparar um evento real (Lead) dispara a conversão de verdade — **pior ainda pós-go-live** (após remover o `meta_test_event_code`, cai no stream de PRODUÇÃO e polui os dados do cliente).

**Causa raiz:** GTM gated não carrega o loader; e o caminho de conversão (client-side `fbq`/`gtag`/`ttq` + server-side `/tracker`→CAPI) manda pra prod quando exercido de verdade.

**Solução:**
1. **Injeta o loader deployado direto do CNAME first-party** do cliente (`https://track.<cliente>/scripts/loader.js?t=<tenant_id>`) via `<script>` — o CNAME é first-party (CSP aceita; `tracking.ads4pros.com` como third-party pode ser bloqueado). Espera `__pma_loaded===true` + `typeof pmaTrack==='function'`.
2. **Stuba TODAS as vias de envio** antes de exercer: `window.fetch` (captura o body do `/tracker` e retorna `Response('{}',{status:200})` — nada sai), `window.fbq`, `window.gtag`, `window.ttq.track`. Assim você **captura o payload que o loader MANDARIA** (ex.: `custom_data.value`) sem enviar. **Pré-stuba `window.fbq` ANTES de injetar** → o loader pula o próprio init (`if(f.fbq)return`) e não dispara PageView. O loader sobrescreve `gtag`/`ttq` no init → re-stuba DEPOIS da injeção.
3. **Dispara o evento** com `form.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}))` num form sintético **anexado ao body** (pro handler em capture-phase no `document` pegar via bubbling; `dispatchEvent` sintético **não navega/submete** — `isTrusted=false`). Entre casos (ex.: venda vs locação), limpa a chave de dedup no `sessionStorage` (`pma_lead_<method>`).
4. Pra provar o caminho servidor completo (event_log + CAPI) **quando ainda é seguro** (test stream ativo), NÃO stuba — deixa o `/tracker` passar e faz probe no `event_log` (payload_value, `sent_to_meta`/`meta_response_ok`, e `meta_payload_sent ? 'test_event_code'` pra confirmar que foi no stream de teste). Ordena o teste completo ANTES do go-live (remover test_event_code) pra não poluir prod.

**Ref:** [[project_uni_tracking_conversoes]]; Paid Media cont.103 (loader property_value + gate venda/locação).

---

## Bot conversacional re-pergunta info que o cliente já deu FORA DE ORDEM (checkout/wizard) {#parking-info-fora-de-ordem}

`tags: conversa, checkout, wizard, maquina de estados, info fora de ordem, re-pergunta, parking, customer_context, lock por-conversa, WhatsApp, restaurante, tiatendo, forma de pagamento, retirada entrega, endereco adiantado`

**Sintoma:** o cliente manda a resposta de um passo ANTES do bot perguntar ("vai ser no cartão", "rua X 560") e o bot (a) ignora → re-pergunta depois; (b) trata a msg como resposta do passo CORRENTE (ex.: "vai ser no cartão" vira o NOME do cliente); (c) cai num fallback espúrio ("Pode me dizer: retirada ou entrega?").

**Causa raiz (diagnóstico):** o fluxo é uma **máquina de estados determinística** (não LLM) e há **lock por-conversa** → NÃO é race concorrente, é **ordem**: cada mensagem é processada contra o estado que existe quando ela é desenfileirada. Info dada cedo bate no gate errado.

**Solução — parking-and-reuse (cirúrgico, preferível a debounce):**
1. **Estaciona** a info reconhecida no contexto que PERSISTE entre os passos (não no `pending`, que é substituído a cada gate) — no tiatendo, `session.customer_context`. Escaneia TODA msg do fluxo (menos o gate que já trata aquele input) com o detector correspondente (`_matchPaymentMethod`/`detectDeliveryPref`/detector de endereço) e grava `parked_<x>`.
2. **Consome no gate certo:** o gate lê+LIMPA o park (`_consumeParkedPayment`) — se presente, pula a pergunta e usa o valor (com ack "como você tinha dito…"). Limpar é obrigatório senão vaza pro próximo pedido da mesma conversa.
3. **Gate corrente não mis-consome:** o passo atual precisa REJEITAR a msg que é claramente info de outro gate (ex.: `awaiting_name`: se `_matchPaymentMethod(text)` casa, NÃO vira nome → reconhece o park e re-pergunta o nome). Muitos gates aceitam "qualquer coisa" (o de nome aceitava 4 palavras) — esse é o bug real por trás de (b).
4. Muitos fluxos JÁ têm um "skip se já sei" (no tiatendo o P0-C de `_awaitConfirm` consulta `delivery_pref`/`customer_address`) — o parking só precisa POPULAR esse contexto quando a info vem fora de ordem, e o skip existente reaproveita de graça.

**Gotchas:** (a) blast-radius alto (fluxo `[5-T]`) → TDD por peça, uma info de cada vez; (b) o consume adiciona 1 read de sessão no gate → atualizar os testes existentes do gate pra mockar `getOrCreateSession` (senão `TypeError`/DB real); (c) `_matchPaymentMethod` etc. devem casar só TOKENS ("dinheiro"/"cartão"), nunca frases genéricas, pra não estacionar lixo.

**Ref:** tiatendo prints 2026-07-15 B3 (`restaurantOrderFlow._parkPaymentIfMentioned`/`_consumeParkedPayment`); devolutiva `docs/devolutivas/2026-07-15-smoke-conversa-loja-prints.md`. Continuação B4/B6 = mesmo padrão pra endereço/entrega.

---

## Migração de schema vai subir e o entrypoint roda `alembic upgrade || continuing` (fail-open) {#migracao-entrypoint-fail-open}

`tags: migration alembic entrypoint fail-open upgrade schema deploy silencioso`

**Sintoma / risco:** o entrypoint do container roda a migração no start, mas **fail-open**:

```sh
alembic upgrade head || echo "[entrypoint] WARNING: alembic upgrade failed (continuing)"
exec "$@"
```

A ordem dentro do container está certa (migração antes do app). O problema é o `||`: se a migração
falhar (permissão, lock, DDL inválido), o container **sobe assim mesmo** — e o ORM da imagem nova
mapeia colunas que não existem → `select(Model)` estoura → **derruba TODO o tráfego**, não só a
feature nova. Um WARNING no log é a única pista.

**Não resolve:** "rodar a migração manualmente antes do deploy" — o arquivo da migração só existe
**na imagem nova**; o container velho não a tem. E `docker service update` não te dá um hook entre
"pull" e "start".

**Resolve — prove o DDL ANTES, contra o banco real, sem persistir:** rode o DDL de verdade dentro de
uma transação e faça `ROLLBACK`. Se faltar permissão/o SQL for inválido, você descobre agora e não
no fail-open.

```python
tx = conn.transaction(); await tx.start()
try:
    await conn.execute("ALTER TABLE t ADD COLUMN IF NOT EXISTS c BOOLEAN NOT NULL DEFAULT false")
    await conn.execute("UPDATE t SET c = (...)")          # o backfill real
    print(await conn.fetchval("SELECT count(*) FROM t WHERE c"))   # confere o resultado
finally:
    await tx.rollback()                                    # nada persistido
```

Cheque junto: `SELECT current_user`, `SELECT tableowner FROM pg_tables WHERE tablename='...'`
(o erro clássico é "must be owner of table"), `SELECT version_num FROM alembic_version`, e se o env
que gateia a migração (ex.: `DATABASE_URL_SYNC`) está setado — **se não estiver, a migração nem roda**
e o app sobe com ORM quebrado do mesmo jeito.

**Depois do deploy, verifique o efeito, não o "convergiu":** `docker service logs | grep 'Running upgrade'`
+ probe do `alembic_version` + probe do backfill (a invariante que ele deveria preservar).

**Corolário:** o fail-open é **pré-existente e sobrevive** ao seu deploy. Provar o DDL protege ESTA
migração, não a próxima. Registre como follow-up (trocar por `set -e`/healthcheck) em vez de dar por
resolvido.

**Ref:** Paid Media `services/tracking/entrypoint.sh:22`, migração 0020 (cont.104 2026-07-15).
Achado pelo Cross-Claude no milestone-review — o DeepSeek não pegou.

---

## Reviewer cross-provider (R11/conselho) acusa "migration ausente"/"campo morto" que JÁ existe — ele só vê o diff staged {#reviewer-so-ve-diff-staged}

`tags: review reviewer diff staged falso-positivo migration campo-morto r11 conselho`

**Sintoma:** num fluxo de commits pequenos (subagent-driven, TDD task-a-task), o reviewer do R11
solta `[SEV: risco]` do tipo:
- *"coluna adicionada no modelo sem migration correspondente no diff"* → a migration existe, foi
  commitada na task anterior;
- *"campo adicionado ao schema mas nada no backend consome — pode ser campo morto"* → o consumo foi
  commitado 2 tasks atrás;
- *"comentário cita `send_to_meta` mas essa função não está no diff"* → é forward-reference
  intencional, sequenciada no plano.

**Causa raiz:** o reviewer recebe **só o `git diff` staged**, não o repo nem o histórico. Toda mudança
sequenciada em commits atômicos "parece" incompleta pra ele. O bônus ruim: ele às vezes **inventa a
regra violada** (citou "R6 banco novo por projeto" e "R3 zero mock escondido" pra um TypeError
hipotético) e **aponta o caminho errado** (mandou criar a migration em `worker/migrations/` quando o
serviço usa `services/tracking/alembic/versions/`).

**Resolve:** triar CADA finding contra o repo antes de agir OU descartar — as duas coisas são erro:
1. `git log --oneline <base>..HEAD` / `git show <sha> --stat` → aquilo já foi commitado?
2. `grep` o consumidor do campo no repo (não no diff).
3. Se a regra citada não bate com o problema descrito, é sinal forte de alucinação — mas **verifique
   o problema mesmo assim** (a regra pode estar errada e o bug certo).
4. **Registre a triagem no commit message.** Senão o próximo (ou você em 2 semanas) "re-descobre" o
   mesmo falso-positivo e infla o código guardando contra fantasma.

**Não faça:** adicionar `getattr(x, 'campo', default)`/`?? ""` defensivo só pra calar o reviewer —
isso mascara atributo ausente de verdade e troca uma falha alta e óbvia por um bug silencioso.

**Contraponto (não vire cínico):** no MESMO marco, o Cross-Claude — que teve acesso ao repo e rodou
os testes — achou 2 bugs reais que a spec e eu tínhamos perdido. A diferença não é o modelo, é o
**contexto que ele recebe**. Reviewer com repo > reviewer com diff. Quando o finding importa, dê
acesso ao repo e peça prova empírica ("rode o teste", "quebre o guard e veja se pega").

**Ref:** Paid Media cont.104 (2026-07-15), tasks 2 e 5 do toggle Modo teste.
Ver também [Devolutiva cross-time escrita da MEMÓRIA acusa o bug errado](#devolutiva-reverificar-no-codigo).

---

## Guard anti-dupla-cobrança com idempotency do Stripe não dispara (a key REPLICA a resposta cacheada) {#stripe-idempotency-replay}

`tags: stripe, idempotency, idempotencyKey, checkout session, dupla cobranca, double charge, webhook lag, replay, retrieve, url null, expired, complete, 409`

**Sintoma:** você guarda contra dupla cobrança fazendo `sessions.create(params, { idempotencyKey })` e depois `if (!session.url) return 409 /* já pagou */`. O ramo do 409 **nunca dispara** — e o teste dele passa, porque mocka `url: null` (mocka a conclusão).

**Causa raiz:** **idempotency do Stripe é cache de resposta, não re-avaliação.** A doc é explícita: ele **salva o status+body da 1ª requisição** e devolve **o mesmo resultado** nas seguintes. Como a Checkout Session **nasce ativa**, o body cacheado tem `url` preenchida — então o replay devolve essa **`url` velha e não-nula mesmo depois do cliente pagar**. O `url: null` vale pro **`retrieve` ao vivo** (o SDK documenta: *"This value is only present when the session is active"*), **não pro replay do `create`**.

**O que a key resolve de fato:** o replay devolve **a mesma sessão**, e **Checkout Session é de uso único** — o Stripe não deixa pagar duas vezes a mesma sessão. **É isso** que barra a 2ª cobrança, não o `url`.

**Solução:** usar o `create` idempotente só pra obter a mesma sessão, e perguntar o status **ao vivo**:

    const session = await stripe.checkout.sessions.create(params, { idempotencyKey });
    const live = await stripe.checkout.sessions.retrieve(session.id);
    if (live.status === 'complete') return 409;                    // pagou de verdade
    if (live.url) return { url: live.url };                        // aberta
    const fresh = await stripe.checkout.sessions.create(params);   // expirada = NINGUÉM pagou
    return { url: fresh.url };

**Gotchas:**
- ⚠️ **`expired` NÃO é `complete`.** 409 numa sessão expirada **bloqueia um comprador disposto** — erro tão caro quanto cobrar 2×. Trate os dois status separadamente.
- **Params entram na key:** replay com a mesma key e **params diferentes** faz o Stripe **rejeitar a requisição**. Se o preço muda, a key tem que mudar → embutir os price ids na key.
- **Key derivada de input opcional colide:** montar a key com `niche ?? ''` / `slug ?? ''` faz um body vazio virar `offer:::…` — **key compartilhada entre requisições distintas** → o Stripe entrega a sessão de um comprador a outro. **Validar a entrada (400) antes de compor a key.**
- **Duas chamadas concorrentes** com a mesma key → erro de *concurrent idempotent request* (não duplicata). Sem `try/catch` vira 500.
- **O 409 do guard precisa de UI própria.** Se o cliente cair no `catch` genérico, quem **acabou de pagar** lê "Something went wrong, please try again" — o convite exato pra 2ª cobrança. E não trate **qualquer** 409 como "já pagou": um 409 de WAF/rate-limit diria "tudo certo" a quem não pagou. Gate no **seu próprio marcador** (`error === 'already_paid'`).

**Ref:** ads4agencies-site `app/api/checkout/route.ts`, commit `ad1c0ef` (2026-07-15); memória `reference_stripe_idempotency_replica_resposta_cacheada`. Achado pelo review Cross-Claude **depois** de a 1ª versão do fix ir pro tree apoiada na premissa errada.

---

## Raspando email de contato: JSON-LD é onde mora, e o MX "válido" aceita registro A {#scrape-email-jsonld-mx}

`tags: scrape, scraping, email, contato, bs4, BeautifulSoup, get_text, script, json-ld, ld+json, schema.org, LocalBusiness, mx, email-validator, check_deliverability, dnspython, bounce, prospeccao`

**Sintoma:** (a) o scrape acha bem menos email do que o site realmente publica; (b) emails "validados" quicam mesmo assim.

**Causa-raiz (a):** `BeautifulSoup.get_text()` **exclui `<script>`** — comportamento correto dele, e por isso passa batido em review ("script não vaza pro get_text, tá certo"). Só que negócio local publica o email em **`<script type="application/ld+json">`** (`schema.org/LocalBusiness`), que é **onde o negócio declara os próprios dados** — a fonte mais confiável que existe. Um scan de `mailto:` + texto é **100% cego** a ela.

**Causa-raiz (b):** `email_validator.validate_email(addr, check_deliverability=True)` **não exige MX** — cai pro **registro A/AAAA** (RFC 5321 "implicit MX"). Em scrape isso vira **no-op**: o email vencedor é quase sempre `@` o domínio do próprio site, e você só chegou ali **porque acabou de baixar HTML daquele host** → o A **provadamente existe** → passa sempre. Site de template que imprime `info@ownsite.com` sem nunca configurar email tem A e não tem MX.

**Solução:**
1. Ler as 3 fontes em ordem de confiança: **`mailto:` → `ld+json` → texto**. No JSON-LD, **recursar** (schema.org aninha em `@graph`) e **podar subárvores de terceiros** por `@type` (`Person`, `Review`, `Rating`) e por chave (`author`, `review`, `publisher`) — senão você grava o email **do avaliador** como contato do lead, e pior: por ser fonte de alta confiança, ele aborta o crawl antes do mailbox real.
2. Exigir **MX real**: `dns.resolver.resolve(domain, "MX")` (dnspython já vem com email-validator; DNS é bloqueante → thread + cache por domínio).
3. **Ranquear e percorrer até um passar no MX** — checar só o melhor e desistir joga fora email bom (loja publica um role sem MX **e** o gmail que funciona).
4. **Nunca chutar** (`info@<domínio>` inventado) = bounce garantido.

**Gotchas:** filtro de lixo por **substring** derruba lead real (`info@sentrytinting.com` casa "sentry"; `businessname@` casa "name@") → casar **domínio com fronteira de ponto** e **local-part exato**. Bloquear um lixo faz o ranking **cair no próximo, que também pode ser lixo**. O rodapé credita a agência que fez o site e o `info@` dela **vence o mailbox da loja** no ranking role-first → sinal pra auditar: **domínio próprio (não-free) que não bate com o host do site**. Enumeração de blocklist **não fecha** — o backstop é **review humano** do relatório.

**Ref:** Scraper-prospeccao `services/api/app/integrations/email_harvest.py`, commit `7ea8e4f` (2026-07-15): JSON-LD sozinho rendeu **+22 emails (100→122)** em 310 leads. Memórias `reference_jsonld_is_where_business_email_lives`, `reference_email_validator_mx_aceita_registro_A`.

---

## Verifiquei a pré-condição, pedi aprovação (R20/R5), e executei quando o operador respondeu — mas a verificação VENCEU na espera {#verificacao-vence-esperando-r20}

`tags: R20, R5, aprovacao, gate, quiet hours, TCPA, janela, stale, verificacao vencida, time-of-check, TOCTOU, disparo, compliance`

**Sintoma:** você fez tudo certo — checou a pré-condição, mostrou o número ao operador, esperou o R20, e executou **exatamente o que foi aprovado**. E mesmo assim a execução violou a pré-condição.

**Caso concreto (Scraper-prospeccao, 2026-07-17 — violação real):** verifiquei a janela TCPA às **18:05 ET** ("restam 175 min até as 21:00"), pedi o R20 pro disparo de 51 SMS. **O operador respondeu ~14h depois, às 07:45 da manhã.** Disparei na hora, com a verificação da véspera. **9 SMS saíram entre 07:45 e 07:59 locais — antes das 8h = violação de quiet hours.** A checagem não estava errada quando foi feita; ela **venceu esperando a aprovação**.

**Causa-raiz — TOCTOU com um humano no meio.** Toda pré-condição **temporal** (janela horária, cotação, saldo, token, lock, rate-limit, "o serviço está no ar") tem validade. Um gate de aprovação humana introduz uma espera **de duração desconhecida** entre a verificação e o uso — o operador pode responder em 2 minutos ou dormir e responder de manhã. **A aprovação diz "pode fazer X", não "as condições de X ainda valem".**

**Regra:** o que você verifica **antes** de pedir aprovação serve pra *decidir se vale pedir*. **NUNCA** serve como garantia na hora de executar. Toda pré-condição perecível tem que ser **re-checada no momento do uso** — e, se possível, **dentro do código**, por item.

**Solução:**
1. **Guard no código, por-item, no instante da ação** — não uma checagem de startup, não uma nota no runbook, não disciplina do agente. `if not is_within_quiet_hours(datetime.now(UTC), lead.state): skip`.
2. **Falha = pular, não abortar o lote.** E **não marque no ledger** — o item volta no próximo run, dentro da janela dele.
3. **No fuso/contexto do ALVO, não no seu.** 09:00 ET é 06:00 PT: checar no *seu* fuso libera envio ilegal. Desconhecido → o mais restritivo (ex.: `Pacific/Honolulu`, onde qualquer instante é o mais cedo localmente — só erra pro lado conservador). Isto é o mesmo princípio de [Guard checa o ALVO, não a intenção](#guard-checa-intencao-nao-alvo).
4. **Se a pré-condição venceu quando o R20 chegou, NÃO execute** — volte ao operador. "Ele já aprovou" não é autorização pra executar em condição diferente da que ele aprovou.

**Sinal de alerta:** se entre a sua verificação e a sua ação existe uma mensagem ao operador, **assuma que passaram horas**. Antes de executar um `--apply` aprovado, releia o relógio/estado. Se a resposta demorou e você não re-checou, você está executando às cegas com a confiança de quem checou.

**Ref:** Scraper-prospeccao — 9 SMS fora da janela; fix = `is_within_quiet_hours`/`timezone_for_state` em `services/api/app/integrations/cohort_dispatch.py`, chamados por-envio em `run_cohort_dispatch.py` (17 testes; provado contra o timestamp REAL da violação). Memória `reference_tcpa_quiet_hours_violation_stale_check`.

---

## Guard de segurança checa a INTENÇÃO e não o ALVO (ex.: `APP_ENV=test` não protege banco nenhum) {#guard-checa-intencao-nao-alvo}

`tags: guard, seguranca, teste, pytest, conftest, autouse, truncate, APP_ENV, DATABASE_URL, banco live, producao, falsa seguranca, fixture`

**Sintoma:** existe um guard explícito protegendo uma operação destrutiva, o código parece defensivo, e **mesmo assim a operação roda em produção**.

**Causa-raiz — o padrão geral:** o guard verifica **a intenção declarada** em vez do **alvo real**. Caso concreto: `conftest.py` com fixture `autouse` que dá `TRUNCATE` em tabelas antes de cada teste, protegida por `if s.APP_ENV != "test": pytest.fail(...)`. Só que o `pyproject.toml` **sempre** seta `APP_ENV=test` (`[tool.pytest.ini_options] env = [...]`). O guard **nunca dispara** — ele confirma que "estou rodando testes", que é sempre verdade sob pytest. **Ele nunca olha `DATABASE_URL`.** Se a URL aponta pro banco de produção, rodar a suíte **trunca produção**, com o guard aceso e verde.

**Regra:** um guard destrutivo tem que checar **o alvo**, não o contexto. `APP_ENV=test` responde *"é um teste?"*; a pergunta certa é *"esse host/banco pode ser destruído?"*.

**Solução:** assertar sobre o **alvo** — extrair host/database da `DATABASE_URL` e falhar se não for localhost nem terminar em `_test`. Alternativas: apontar o teste pra um DB dedicado; tornar a fixture não-autouse (só quem pede DB paga).

**✅ IMPLEMENTAÇÃO DE REFERÊNCIA (2026-07-16, Scraper-prospeccao — a receita acima funcionou):**
1. **Banco dedicado** `scraper_prospeccao_test` no mesmo Postgres (owner = role da app já existente, **sem role nova**) + `alembic upgrade head`. Reversível com `DROP DATABASE`. (Se preferir **efêmero** em container no VPS, ver [Postgres efêmero pra testes destrutivos](#pg-efemero-testes-destrutivos) — mesma família, receita distinta; escolha persistente quando não há Docker local e a suíte roda direto da máquina.)
2. **Repoint no import do `conftest.py`, ANTES dos imports de `app.*`** — crítico e fácil de errar: `get_settings()` costuma ser `lru_cache` e o módulo de database cria o engine **no import**, então **a primeira leitura vence pra sempre**. Como env var vence `env_file` no pydantic-settings, um `os.environ["DATABASE_URL"] = <test>` no topo repointa **o processo inteiro** (engine do app incluso). Imports de `app` depois disso, com `# noqa: E402`.
3. **O guard lê o engine, não a config:** `assert_test_database(test_engine.url.render_as_string(hide_password=True))` dentro da própria fixture destrutiva — re-derivado **do engine que está prestes a ser truncado**. Assim, mesmo que o repoint falhe, falha **alto** em vez de truncar calado.
4. **`hide_password=True` importa:** o guard só lê o *path* (nome do banco), e ele levanta exceção **exatamente quando a URL é a de produção** — com `hide_password=False` a senha do banco LIVE fica no frame que estoura, e `pytest --showlocals` (ou wrapper de CI) a joga no log.
5. **Suffix `_test`, não `contains "test"`** — `contains` deixa passar `test_scraper_prospeccao`, que pode ser um banco real. Teste esse caso.
6. **Prova que vale (não presuma):** **controle positivo** — plante uma linha-sentinela **no banco LIVE** numa tabela da lista de TRUNCATE, rode a suíte, confira que sobreviveu; e confira que o **banco de teste** foi truncado/re-seeded (prova que a fixture rodou, no alvo certo). Contagem de linhas sozinha é baseline inútil se o alvo já estiver vazio. **Controle negativo:** force `TEST_DATABASE_URL` no banco LIVE → tem que recusar carregar o conftest. `pg_stat_activity` confirma o alvo ao vivo.

⚠️ **O banco dedicado NÃO acelera a suíte** — se ele é remoto, o round-trip por teste continua (13 testes = ~4min). Ele só a torna **incapaz de destruir prod**. Suíte rápida é problema separado (PG local via `TEST_DATABASE_URL`).

**Sintoma-satélite que denuncia:** se testes **puros** (sem I/O) estão lentos/instáveis, alguém está fazendo I/O por baixo via `autouse`. Escape local, blast-radius zero — **sombrear a fixture pelo nome no módulo**:

    @pytest.fixture(autouse=True)
    def _truncate_tables():
        """Override conftest's DB-truncating autouse fixture — this test is pure."""
        yield

(no Scraper-prospeccao isso levou 83 testes de **240s com erros aleatórios** pra **0.7s**).

**Ref:** Scraper-prospeccao — achado 2026-07-15, **RESOLVIDO 2026-07-16**. Implementação: `services/api/tests/db_target.py` (`resolve_test_database_url`/`assert_test_database`/`derive_test_database_url`, 16 testes em 0.06s) + `services/api/tests/conftest.py`. Review R11 Cross-Claude: 0 bugs confirmados; os 2 achados aplicados viraram os pontos 4 e "precedência testável" acima. Memória `reference_pytest_trunca_banco_live_scraper`.

---

## Validar UMA conta numa API multi-tenant e generalizar o resultado {#validar-uma-conta-generalizar}

`tags: multi-tenant validacao conta amostra generalizar api teste`

**Sintoma:** um probe de validação (ex.: `validateOnly`) passa contra a conta do piloto, você conclui
"o campo X não é obrigatório → sem mudança de código", ship, e no primeiro cliente seguinte o mesmo
payload é **rejeitado**.

**Caso real (Paid Media, 2026-07-16, migração Google Ads → Data Manager API):** a "Fase 0" rodou
`validateOnly` com gclid real na conta do piloto (Uni) **sem** `transactionId` → **200**. Conclusão
registrada: *"transactionId não é exigido quando há gclid → zero mudança no router"*. Ao migrar TODOS
os tenants, o Moper devolveu `events[0].transaction_id | REQUIRED_FIELD_MISSING` — **o requisito
depende da conversion action**, não da API. Titanium e Uni passavam; Moper não. O conselho R11
(DeepSeek + Cross-Claude) tinha marcado exatamente esse campo como **risco de consenso** e o probe de
uma conta deu um **falso all-clear** que calou o alerta deles.

**Why:** APIs multi-tenant validam contra a configuração do *destino* (tipo da conversion action,
categoria, política da conta), não só contra o schema do payload. Um 200 prova "válido **para aquele
destino**", nunca "válido para a API". O viés é forte porque o probe parece autoridade — veio do
próprio Google.

**How to apply:**
1. **Probe de contrato roda em N destinos heterogêneos, não em 1.** Escolha destinos que difiram no
   eixo que importa (aqui: tipo/categoria da conversion action — lead-gen vs ecommerce vs chamada).
   Um único destino só prova o caminho feliz dele.
2. **Se um review/conselho marcou o campo como risco e o seu probe "desmentiu", desconfie do probe,
   não do conselho.** Um all-clear que cancela um risco de consenso merece uma segunda amostra antes
   de virar decisão de arquitetura.
3. **Prefira o fix barato ao "não precisa".** Threadar um id estável custava ~5 linhas; a conclusão
   "não precisa" custou um ciclo de descoberta em produção. Quando o campo é opcional-ou-obrigatório
   *dependendo do destino*, **mande sempre** (se for inofensivo onde é opcional).
4. **O id tem que ser ESTÁVEL, nunca `uuid4()` na hora do envio** — `transactionId`/`orderId` são
   chave de deduplicação: um id novo a cada retry conta a conversão duas vezes. Reuse o id que já
   deduplica em outro canal (aqui: o `event_id` que o Meta/TikTok CAPI já usava) ou derive
   deterministicamente (`wa-lead-{conv_id}`).
5. **Migre em lote cedo, não só o piloto.** Foi o "migra todos" que expôs o erro no mesmo dia; migrar
   só o piloto teria escondido até o próximo cliente entrar — com o sintoma longe da causa.

**Corolário (mesma sessão):** o erro real ficou escondido atrás de um genérico *"There was a problem
with the request."* porque o extrator de erro só conhecia o shape da API antiga
(`error.details[].errors[]`) e a nova usa `google.rpc.BadRequest.fieldViolations`. **Ao trocar de API,
o parser de erro é parte da migração** — senão o primeiro erro real chega ilegível justo quando você
mais precisa dele. Guarde `isinstance` em todo `.get()` do extrator: ele roda no caminho de erro, e uma
exceção ali escapa (o `try/except` costuma cobrir só o `json.loads`) e derruba o request.

**Ref:** Paid Media Automation — cont.105.2 (2026-07-16). Fix `0f545f7` (threading do `event_id` →
`transaction_id`, parser dos 2 shapes) + `d0b567b` (guarda contra corpo malformado). Memória
`project_google_data_manager_migration`.

---

## Feature que depende de LLM ou dado real não fecha [5-T] sem smoke em prod com a FRASE/DADO EXATO do caso original {#smoke-prod-feature-llm}

`tags: smoke prod llm 5t frase-exata dado-real validacao feature`

**Sintoma:** feature "pronta" com testes verdes + review/conselho aprovando, mas que quebra no
caso real. Aconteceu no D16/tiatendo (2026-07-16): **1128 testes verdes + 3 passadas de conselho
cross-Claude + GO explícito**, e o smoke da frase exata do print em prod achou **2 defeitos que
matavam a feature inteira**.

**Por quê teste e review não pegam:** ambos provam o que você IMAGINOU que acontece. Os defeitos
vivem no que só o ambiente real sabe:
1. **Por qual guard/branch o texto real passa.** No D16 eu instrumentei o guard errado — a frase
   caía num TERCEIRO guard de defer (`unknown_item`), não no que eu cobri. Meus testes, montados em
   cima da minha hipótese, passavam. O conselho leu o mesmo código com a mesma premissa.
2. **Em que formato o LLM/serviço real devolve os dados.** O LLM mandava `ref='Feijoada [G]'` (com
   a variante); meu consumo comparava com o nome canônico `'Feijoada'` → **nunca casava**. Toda a
   lógica estava "certa" contra o formato que EU supus.

**Solução:**
- Feature LLM/integração **não fecha `[5-T]` sem smoke em prod com a FRASE/DADO EXATO do caso
  original** — não vale phrasing "equivalente" (foi phrasing limpo que passou o tempo todo enquanto
  o do print quebrava).
- Conferir o resultado **no destino final** (ex.: `order_items.line_notes` no banco), não na resposta
  intermediária.
- Quando achar o defeito, **procure a CLASSE**: achei 1 guard não coberto → varri e achei 4 →
  virou ponto único (`_deferToFlow`) + **teste estrutural** que reprova se aparecer um defer cru
  novo. Fix pontual deixaria o próximo guard reabrir o buraco.
- Casamento de identificador vindo de LLM: **conjunto fechado** de formas aceitas
  (`name`, `name var`, `name [var]`, `name (var)`), nunca substring (`in`) — "coca" bateria em
  "Coca-Cola Zero" e colaria no item errado.

**Reincidência 2026-07-31 (tiatendo, 3 deploys num dia) — e o que ela acrescenta:** **6088 testes
verdes**, **conselho de 3 membros**, **2 rodadas de review R11** (que bloquearam e acharam defeito
real), e ainda assim **2 defeitos só apareceram quando uma frase de gente de verdade entrou por um
WhatsApp de verdade** — cada um **minutos depois** do deploy anterior:
- `0.267.0` → o smoke achou o bot **reperguntando o bairro que estava na frase**, no caminho de
  **troca** de endereço, que **tinha nascido naquele mesmo lote**. Código novo violando a invariante
  do próprio lote é ponto cego estrutural: a suíte foi escrita olhando o caminho novo, não o velho.
- `0.268.0` → o smoke achou o **primeiro** defeito vindo do interpretador LLM: ele entendeu o pedido
  **certo** e mesmo assim duplicou o rótulo de tamanho num campo de texto livre, que virou pergunta
  órfã e **engoliu o "pode fechar"** do cliente.

Corolário de cadência: **smoke não é a última linha do checklist, é etapa de descoberta.** Se cada
deploy do dia rendeu um defeito no smoke seguinte, o ciclo é `deploy → smoke com frase de gente →
fix → deploy`, e "acabou" é o smoke que **não** achou nada — não a suíte verde. E confira o payload
**no destino final** (aqui: a linha na tabela `pendency`), não a resposta que o bot mandou.

**Ref:** tiatendo D16/B7 Fase 2 (2026-07-16→17). Fixes `4dd5bd5` (`_deferToFlow` + guard estrutural),
`e27834f` (`_refMatchesItem`). Reincidência de 2026-07-31: commits `4f369ca`, `bcd8ccf` (PROD
`0.268.0`/`0.269.0`), ADR-0014 do tiatendo. Memórias
`feedback-smoke-prod-pega-o-que-teste-e-conselho-nao-pegam`,
`project-4-frentes-e1-i1-reaper-d16-0222-2026-07-16`. Irmão: renderizar template sem DB p/ `[5-T]`
de tela, e pg efêmero p/ testes de DB que pulam em silêncio.

---

## Um fix commit que não re-roda a suíte de regressão enterra um RED sob "[5-T] local verde" {#fix-commit-sem-re-rodar-suite}

`tags: regressao, suite stale, 5-T, handoff verde, fix commit tardio, assert substring, html renderizado, style, emoji, glifo, checar marcacao`

**Sintoma:** handoff dizia "103 testes verdes / [5-T] local", mas ao retomar, `test_lojaCardE1` estava
RED. O fix commit anterior (badge no compacto) adicionou um comentário CSS com uma **estrela literal**,
e um teste PRÉ-EXISTENTE fazia checagem crua `"estrela" not in html` sobre o HTML inteiro (inclui o
`<style>` sempre renderizado). O commit de fix não re-rodou a suíte daquele arquivo → o RED passou
despercebido sob o "[5-T]" anterior.

**Solução:**
- Depois do ÚLTIMO commit de uma branch (inclusive fix commits tardios), **re-rode a suíte de
  regressão do alvo** — não confie no "[5-T]" tirado ANTES do último commit.
- Antes de deployar branch "pronta de sessão anterior", rode a suíte relevante uma vez — o "verde"
  do handoff pode estar stale.
- Asserção de presença/ausência em HTML renderizado: **cheque a marcação** (`class="x"`), NUNCA a
  substring crua do glifo/emoji — `<style>` sempre contém nomes de classe e comentários podem conter
  o glifo (foi um comentário CSS com emoji que quebrou o teste sem o produto mudar).

**Ref:** tiatendo E3-E6 loja (2026-07-17). Fix `390cece`. Memória `project-vitrine-e3-e6-loja-2026-07-17`.

---

## Resgatar linhas órfãs de migration aditiva (coluna nova NULL) via backfill + path real do coletor {#linhas-orfas-migration-aditiva}

`tags: migration aditiva, coluna nova, NULL, backfill, reaper, IS NOT NULL, linha orfa, docker exec, asyncio.run, dispatch sem persistir, scan cross-tenant`

**Sintoma:** um reaper filtra `WHERE col IS NOT NULL AND col < cutoff` (fail-safe: não age no que não
sabe datar). Linhas criadas ANTES da migration que adicionou `col` ficam `col=NULL` → nunca são pegas
(presas pra sempre). Caso tiatendo: conversa pausada antes da mig 100 (`bot_paused_at` NULL) ficava
muda; o reaper horário exige `IS NOT NULL`.

**Solução:**
- **Backfill** com proxy defensável (`col = updated_at`) SÓ nas linhas-alvo, guardado
  (`WHERE ... AND col IS NULL AND id = ...`); depois deixe o **loop de produção do próprio serviço**
  agir — ele traz o efeito colateral (notificação) junto, uma vez.
- **NÃO** invoque o path do reaper num `docker exec` bare achando que envia: efeitos que dependem do
  runtime (cliente de canal, tasks com delay) são cortados quando o `asyncio.run` fecha o loop — o
  UPDATE de estado funciona, o dispatch pode não. Invocar manual + disparar direto = risco de 2 cópias.
- Gotcha de inspeção via exec: `from mod import _cache` captura o dict ANTES do rebind — use o RETORNO
  da função de load; rode com cwd/-w correto (relativo a `TENANTS_DIR`/`/app`). E `dispatchResponse`
  (tiatendo) NÃO grava em `messages` (só no canal) — ausência lá ≠ não-enviado.
- Depois: **scan cross-tenant** do mesmo padrão órfão pra saber se é sistêmico.

**Ref:** tiatendo Fabiula (2026-07-17). Memória `project-vitrine-e3-e6-loja-2026-07-17`.

---

## Padronizar componente compartilhado: regra por POSIÇÃO vaza + env Jinja é por-rota (tiatendo I6) {#componente-compartilhado-posicao-e-env}

`tags: design system, componente compartilhado, css nth-child, regra por posicao, blast radius, Jinja2Templates, env globals, por-rota, macro, mock, widget de estoque`

Ao padronizar `.ti-table` (design system, 27 usos) e migrar o Caixa pro componente, dois vazamentos silenciosos:

- **Regra CSS keyed por posição vaza pra todos os usos do componente.** Uma regra `.ti-table td:nth-child(7){display:none}` escrita pro 7º col "No status" do **Orders** (≤1024px) aplicava a TODA `.ti-table`. No Caixa a 7ª `<td>` é o botão de AÇÃO → sumia no tablet/mobile. **Lição:** regra de componente ancorada em `nth-child(N)`/posição assume que toda instância tem o mesmo significado de coluna — quase nunca verdade. Escopar por classe do CONTEXTO (`#pagina .ti-table ...`) ou por classe semântica da célula, nunca por índice global. Fix seguro = override no escopo da página afetada, sem tocar a regra do outro consumidor (blast radius).

- **Cada módulo de rota do dashboard tem seu PRÓPRIO `Jinja2Templates`.** Um global registrado num (`statusLabelPt` em `ordersRoutes.env.globals`) NÃO existe no env de outra rota (caixa) → `{{ statusLabelPt() }}` renderiza vazio em PROD, mesmo com o teste "verde" (o teste registra o global à mão num Environment bare). **Reusar macro/partial que depende de global Jinja → registrar o global no env da rota que renderiza.** Macros importadas via `{% from %}` não sofrem (loader, não env.globals). Memória `feedback-per-route-jinja-env-globals-dont-share`.

**Regra de mock em widget de estoque (I5):** só mostrar "N restantes" onde `stock_qty` é coluna REAL e controlada (NULL = ilimitado, não aparece). Não inventar contagem — mesma decisão do rating-fora do E6.

**Ref:** tiatendo I6/I5 (2026-07-18), PROD `0.224.0`/`0.225.0`. Memória `project-vitrine-e3-e6-loja-2026-07-17`.

---

## Verificar UI: o que "não aparece" no screenshot pode ser artefato da ferramenta, não bug (Micro Investors F2) {#ui-falso-negativo-da-ferramenta}

`tags: playwright, fullPage, screenshot, falso negativo, DOM, naturalWidth, getBoundingClientRect, tailwind v4, turbopack, chunk css, IACVT, var indefinida, canal alpha, png`

Três falsos-negativos numa sessão só, todos do mesmo tipo — **o instrumento mentiu, não o código**:

- **`fullPage: true` do Playwright distorce `position:absolute` + `mask-image`.** Uma foto no hero
  (absolute, com máscara em gradiente) **sumiu** do screenshot fullPage em prod e quase virou "bug de
  deploy". A prova real veio do **DOM**: `img.complete=true`, `naturalWidth=669`, `getBoundingClientRect`
  visível — e o screenshot de **viewport** mostrou a imagem. **Regra:** antes de declarar "não renderiza",
  cheque o DOM (complete/naturalWidth/rect/display computado); use fullPage pra composição geral, nunca
  como prova de que um elemento posicionado existe.

- **Tailwind v4 + Turbopack fragmenta o CSS em vários chunks no DEV.** Procurar `.bg-navy` no chunk que
  o `<link>` aponta e não achar NÃO significa que o utilitário não foi gerado (nem `.bg-primary` estava
  lá). **Verifique no CSS de PRODUÇÃO** (`.next/static/chunks/*.css` após o build) — é o que vai pro deploy.

- **Classe gerada ≠ classe que pinta.** `.bg-navy{background-color:var(--navy)}` só funciona se `--navy`
  existir no CSS servido; `var()` de variável indefinida invalida a declaração inteira (IACVT) e a regra
  vira no-op silencioso — o mesmo mecanismo que já derrubou a fonte pro Times New Roman neste projeto.
  **Verifique o PAR: a regra E a variável.**

- **Bônus (imagem):** um PNG que "parece ter fundo bege" pode ser recorte com alpha — a prévia compõe
  sobre fundo claro. Cheque o canal alpha (mapa de opacidade) ANTES de aplicar máscara/`multiply` pra
  "esconder o fundo": tratar um fundo que não existe só escurece o assunto.

**Ref:** Micro Investors F2 home (portal `v8`, 2026-07-18).

---

## `deepseek-review.sh` morre com "jq: Argument list too long" (diff > ~30KB no Windows) {#jq-argv-too-long-review}

`tags: deepseek-review, jq, argument list too long, argv 32kb, windows, git-bash, diff grande, package-lock, commit em lotes, git stash, PreToolUse, hook R11`

**Sintoma:** R11 falha em `line 123: jq: Argument list too long`. Não é bug do jq — é o **limite de argv
do Windows/git-bash (~32KB)**: o script passa `AGENTS.md` + o diff inteiro via `--arg`. Um `package-lock.json`
no diff (ou ~500 linhas de código novo) já estoura.

**Solução:** dividir o trabalho em **lotes menores, cada um com sua própria review** (respeita R11) —
`git stash push -- <paths do lote 2>`, revisa e fecha o lote 1, `git stash pop`, revisa e fecha o lote 2.
Lockfile vai isolado (`chore:`, sem lógica). **NÃO** bypasse o hook: o gate continua válido, só o
transporte é que não cabe.

**Gotcha do hook (PreToolUse):** ele bloqueia o **comando Bash inteiro** antes de executar. Se você
encadeou `git add X && git ...`, o `git add` **NUNCA roda** — então a correção que você acabou de fazer
no arquivo continua fora do stage e o hook reclama do mesmo problema em loop. **Rode o `git add` sozinho**,
confirme com `git show :<arquivo>`, e só então feche. (Idem: o hook casa por TEXTO — escrever a palavra
num heredoc de documentação já dispara o gate.)

**Ref:** Micro Investors F2 (2026-07-18), plugin percus-review 6.28.0.

---

## Bug de fuso multi-tenant tem 4 camadas — e a mais traiçoeira é o YAML, não o código {#fuso-multi-tenant-4-camadas}

`tags: timezone, fuso, multi-tenant, yaml do tenant, cadeia de fallback, AT TIME ZONE, date_trunc, timestamptz, EXTRACT EPOCH, toBrasilia, rename nao shim, scp yaml prod, teste-lint`

**Sintoma:** relatório mostra dado no dia/hora errados pra tenant fora do fuso "padrão" da equipe.
No caso real (tiatendo, cliente em Dourados/MS = UTC−4): pedido às 20:00 **locais** virava 00:00 UTC
do dia seguinte → **o jantar inteiro**, pico de faturamento do restaurante, caía no dia da semana errado.

**As 4 camadas — corrigir só uma NÃO resolve:**
1. **Config (YAML do tenant)** — o fuso declarado está errado, ou mora num bloco que a cadeia de
   resolução não lê. **É a mais traiçoeira: com o YAML errado, o código corrigido devolve hora errada
   OBEDIENTEMENTE.** Ninguém desconfia porque o código "está certo".
2. **Cadeia de fallback** — o resolvedor só olha alguns elos e cai no default **em silêncio**.
3. **SQL** — `EXTRACT(DOW/WEEK/YEAR/HOUR ...)`, `date_trunc('day', ...)`, `::date` sobre coluna
   `timestamptz` roda no fuso da SESSÃO do banco (UTC), não do tenant.
4. **Render** — helper de formatação com fuso cravado (`toBrasilia`, `BRT = -03:00`).

**⚠️ A armadilha que quase me pegou: consertar a cadeia SOZINHA pode PIORAR tenants.**
Dois tenants declaravam `America/New_York` num bloco que a cadeia quebrada nunca lia — resolviam o
default (BRT) **por acidente, e por acaso certo**. Consertar a cadeia os faria resolver New_York **de
verdade**, deslocando 5h. Fix da cadeia e correção dos YAMLs têm que ir no **MESMO commit**.

**Detalhes de SQL que custam caro:**
- **Round-trip DUPLO** pro "hoje" do tenant:
  `date_trunc('day', now() AT TIME ZONE $tz) AT TIME ZONE $tz`. A 1ª conversão leva pro relógio local
  (naive), o `date_trunc` acha a meia-noite local, a 2ª volta pra `timestamptz` comparável com a
  coluna. **Aplicar só a 1ª produz OUTRO resultado errado, não o certo.**
- **`AT TIME ZONE` depende do TIPO da coluna**: sobre `timestamptz` devolve naive; sobre `timestamp`
  naive devolve `timestamptz` — e aí a dupla aplicação **inverte o sinal**. Pré-voo obrigatório em
  `information_schema.columns` antes de aplicar.
- **`EXTRACT(EPOCH FROM (a - b))` é IMUNE a fuso** (subtração = intervalo). "Corrigir" quebra a métrica
  de duração.

**Migração do render: RENAME, não shim.** Trocar `toBrasilia` → `toTenantTime(dt, tz, fmt)` com tz
obrigatório e **apagando o nome antigo** faz call site esquecido quebrar **no import**, não em produção.
Um shim com default preserva exatamente o modo silencioso pelo qual o bug sobreviveu.

**⚠️ NUNCA `scp` um YAML de tenant por cima do de produção.** Os arquivos de prod divergem do repo
(chaves, flags, campos operacionais). Faça `diff` primeiro e edite **só a linha do fuso**, in-place
(`sed`). No caso real, o arquivo de prod tinha 179 linhas contra 163 do repo.

**Fechar com trava, não com documentação.** O bug reapareceu **3× em um único dia** com a regra já
escrita na memória do projeto. Um teste-lint que varre o código atrás do padrão errado é o que segura.
Dois critérios de aceite: (a) tem que pegar as **instâncias históricas reais** — se alguma escapar, o
desenho está errado e **não se ajusta o corpus pra passar**; (b) **não pode acusar os casos corretos**
(os `EPOCH` de duração), senão vira ruído e alguém desliga na primeira semana.

**Ref:** tiatendo `0.229.0`→`0.231.0` (2026-07-19), spec `2026-07-18-fuso-do-tenant-sweep-design.md`.

---

## "Concluída" decidida pelo TEXTO do status apodrece em silêncio quando o produto deixa renomear {#status-por-texto-apodrece}

`tags: status, texto do status, ILIKE cancel, IN done completed, renomear situacao, completed_at, cancelled_at, predicado centralizado, progresso, metrica divergente`

**Sintoma:** métricas e telas erram só para *algumas* organizações — as que renomearam a situação
terminal. Barra de progresso da tarefa-mãe em 0% com tudo pronto; aviso de prazo cobrando tarefa já
entregue; contagem de "concluídas" divergindo entre dois gráficos da mesma tela.

**Causa raiz:** o código compara `status` com uma lista fixa (`IN ('done','completed','concluido')`) ou por
substring (`ILIKE '%cancel%'`). Funciona no seed padrão e quebra no minuto em que alguém chama a
situação de "Entregue" ou "ABORTADO". A heurística de substring erra nos **dois** sentidos: deixa
passar o que devia excluir ("ABORTADO" não casa "cancel") **e** exclui o que devia passar
("Cancelamento aprovado" é um desfecho concluído).

**Correção:** um marcador booleano/timestamp, nunca o texto. No caso: `completed_at` + `cancelled_at`,
com predicados centralizados num módulo só (`is_done`, `is_terminal`, `is_open`) em duas formas —
expressão ORM e fragmento SQL cru — para que query hand-rolled e ORM não divirjam.

**O que torna isto caro:** não é um call-site, são vários, e eles **não aparecem juntos no grep óbvio**
(um usa `IN`, outro `ILIKE`, outro nem filtra). Num único épico apareceram **5**, e o mais grave
(progresso da tarefa-mãe) já estava documentado como armadilha conhecida no projeto — o call-site
simplesmente nunca tinha sido migrado. Documentar não fecha; **grep dirigido antes de tocar em
qualquer contagem** fecha:

```
grep -rn "status.in_(\|status NOT IN\|ilike(\"%cancel\|'done', 'completed'" backend/app/
```

**Achado por teste, não por leitura.** O 5º bug apareceu porque um teste escrito para *outra* coisa
(progresso da mãe após PATCH via API) falhou com `Decimal('0.00') == 100`. Teste de integração que
exercita o efeito colateral real encontra o que a revisão de diff não vê.

**Ref:** Plexco Tasks s141 (2026-07-18/19), épico WS-C F3 `/ext` escrita.

---

## Escape que atravessa camadas de transporte pode virar troca de X por X — com "ok" mentiroso {#escape-atravessa-camadas-noop}

`tags: escape, backslash, heredoc, bash, python, em-dash, no-op, verificacao em bytes, assert do novo, encoding, fix fantasma, ok mentiroso`

**Sintoma:** script de fix (bash heredoc → python) imprime "ok", assert de `count==1` passa, testes verdes — e o arquivo continua EXATAMENTE igual. Dois reviewers independentes acharam o defeito "corrigido" ainda vivo.

**Causa raiz:** cada camada de transporte pode consumir um nível de backslash. No caso: `new = '") \\u2014 mesmo'` num heredoc chegou no Python como `—` — que É o próprio em-dash. O replace trocou em-dash por em-dash: no-op sintaticamente perfeito, com toda a aparência de sucesso (o assert checava o ANTIGO, que existia mesmo; o write escreveu o mesmo conteúdo).

**Solução:**
1. **Verificação de fix de encoding/escape é SEMPRE em bytes**, nunca em string de alto nível: `open(p,'rb').read().count(b'\xe2\x80\x94')` não mente; `'—' in line` depende de quantas camadas o literal do próprio CHECK atravessou (o meu check tinha o MESMO bug do fix).
2. Pra editar escape em arquivo, usar ferramenta que NÃO processa escapes (Edit tool / editor direto), não string através de shell.
3. Assert de fix não é "o padrão antigo existia" — é "o padrão NOVO existe e o antigo NÃO": `assert new in s and old not in s` teria pego na hora.

**Ref:** Paid Media cont.106.3, em-dash no template do loader (`proxy/router.py`). Só o quality reviewer batendo em bytes revelou.

---

## Deploy delta com base defasada REVERTE feature entregue — e o smoke de feature não pega {#deploy-delta-base-defasada}

`tags: deploy delta, imagem base, COPY parcial, feature revertida, bisseccao de imagem, manifesto de hashes, CRLF LF, falso positivo, default silencioso, log por assinatura`

**Sintoma:** features marcadas `[5-T]` com smoke em produção NA ÉPOCA simplesmente não estão mais lá semanas/dias depois. No caso: 5 features (widget de estoque, nav, e 3 da vitrine da loja) mortas em produção por ~23h, incluindo **zero ocorrências na página pública que o cliente final vê**.

**Causa raiz:** deploy delta (`FROM <imagem-base>` + `COPY` só dos arquivos mudados) usando uma base ANTERIOR às features já entregues. Tudo que entrou entre a base e a atual não é apagado — é **nunca copiado**. O serviço sobe, `/health` responde 200, e o smoke da feature nova passa.

**Por que fica invisível:** o consumidor da função sumida chamava dentro de um `_safe(..., [])`. O card mostrava "sem alertas", que é *indistinguível* de "está tudo em estoque". O único sintoma era 1 linha de ERROR por minuto num log que ninguém lia.

**Solução:**
1. **Bissecção nas imagens** acha o instante exato, sem adivinhação:
   `docker run --rm --entrypoint grep <img>:<versao> -c "def minhaFuncao" /app/caminho.py` em cada versão.
2. **Comparar a ÁRVORE INTEIRA**, não a feature: manifesto de hashes do HEAD × árvore da imagem, rodado **entre `docker build` e `docker service update`**. Smoke de feature prova que a NOVA subiu; só o diff de árvore prova que as ANTIGAS sobreviveram.
3. **Normalizar fim de linha antes de hashear.** Sem isso, manifesto gerado no Windows (CRLF) contra imagem via `git archive` (LF) acusa TODO arquivo de texto — 158 falsos positivos na 1ª execução real. Falso positivo em massa MATA a trava: na 2ª vez que grita sem motivo, alguém a remove do processo.
4. Se for usar base rasa/antiga pra evitar `max depth`, o `COPY` tem que levar a árvore inteira, não o diff.

**Regra geral:** `except`/default silencioso transforma bug de deploy em bug invisível. Ao varrer produção atrás de falha engolida, agrupar o log por assinatura (`sed` normalizando ids + `sort | uniq -c`) revela em segundos o que passa despercebido linha a linha.

**Ref:** tiatendo, imagens `0.226.0`→`0.232.0`. Trava: `scripts/verifyImageMatchesHead.py`.

---

## Conselho responde bem à pergunta errada quando o contexto omite uma restrição {#conselho-contexto-incompleto}

`tags: conselho, council, pre-mortem, prompt incompleto, restricao de fluxo, multi-turno, veredito, autoridade do operador, reversao documentada`

**Sintoma:** conselho 3-membros dá veredito coeso (2/3, 3/3), o agente implementa, e o operador aponta na hora um caminho melhor que o conselho nem considerou.

**Causa raiz:** o prompt do conselho descreveu o problema sem uma restrição decisiva. No caso: perguntei se o bot devia "avisar ou perguntar" quando um item some do pedido, informando que o resumo é ecoado no fim — mas **omiti que o checkout é multi-turno** (o bot ainda faz 1 a 4 perguntas antes de fechar). O argumento central deles ("o cliente quis encerrar, não incomode") desmonta na hora: vamos incomodar de qualquer jeito.

**Solução:**
1. Antes de submeter, listar as **restrições de FLUXO** — o que acontece antes e depois do ponto de decisão, quantos turnos, o que ainda é reversível. Decisão de UX conversacional depende disso mais que do conteúdo da mensagem.
2. Perguntar-se: **"o que ainda é possível fazer nesse instante?"** No caso, a restrição que decidia era "o rascunho ainda está ABERTO, dá pra incluir o item de verdade" — depois do fechamento, perguntar prometeria o que não se pode cumprir.
3. Veredito do conselho **não vira autoridade sobre o operador**, que tem contexto de negócio que nenhum provider tem (ali: item omitido = venda perdida + chamado de suporte).
4. Ao registrar a reversão, dizer QUE o conselho errou **e por quê o input estava incompleto** — senão a próxima sessão relê o veredito antigo e reverte de novo.

**Ref:** tiatendo D16 (`0.236.0`). O desenho final ficou melhor que as 3 opções submetidas: pergunta 1× com escape + o aviso passivo do conselho como rede.

---

## Scheduler novo sobre tabela velha: dedup por MARCADOR, senão a linha fóssil engole o 1º disparo {#scheduler-dedup-por-marcador}

`tags: scheduler, cron, dedup, linha fossil, upsert, marcador, report_meta, catch-up, restart, yaml sexagesimal, HH:MM vira 540, contrato de shape, degrade com warning`

**Sintoma:** você troca um job agendado (ex.: relatório semanal domingo 03:00 UTC fixo) por um scheduler por-tenant com dedup persistente numa tabela que o job ANTIGO também escrevia. Na transição, o job antigo já gravou a linha da semana corrente → o scheduler novo vê "já existe" e **pula o 1º envio novo em silêncio**. Ninguém percebe: não há erro, só ausência.

**Solução:**
1. **Linha nova carrega um marcador** (ex.: chave `report_meta` no JSONB de metrics). O dedup checa o MARCADOR, não a existência da linha: linha fóssil (sem marcador) não bloqueia — o 1º disparo novo sobrescreve por cima (upsert).
2. Dedup em memória (`_lastRun` global) **não sobrevive a restart/redeploy** — se o restart cair no dia do disparo, ou duplica ou engole. Persistir na tabela que já tem unique (tenant, período) sai de graça.
3. Semântica catch-up ("1× por semana A PARTIR do instante agendado", não "== hora agendada") tolera o processo fora do ar no horário; o dedup persistente é o que impede o duplo envio.
4. Config de horário vinda de YAML: `report_time: 09:00` SEM aspas é **sexagesimal no YAML 1.1 → int 540** (9×60). O parser tem que aceitar `str "HH:MM"` E `int minutos`, senão o horário configurado é trocado pelo default em silêncio.

**Bônus da mesma sessão (contrato de shape entre caller e helper):** `sendPersonalAlert(config, msg)` lê `config["specialistPhone"]`; um caller passava o `tenantConfig` INTEIRO (onde o campo é `specialist.personal_whatsapp`) → warning logado e **nenhum envio, durante meses**. Helper de envio que "degrada com warning" quando falta campo esconde erro de contrato pra sempre — teste que trava o SHAPE do argumento (`assert config == {"specialistPhone": ...}`) pega na hora.

**Ref:** tiatendo `0.237.0`, reconstrução do Relatório Semanal (`execution/quality/reportScheduler.py` + `execution/plugins/restaurant/weeklyReport.py`).

---

## Build no VPS falha puxando imagem PÚBLICA do ghcr.io ("denied") + `${VAR}` do stack deploy é no-op {#ghcr-denied-stale-login}

`tags: ghcr docker denied login stale build vps pull imagem-publica stack-deploy`

**Sintomas (2 no mesmo deploy, Scraper-prospeccao 2026-07-19):**
1. `docker build` falha em `COPY --from=ghcr.io/astral-sh/uv:<tag>` com `failed to fetch oauth token: denied` — parece rate-limit ou imagem privada, mas a imagem é pública e o build já funcionou antes na mesma máquina.
2. `API_IMAGE=nova-tag docker stack deploy -c stack.yml <stack>` termina "update completed"… com a imagem VELHA. Nem `export` + `echo $API_IMAGE` provando a var setada muda nada.

**Causas:**
1. **Login VELHO no ghcr.io** em `/root/.docker/config.json` (`auths["ghcr.io"]` com token expirado). Docker manda a credencial podre e o registry NEGA — o pull anônimo teria funcionado.
2. O `docker stack deploy` do host **não interpola `${VAR:-default}` do ambiente** — reaplica o default do yml. Update "completed" com imagem velha = no-op silencioso.

**Solução:**
1. `docker logout ghcr.io` → rebuild (pull anônimo).
2. Não passar tag por env var: **editar o default no `deploy/stack.yml` (repo = fonte da verdade) → `scp` pro VPS → `docker stack deploy`**. SEMPRE conferir depois: `docker service inspect <svc> --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` — replicas 1/1 não prova imagem nova.

**Ref:** Scraper-prospeccao, deploy `2026-07-19-nr1` (página niche-review). Memória: `reference_deploy_swarm_local_image_gotchas`.

---

## "O backend já aceita X" — repo ≠ imagem em prod (422 silencioso pós-deploy parcial) {#repo-nao-e-imagem-em-prod}

`tags: repo vs imagem, deploy parcial, 422, Literal, capacidade nao verificada, handoff herdado, smoke honeypot, gate de versao no deploy, milestone review`

**Sintoma:** feature nova (form do `/investors`) 100% pronta e testada em código; o HANDOFF afirmava "o backend já aceita `source=investors` desde `d3ec75e`". Verdade **no repo** — mas a imagem em prod (`:0.2.40`) foi buildada ANTES desse commit, e o POST levava **422** (`Input should be 'portal' or 'landing'`). Se o portal tivesse subido sozinho, 100% dos leads da página de captação quebrariam com "Algo deu errado" e nada apareceria em log de erro do portal.

**Causa raiz:** afirmação de capacidade baseada em `git log`, não na imagem deployada. Commits de fundação (schema/Literal/notifier) entram no repo semanas antes do deploy que os carrega.

**Solução (2 camadas):**
1. **Smoke da capacidade direto em prod ANTES do deploy dependente**, sem side-effect: POST com **honeypot preenchido** (`website`) — se o Literal aceita, vem 201 falso sem persistir nada; se não, vem o 422. Custo: 1 curl.
2. **Milestone review adversarial paga:** foi o revisor cross-contexto (subagente de contexto limpo) que testou ao vivo e derrubou a premissa — o autor do plano (eu) tinha herdado a afirmação do HANDOFF sem re-verificar.

**Padrão do gate no script de deploy:** o deploy dependente começa com `curl /health` e **aborta** se a versão exigida não está em prod (ver `.tmp/deploy_frontend_v76.py` step 0 no Micro Investors).

**Ref:** Micro Investors, deploy F3 `portal:v9` (2026-07-19). O fix virou a ordem: `:0.2.41` → `v9` → `v76`.

---

## Monitor passivo: o erro que você viu no probe ativo pode NÃO existir no pipe {#monitor-passivo-corpo-do-erro}

`tags: monitor passivo, probe ativo, event_log, corpo do erro, no_click_id, validateOnly, skip deliberado, response_ok, vocabulario de skips, gabarito impossivel`

**Sintoma:** o gabarito do smoke exigia que o `INVALID_CONVERSION_ACTION_TYPE` do Moper (achado da auditoria) aparecesse no `detail` do elo entrega. O monitor devolveu `no_click_id`. Parecia bug do monitor — não era: probe `SELECT ... WHERE google_ads_response_body ILIKE '%INVALID%'` → **0 linhas em 60 tentativas**.

**Causa raiz:** o corpo de um erro só existe onde (a) o request realmente FOI feito e (b) o caminho grava a resposta. Os 60 envios do Moper morrem em `no_click_id` ANTES de chegar na API do Google; o `INVALID_CONVERSION_ACTION_TYPE` da auditoria veio do NOSSO `validateOnly` via service-layer — que **não passa pelo event_log**. Prometer detecção passiva de um erro sem checar onde o corpo mora = gabarito impossível.

**Solução (2 regras):**
1. Antes de prometer que um monitor passivo detecta o erro X, probe **onde o corpo mora**: `SELECT COUNT(*) FILTER (WHERE body ILIKE '%X%')` na tabela que o monitor lê. Se 0, o X é detectável só por sonda ATIVA — documentar, não forçar o gabarito.
2. **Skip deliberado ≠ falha, mas o pipe grava igual**: `ga4_sent_by_site` (auto-bridge suprime envio), `no_click_id` (orgânico), `missing_meta_config` — todos ficam com `response_ok=0` e passivamente são indistinguíveis de falha real. A camada que classifica precisa de um vocabulário de skips (espelhar `_CONFIG_SKIPS` do capi_fanout) antes de pintar o elo de vermelho.

**Ref:** Paid Media Automation, cont.107 (fatia 1 do monitor de saúde, 2026-07-19). O item #4 do gabarito virou "conferir → fatia 2" com prova, em vez de um fix errado na regra. Memória: `project_tracking_health_monitor_fatia1`.

---

## Kill-switch cujo gate mora nos call-sites cobre menos do que promete — e o docstring vira mentira {#kill-switch-no-facade}

`tags: kill-switch, feature flag, gate, call-site, facade, keyword-only sem default, fail-closed, cobertura parcial, docstring mentira, whatsapp proativo, cold outreach, guard-rail, inspect.signature, funcao fantasma, 409, silencio declarado`

**Sintoma:** kill-switch de envio proativo de WhatsApp (`WA_PROACTIVE_ENABLED`) deployado, flag confirmada `false` em prod, log provando quarentena no startup. Mesmo assim, um clique em `/admin/engajamento/disparar` dispararia **cold outreach em massa** — exatamente o perfil que derruba o device. O docstring dizia "nada é iniciado por nós"; a v1 gateava **2 de 8** remetentes.

**Causa raiz:** o gate foi implementado nos **call-sites**, um por um. Isso torna a cobertura uma função da memória de quem escreve: remetente novo **nasce sem gate** e nada avisa. Pior que não ter switch — a v1 produzia confiança falsa em quem lia o docstring. Um inventário achou 14 remetentes proativos com zero switches.

**Solução (3 camadas, nessa ordem de valor):**
1. **Gate no FACADE, com a decisão obrigatória.** `sendMessage(..., *, proativo: bool)` **keyword-only SEM default**. Sem default é o ponto todo: default `False` faz remetente novo nascer sem gate de novo (a falha original); default `True` deixa o bot **mudo pra usuário real** no primeiro esquecimento. Sem default, esquecer é `TypeError` **alto**, pego pela suíte antes de prod. "Fail-closed" aqui é sobre a DECISÃO ser obrigatória, não sobre bloquear por omissão.
2. **Guard-rail na SUPERFÍCIE do facade, não só nos call-sites.** Validar "todo call-site declarou" deixa o buraco simétrico: uma `sendImage()` nova **no próprio facade** nasce sem gate e todos os testes ficam verdes. Teste por `inspect.signature`: toda corrotina de envio precisa do parâmetro; isenção (`checkNumberExists`) só explícita numa allowlist.
3. **Provar o guard-rail com função fantasma.** Criar o remetente/função que deveria ser pego, rodar (tem que falhar **nomeando-o**), remover. Sem isso você tem um teste que passa, não um teste que protege — foi assim que se descobriu que o padrão antigo (`\b(?:evo|wa_client)\.send…`) devolvia `False` pra `gowa_client.sendMessage`.

**Efeito colateral a decidir conscientemente:** classificar honestamente revela envios que "pareciam inbound" mas são reach-out a terceiro — ex.: escalação pro número de SUPORTE nasce de um inbound, mas quem recebe **não escreveu pra nós**. Marcar como proativo silencia a escalação durante a quarentena; aceitável só porque o registro (`WhatsappLog`) é gravado **antes** e independe do envio. Decida e documente, não deixe implícito.

**Regra geral:** *silêncio de kill-switch precisa ser DECLARADO.* Um endpoint que devolve `200` com zeros na quarentena faz a UI dar toast **verde** de sucesso — a mitigação escrita em `resultado["detalhes"]` era código morto (o front nunca renderizava). Use **409 + `detail`**, e conte a verdade a quem depende do envio (quem adicionou um membro precisa saber que a pessoa **não** foi avisada).

**Ref:** Família Milionária, 2026-07-16 → 19. Commits `25e0a69` (v2 nos call-sites) → `04a5485` (facade). Memória: `incident_2026_07_16_device_ban_numero_queimado`.

---

## View `SELECT *` congela colunas na criação — prod "funciona" e instalação fresca quebra (e a suíte verde não te conta) {#view-select-star-congela-colunas}

`tags: postgres, view, SELECT *, CREATE OR REPLACE VIEW, migration, instalacao fresca, fresh install, schema drift, column does not exist, schema_migrations, ledger de migration, idempotente, testes skipped em silencio, suite verde falsa, pg efemero, pgvector`

**Sintoma:** validação de feature nova em pg efêmero (instalação FRESCA via `setupDatabase()`): `column o.payment_method does not exist` num caminho central (`listUnpaid`), mais fixtures inserindo colunas inexistentes (`tenants.company_name`). Em PROD tudo funciona há semanas. A tabela TEM a coluna; a **view** (`orders_real AS SELECT * FROM orders`, criada na migration 041) não — view congela o conjunto de colunas NA CRIAÇÃO, e a coluna nasceu na 068.

**Causa (dupla):**
1. **Era pré-ledger mascarou o drift:** até o ledger `schema_migrations` existir (2026-07-05 no tiatendo), toda migration re-executava idempotente a cada deploy — o `CREATE OR REPLACE VIEW` da 041 se re-aplicava e "via" as colunas novas. Com o ledger, cada migration roda 1× na ordem → instalação fresca congela a view pré-068. **Prod e fresh divergem sem ninguém mudar uma linha.**
2. **A suíte "verde" não provava nada disso:** o guard de segurança (dbSafety esvazia DSN sem "test" no nome) fez os `needs_db` PULAREM em silêncio em toda máquina local — "4533 passed / 0 failed" com o coração de banco não-verificado. Fixtures fósseis (colunas de um schema antigo de outro produto) sobreviveram meses assim.

**Solução:**
1. Migration nova que re-emite o `CREATE OR REPLACE VIEW` (re-congela com as colunas atuais; append de colunas no fim é permitido pelo Postgres, prefixo preservado porque a view veio de `SELECT *` da MESMA tabela). Em prod tende a ser no-op.
2. Grep de auditoria: `CREATE .*VIEW` + `SELECT \*` nas migrations — toda view assim é uma bomba de fresh-install se a tabela ganhar coluna depois.
3. O número "X passed" de suíte só vale com a contagem de SKIPPED ao lado; gate real de feature de banco = pg efêmero (pgvector!) + `setupDatabase()` + pytest no container. Baseline pra separar "eu quebrei" de "já estava quebrado": mesmos testes com o código DA IMAGEM de prod, montando só `tests/` por cima.

**Ref:** tiatendo, 2026-07-20, Task 7 da venda manual (migration `101_refresh_orders_real_view.sql`). Memória: `project-venda-manual-caixa-2026-07-20`.

---

## Worker precisa de segredo que outro serviço cifrou → sonda roda DENTRO do serviço dono (endpoint interno fail-closed) {#sonda-no-servico-dono-do-segredo}

`tags: segredo cifrado, criptografia divergente, AES-GCM, AES-CBC, scrypt, master key, blast radius, endpoint interno, X-Internal-Auth, hmac.compare_digest, constant-time, fail-closed, traefik host rule, exposto na internet, worker, monitor de saude, degradar nao abortar`

**Sintoma:** job agendado no worker precisa validar/usar credenciais de tenant cifradas por OUTRO serviço, e a descriptografia falha ou exigiria copiar a master key. Causa-raiz típica: criptos diferentes por design (Paid Media: worker = AES-CBC + scrypt de `ENCRYPTION_KEY`; tracking = AES-GCM + `PMT_MASTER_KEY`). Copiar a chave amplia blast radius; duplicar a lógica de probe cria drift.

**Solução:**
1. A sonda roda DENTRO do serviço dono do segredo, reusando o módulo existente (ex.: `credential_test.py`), exposta num endpoint interno (`POST /internal/...`).
2. Auth por header de segredo compartilhado (`X-Internal-Auth`) com `hmac.compare_digest` (constant-time) e **fail-closed**: env ausente ⇒ 403 SEMPRE, travado por teste.
3. ⚠️ Se o Traefik roteia o serviço por **Host rule**, `/internal` é alcançável da INTERNET — o header é o único gate; "rede interna" não protege nada. Smoke obrigatório: curl público sem header ⇒ 403.
4. O cliente no worker NUNCA levanta exceção (serviço fora ⇒ elo degrada pra `desconhecido`, não aborta a varredura) e retorna `(resultado, motivo_erro)`.

**Ref:** Paid Media Automation, 2026-07-20, fatia 2 do monitor de saúde (elo credencial). Memória: `project_tracking_health_monitor_fatia2`.

---

## QR code de pareamento "não linka" → suspeite do SEU refresh antes de culpar o provedor {#qr-pareamento-expira}

`tags: qr code, whatsapp, pareamento, linkar dispositivo, nao consigo conectar, qr_duration, codigo expirado, gowa, whatsmeow, baileys, handshake ausente, loop de refresh, aba abandonada, host compartilhado, log flood, polling, visibilitychange, template literal, script inline sem teste`

**Sintoma:** usuário escaneia o QR e o celular diz "não é possível conectar novos dispositivos agora"; nos logs do servidor de WhatsApp **não aparece handshake nenhum**. A ausência de handshake parece provar que a recusa é do provedor — e foi o que nos fez perseguir "conta Business", "bug do iOS" e "versão do servidor" por semanas.

**Causa-raiz real:** o QR expira rápido (GOWA: `qr_duration: 30s`) e só é reemitido na próxima chamada de login. Se a UI busca o código **uma vez** e congela a imagem, quem demora mais que a janela escaneia um código morto — e o WhatsApp recusa isso **do lado dele**, antes de tocar o seu servidor. Daí o log limpo.

**Solução:**
1. **Teste decisivo e barato:** parear direto pela UI nativa do provedor (que auto-renova o QR). Funcionou lá e não no seu painel ⇒ o culpado é seu, não do provedor. Isso encerra a discussão em 2 minutos.
2. Renove o QR antes de expirar (`qr_duration - 5s`), mas **com teto** (ex.: 5 tentativas ≈ 2min) e um botão "gerar novo". Loop sem teto inunda host compartilhado — se o host é de outro time, isso vira incidente **deles** (nos cegou durante a investigação de uma queda real).
3. ⚠️ **Não use o status da conexão como sinal de "pareando".** O provedor reporta `is_logged_in:false` para device não pareado, o que normaliza para `disconnected` — que também é o estado ocioso. Parar o loop nesse status mata o refresh ~200ms depois do clique (loop roda **zero** vezes); e quando o poll de status falha, a linha fica `connecting` e o loop roda **para sempre**. Os dois sintomas, opostos, têm a mesma raiz. Use um **orçamento de tentativas explícito**, não o status.
4. **Trave também no servidor** (429 por instância). É o único mecanismo que alcança **abas já abertas** rodando o JS antigo — um fix só no cliente não chega nelas. Bônus: clientes antigos costumam parar o loop em qualquer resposta não-OK, e se o refresh automático deles é silencioso, o 429 os aposenta sem erro visível.
5. Não renderize QR persistido em banco numa recarga de página: sem timestamp, ele está sempre vencido.

**Armadilha de processo:** JS de painel dentro de template literal não é lido pelo `tsc` **nem por teste nenhum** — foi assim que o bug subiu com "build verde". Extraia a lógica de decisão para um módulo compilado **pelo mesmo source** que a página e pelo spec, e teste "parar" e "exibir" como complementos exatos (property test) — eles divergiram e um status exibia QR enquanto cancelava o próprio refresh.

**Ref:** GHL-GOWA-WhatsApp, 2026-07-16/19. Cliente pagante 3 dias sem conseguir parear. Commits `3b55593`, `4ddd027`. Memória: `gowa-linking-blocked-whatsapp-side`.

---

## Dois produtos na MESMA conta Stripe → todo webhook chega nos dois; discrimine por preço {#stripe-cross-talk-dois-adapters}

`tags: stripe, webhook, checkout.session.completed, dois produtos, mesma conta, cross-talk, provisionou no lugar errado, metadata identica, price id, endpoint nao registrado, assinatura cancelada, remove, direito de uso, entitlement`

**Sintoma:** cliente paga, o painel volta pra tela de pagamento e nada é provisionado — mas o Stripe mostra `succeeded` e a assinatura ativa.

**Causa raiz:** não havia endpoint de webhook registrado para o serviço novo. O **único** endpoint registrado na conta era o do serviço legado, que consumiu o `checkout.session.completed` e provisionou **no banco dele**. O serviço novo nunca soube do pagamento.

**Solução:**
1. Confira `GET /v1/webhook_endpoints` **antes** de culpar o código — o evento pode estar sendo entregue a outro serviço da mesma conta.
2. Registrar o endpoint **não basta**: com dois produtos na mesma conta, os dois passam a receber **todos** os eventos. A metadata da sessão costuma ser idêntica entre produtos, então **o `price` é o único discriminador confiável** — filtre por ele no handler dos dois lados.
3. ⚠️ **Nunca deixe "remover recurso" cancelar a assinatura.** A assinatura é o **direito** a uma instância: remover o recurso deve liberar o slot, não encerrar o contrato. Um cliente clicou "Remove" para religar e perdeu, sem refund, o que pagara 40 minutos antes. Cancelar assinatura é ação separada e explícita.
4. Remediação sem cobrar de novo: assinatura nova com `trial_end` cobrindo o período já pago, **reaplicando o cupom** (o desconto não migra sozinho, e cancelamento no Stripe é terminal).

**Ref:** GHL-GOWA-WhatsApp, 2026-07-16. Commit `5e796c2`.

---

## Tag de plano aberta que já foi entregue sob OUTRO número de migration {#migration-numero-reciclado}

`tags: plano, tag aberta, pendencia falsa, migration numerada, numero reciclado, obra ja entregue, auditoria de plano, frente fossil, arqueologia, PLANO.md, drift de plano`

**Sintoma:** o plano tem dezenas de tags abertas de meses atrás. Parecem trabalho pendente, mas ninguém lembra de tê-las abandonado — e a feature parece existir em produção.

**Causa raiz:** planos antigos citam a obra pelo **número da migration** (`054`, `055`). Quando aquela frente parou, os números foram **reciclados** por frentes posteriores. A obra acabou sendo entregue depois, sob outro número e outro nome — e a tag antiga ficou aberta apontando para um identificador que hoje significa outra coisa. Ninguém fechou porque ninguém sabia que já estava feito.

**Solução:**
1. **Não julgue frente antiga por data.** "Parado há 6 semanas" não distingue abandono de obra-entregue-por-outra-rota. Ausência de sinal não é sinal.
2. Verifique **cada tag aberta contra o código, o banco e as migrations** — nunca por memória nem pelo texto do plano. Agentes de busca em paralelo tornam isso barato.
3. Trate número de migration citado em plano como **referência frágil**: confirme pelo **efeito** (tabela/coluna/flag existe? rota responde?), não pelo número.
4. O veredito útil tem três valores, não dois: **VIVA · FÓSSIL · PARCIAL**. Parcial é o caso comum — a maior parte entregue, um resto real.
5. Ao mover pro histórico, **feche a conta por soma de linhas** (antes = depois + movido ± cabeçalhos). Sem isso, "limpeza" e "perda silenciosa" são indistinguíveis.

**Ref:** tiatendo, 2026-07-20 — auditoria de 4 frentes: 221 linhas fósseis, mas **6 pendências eram reais**. Commit `65140c7`.

---

## Teste que nunca falhou embarca fóssil: o red importa mais que o green {#red-nunca-visto-embarca-fossil}

`tags: tdd, red green, teste nunca falhou, fixture fossil, guard de banco, dbSafety, skip silencioso, teste escrito depois, pg efemero, banco de teste, suite verde mentirosa`

**Sintoma:** a suíte passa localmente, o teste novo "está verde", e ao rodar contra banco real ele quebra em coisas bobas — nome de campo, coluna de ordenação, tipo de exceção.

**Causa raiz:** um guard de segurança (tipo `dbSafety`) **pula** os testes de banco quando não há banco de teste configurado. O teste novo nunca rodou — nem vermelho, nem verde. Ele foi escrito contra o *contrato imaginado* da função, e cada divergência do contrato real virou um fóssil embutido: `sale["order_id"]` quando o retorno tem `id`, `ORDER BY created_at` quando a coluna é `transitioned_at`, `pytest.raises(Exception)` onde o código lança um tipo específico.

**Solução:**
1. **Ver a falha vermelha é o passo, não a formalidade.** Teste que passou de primeira ou não testa nada, ou o comportamento já existia — pare e descubra qual dos dois.
2. Se o guard pula, **declare em voz alta** que o vermelho não foi visto e que o `[5-T]` depende do gate real. Não converta "não rodou" em "passou".
3. Rode o recorte da feature no **gate real** (pg efêmero, CI) antes de marcar entregue — é lá que os fósseis aparecem, em lote e baratos.
4. Vale também pro caminho inverso: **teste verde pode estar guardando bug**. Um teste chamado `..._still_requires` documentava como correta a regra que o operador reportou como defeito.

**Ref:** tiatendo, 2026-07-20 — 8 testes de anulação escritos sem red; o pg efêmero achou **3 fósseis** neles. Commit `356aec3`.

---

## `testIgnore`/`testMatch` de PROJETO substitui o do config raiz — não soma {#playwright-testignore-projeto-sobrescreve}

`tags: playwright, testIgnore, testMatch, projects, particao de suite, spec roda no projeto errado, suite mistura ruido, config raiz, override silencioso`

**Sintoma:** uma partição de suíte que estava funcionando volta a misturar specs: testes mobile/mockados rodam no projeto desktop e falham por motivo errado (viewport, dev server ausente), e a rodada mistura defeito real com ruído — exatamente o problema que a partição existia pra resolver.

**Causa raiz:** no Playwright, `testIgnore` (e `testMatch`) declarados **dentro de um `project`** *substituem* os declarados no nível do config — eles **não somam**. Adicionar um `testIgnore` novo no projeto (ex.: pra não rodar as specs públicas duas vezes) **anula em silêncio** a lista global. Nada avisa: a suíte simplesmente passa a rodar mais coisa, e como a maioria dos specs extras passa, o sintoma aparece só nos poucos que dependem de viewport/servidor.

**Solução:**
1. Extraia as listas pra **constantes nomeadas** e **concatene explicitamente** no projeto: `testIgnore: [...SPECS_COM_CONFIG_PROPRIA, ...SPECS_PUBLICAS]`.
2. Trave com contagem: `npx playwright test --list` e conte por projeto. Se o número subiu depois de mexer em partição, você anulou alguma lista.
3. Comente o porquê no config — é contraintuitivo o bastante pra ser refeito por quem vier depois.

**Ref:** Família Milionária, 2026-07-29 — o `testIgnore` do projeto `chromium` (adicionado 1 dia antes) anulou a lista de 11 specs com config própria; a rodada "4 failed" era 3 ruídos + 1 defeito. Commit `569e4c8`.

---

## Spec vermelha há semanas: o elemento não sumiu, a PÁGINA não abre (guard de perfil) {#spec-vermelha-rota-inacessivel-por-perfil}

`tags: e2e, spec vermelha, elemento nao encontrado, getByRole nao acha, guard de perfil, superadmin, redirect, storageState fabricado, laudo errado, rota protegida`

**Sintoma:** um spec e2e falha em `elemento não encontrado` e o laudo conclui "o botão foi removido no redesign". O botão **existe** no código-fonte. Semanas depois ninguém consertou, porque "a UI mudou" parece explicação suficiente.

**Causa raiz:** a rota tem **guard de perfil** (`if (user.perfil !== 'superadmin') router.replace('/dashboard')`). O elemento não é encontrado porque **a página nunca renderizou** — o teste já está em outra URL. Agrava: o setup de auth pode **fabricar** o perfil no `storageState` (`perfil: payload.perfil || 'superadmin'`), então o teste "deveria" passar — até o app buscar o perfil real no servidor e redirecionar. E o perfil exigido pode **não existir em nenhum usuário** do banco, deixando a rota inacessível pra todo mundo, inclusive em produção.

**Solução:**
1. **Antes de culpar o seletor, afirme a URL:** `await expect(page).toHaveURL(/\/rota/)` como primeira linha. Falha aí = problema de acesso, não de UI.
2. Cheque o **perfil real no banco** (`SELECT perfil FROM usuarios WHERE ...`) — não o fabricado no storageState.
3. Se a rota é inacessível por decisão de produto, **`test.describe.skip` com o motivo medido** (arquivo:linha do guard + o que o banco diz). Vermelho eterno ensina a suíte a ser ignorada.
4. Rota que exige um perfil que **ninguém tem** é achado de produto, não de teste — reporte.

**Ref:** Família Milionária, 2026-07-29 — `/fluxo-bot` e `/admin` exigem `superadmin`; o operador é `admin` e o banco de prod não tem nenhum superadmin. O laudo anterior dizia "o botão adicionar step não existe mais". Commit `569e4c8`.

---

## Hook fica lento e trava os commits: diretorio de estado que so cresce {#estado-append-only-trava-hook}

`tags: hook lento, pre-commit trava, pendura, timeout, commit lento, diretorio cresce, append only, marcador por timestamp, TTL, stat em N arquivos, ls -t, git bash windows, O(N), latest fixo, escrita atomica`

**Sintoma:** de repente o commit demora dezenas de segundos ou pendura, e nada no diff mudou de tamanho. Pode travar **todos** os commitS do projeto.

**Causa raiz:** um hook le o "mais recente" de um diretorio de estado fazendo `stat` em **todos** os arquivos (laco `-nt` ou `ls -t`/`Sort-Object LastWriteTime`). O produtor grava **um arquivo novo por evento** (ex.: `<timestamp>.jsonl`). O diretorio cresce sem limite; no git-bash do Windows cada `stat` e caro, e o custo do hook vira O(N) sobre milhares de arquivos. Os marcadores tinham TTL de minutos e zero valor depois -- puro acumulo.

**Solução:**
1. **O produtor grava sempre no MESMO path fixo** (`latest.jsonl`), sobrescrevendo. O leitor faz `stat` em **um** arquivo conhecido -- O(1), independente do historico. Alinha o custo com a pergunta ("existe estado recente?" e sobre 1 ponto, nao sobre N).
2. **Escrita atomica:** grave em `.tmp` e `mv -f`/`Move-Item -Force`. Sem isso o leitor pode pegar o arquivo no meio da escrita.
3. **Auto-poda no produtor:** ao gravar, remova os irmaos antigos. Assim pilhas legadas drenam sozinhas no proximo evento -- sem limpeza manual nem reinstalar N copias de hook.
4. **Corrija na fonte compartilhada, nao nas N copias.** Se o leitor e gerado por template (1 copia) e o produtor e 1 script, mude ali -- hooks por-projeto sao N lugares pra divergir. Depois da correcao do produtor + poda, as copias antigas ficam O(1) sozinhas (N=1).
5. **Meca antes de "otimizar".** Trocar o laco por `ls -t` teria economizado 10% (o custo era o `stat` em N, nao o laco) -- a medicao refutou a hipotese obvia.

**Ref:** canon Percus, hook R11 pre-commit, 2026-07-20. tiatendo chegou a **2026 marcadores** -> commit pendurava **148s** -> travou o projeto. Paid Midia (1399), Plexco Tasks (1123), Plexco Coach (844) estavam no mesmo caminho. Fix: `latest.jsonl` + escrita atomica + auto-poda no wrapper + leitura de path fixo no template/checks. Resultado: 148s -> **1,1s** (127x).

---

## Declarei hook/gate "instalado/consertado" checando a estrutura, nao RODANDO no cenario real {#verificar-runtime-nao-estrutura}

`tags: verificacao, evidencia observada, hook, gate, pre-commit, rodar nao olhar, runtime, env var ausente, fail-closed, dead code, estrutura vs comportamento, verification before completion, cenario real, shell sem env var`

**Sintoma:** voce instala/conserta um hook ou gate, confere que "esta la" e declara pronto. Numa sessao/maquina diferente ele nao roda -- ou como dead code (nunca executa), ou fail-closed travado (bloqueia tudo antes do check que importa). O defeito passa porque a verificacao foi ESTRUTURAL, nao de COMPORTAMENTO.

**Causa raiz:** "o arquivo tem o bloco certo" e "o script roda sozinho" NAO provam "o hook faz a coisa certa no commit real". Um hook depende do AMBIENTE de quando dispara: env var que nao propaga pra shell nova, `exit 0` de um bloco anterior que mata o codigo seguinte, cwd diferente, PATH diferente. Checar a estrutura e cego pra tudo isso.

**Solução:**
1. **Verifique RODANDO, no cenario de runtime real.** Pra hook de git: rode o proprio hook (`sh .git/hooks/pre-commit`), nao o script que ele chama. Reproduza a condicao adversa -- ex.: `env -u PERCUS_CANON_V2_DIR sh .git/hooks/pre-commit` (env var DESLIGADA), com um caso que DEVE passar e um que DEVE bloquear.
2. **Exija os DOIS sinais:** passa quando deve (nao trava por acidente) E bloqueia quando deve (com a mensagem certa -- "teto 150", nao "nao definida").
3. **"O script funciona" != "o hook roda no commit".** Rodar `percus-gate.sh` direto passando nao diz nada sobre o hook: o gate pode estar como dead code, ou o hook pode travar antes de chega-lo.
4. **Fallback pra estado de ambiente:** o que depende de env var deve ter fallback duravel (arquivo gravado na instalacao) -- env var e o modo mais fragil de passar estado, some entre shells.
5. E a regra `superpowers:verification-before-completion` / "evidencia observada, nunca assercao" aplicada a hook: a evidencia e a EXECUCAO no cenario real, nao a leitura do arquivo.

**Ref:** canon Percus, gate V2 no pre-commit, 2026-07-21. Declarei hooks "VIVO" checando a estrutura (gate alcancavel); rodei `percus-gate.sh` direto, nunca o hook num shell sem `PERCUS_CANON_V2_DIR`. Sessao fria rodou de verdade: hook fail-closed travado (bloqueava qualquer commit). 3a vez no mesmo dia que verificacao estrutural escondeu defeito de runtime. Fix real so veio ao rodar `env -u PERCUS_CANON_V2_DIR sh .git/hooks/pre-commit`.

---

## Cloudflare proxied (laranja) impede Traefik/Let's Encrypt de emitir cert {#cloudflare-proxy-quebra-acme}

`tags: cloudflare, proxy, laranja, orange cloud, dns only, cinza, traefik, lets encrypt, acme, certificado, tls, 403 unauthorized, well-known, acme-challenge, full strict, origin cert, dominio`

**Contexto:** dominio servido por Traefik + Let's Encrypt num VPS. O A record aponta certo pro VPS, o site funciona, cadeado verde no browser -- mas o Traefik loga falha de ACME em loop e nunca emite o cert.

**Causa raiz:** o registro esta **proxied (nuvem laranja)** no Cloudflare. O desafio ACME e' validado contra o IP que o DNS PUBLICO devolve, que sob proxy e' o do Cloudflare -- e o CF nao tem o token, entao responde **404**. O IP do CF aparece na propria mensagem de erro, e e' o que denuncia:
`invalid authorization: acme: error: 403 :: unauthorized :: 2606:4700:3036::6815:5069: Invalid response from https://DOMINIO/.well-known/acme-challenge/... : 404`

**Por que passa despercebido:** o site **funciona** -- o CF termina o TLS com cert proprio (emissor *Google Trust Services*) e encaminha pro origin. So olhando o cert do ORIGIN se ve o problema: fica em `TRAEFIK DEFAULT CERT` (auto-assinado). Funciona porque o CF esta em modo **"Full"**, que aceita cert invalido no origin. **Se alguem mudar pra "Full (strict)", o site cai na hora.** E o Traefik queima o limite do LE (5 falhas/h por hostname) em retry perpetuo.

**Solução:** para dominio servido por Traefik, o registro tem que ser **DNS-only (nuvem cinza)**. Apagar tambem os **AAAA** -- sobrando IPv6 do CF, cliente dual-stack continua caindo no destino antigo. Alternativa (se quiser manter o CF na frente): instalar um **Cloudflare Origin Certificate** no Traefik, ou trocar o desafio pra **DNS-01** com token de API do CF.

**Diagnostico em 10s** -- compare o emissor no publico e no origin:
```bash
echo | openssl s_client -connect DOMINIO:443 -servername DOMINIO 2>/dev/null | openssl x509 -noout -issuer
echo | openssl s_client -connect IP_DO_VPS:443 -servername DOMINIO 2>/dev/null | openssl x509 -noout -issuer
```
Ambos *Let's Encrypt* -> cinza, saudavel. Publico *Google Trust Services* + origin *TRAEFIK DEFAULT CERT* -> laranja, ACME quebrado.

**Ref:** Micro Investors, corte de dominio do F4 (2026-07-22). Os 3 subdominios irmaos ja eram cinza com LE; so apex e www estavam laranja. Desligar o laranja emitiu o cert em segundos e parou o churn. Familia de `#verificar-runtime-nao-estrutura`: o cert "existia" e era o errado.

---

## Canonical absoluto no layout do Next desindexa TODAS as rotas filhas {#next-canonical-layout-herdado}

`tags: next.js, app router, metadata, canonical, alternates, hreflang, seo, desindexacao, layout, heranca, openGraph, i18n, next-intl`

**Contexto:** portal Next (App Router) com varias rotas. Todas serviam `<link rel="canonical" href="https://dominio.com">` -- a RAIZ -- inclusive `/platform`, `/investors`, `/portfolio` e os equivalentes de outro locale. Efeito: cada rota diz ao Google que e' **duplicata da home**, e some do indice em favor de `/`.

**Causa raiz:** o `layout.tsx` declarava `alternates: { canonical: "https://dominio.com" }` como string ABSOLUTA. Metadata de layout no App Router e' **herdada** por toda pagina que nao sobrescreve -- e nenhuma pagina sobrescrevia. Mesmo defeito no `openGraph.url`. Como bonus, nenhuma rota emitia `hreflang`.

**Solução:** o layout NAO declara canonical (so `metadataBase`); cada pagina declara o seu no `generateMetadata`, via helper unico que tambem gera o `languages` (hreflang):
```ts
export const alternatesFor = (locale: string, path = "") => ({
  canonical: absoluteUrl(locale, path),
  languages: Object.fromEntries(routing.locales.map(l => [l, absoluteUrl(l, path)])),
});
```
Centralizar a regra de prefixo de locale num modulo so (`lib/seo.ts`): ela estava reimplementada em 3 lugares (sitemap, pagina de detalhe e implicitamente no layout), e foi essa dispersao que deixou o bug passar.

**Como verificar (o grep ingenuo mente):** o Next serializa o atributo como **`hrefLang`** (camelCase do JSX), entao `grep hreflang` case-sensitive da ZERO mesmo com a tag presente. Nome de atributo em HTML e' case-insensitive, entao esta correto -- use `grep -i`. Checar rota a rota:
```bash
for p in "" /platform /investors /pt/platform; do
  curl -s "https://DOMINIO$p" | grep -oiE '<link rel="canonical" href="[^"]*"'
done
```
Cada rota tem que devolver o canonical DELA, nao a raiz.

**Ref:** Micro Investors, `[5-T]` do F4 (2026-07-22) -- pego no smoke de SEO, dias depois de a pagina ir ao ar. Nenhuma review por-commit pegou: o layout estava "certo" isoladamente; o defeito so existe na HERANCA.

---

## Sessão de login "morre sozinha" em todos os produtos ao mesmo tempo {#sessao-morre-invalidacao-por-pessoa}

`tags: sessão expira, login não dura, logout sozinho, refresh token, family invalidation, invalidate_all_families_for_subject, re-OTP, cross-produto, sub canal:destino, custo OTP, SSO 15 minutos, rt no fragmento, allkeys-lru, maxmemory-policy`

**Contexto:** usuários de VÁRIOS produtos reclamam que não ficam logados — voltam no dia seguinte (às vezes em horas) e tomam OTP de novo. Cada time acha que é "coisa do meu app". O TTL do refresh está correto (ex.: 30 dias) e a rotação até desliza a janela, então "a conta fecha" no papel.

**Causa raiz (a que já aconteceu):** algum fluxo de login chamava uma primitiva de invalidação **chaveada pelo `sub`**. Em auth multi-produto o `sub` costuma ser `canal:destino` (`whatsapp:+55…`) — ou seja, **a PESSOA, não a audience**. Invalidar por `sub` num login apaga as famílias de refresh daquela pessoa em **todos os produtos**: um único login por magic-link em qualquer app derruba todos os outros, e o usuário entra num **loop de re-OTP cross-produto** (logou no A → caiu no B; logou no B → caiu no A). Com OTP pago (Cloud API), isso é custo direto por mensagem.

Agrava: era **intencional** (matar refresh token roubado) e estava **testado como correto** — o teste criava famílias em duas audiences e afirmava que ambas morriam. Ninguém tinha ligado aquele teste ao efeito no login.

**Como distinguir das outras causas (medir, não teorizar):** pegue o intervalo entre logins por identidade (ex.: `created_at` da tabela de OTP) e olhe a distribuição:
- mortes a ~TTL do access (minutos) ⇒ **o consumer não renova** — não guarda o `rt` ou não chama o refresh;
- mortes correlacionadas a login em OUTRO produto ⇒ **invalidação por pessoa** (este verbete);
- mortes aleatórias e em massa ⇒ **despejo no Redis** — cheque `CONFIG GET maxmemory-policy`; `allkeys-*` despeja token antes do TTL e o sintoma é idêntico.

**Solução:** login **nunca** destrói sessão. Roubo de token é tratado por rotação + reuse-detection (RFC 6749 §10.4), que é a defesa desenhada pra isso. Logout destrói **só o serviço que pediu** — não construa "logout-all": cross-produto reintroduz o bug sob demanda e vira vetor de DoS; "sair deste serviço" já é o revoke da família apresentada.

**Verifique também as OUTRAS portas de entrada.** No mesmo incidente, o hop de SSO devolvia só o access token (15 min) e nenhum refresh — sessão morta por construção, e ninguém tinha percebido porque o sintoma se confundia com o bug principal. Se um fluxo entrega token, ele tem que entregar o par.

**Trave com barreira estática (AST), não com teste comportamental.** Um teste da primitiva continua verde depois que você tira a chamada do router — ele não pega a reintrodução. Barre no **call-site** e, principalmente, no **import**: guardar só o nome deixa passar alias (`import x as _nuke`), `getattr` e `functools.partial`. Inclua as peças de um wipe artesanal (enumerar chaves do subject + deletar), senão a regressão volta sem citar a função óbvia. E prove a barreira **injetando a regressão e vendo falhar** — barreira que nunca ficou vermelha não vale nada.

**Ref:** auth-service, ADR-0015 (2026-07-23). Sintoma: nenhum dos 10 produtos mantinha login por 1 dia contra 30 planejados.

---

## Coluna usada como critério de ORDENAÇÃO/desempate que ninguém nunca escreveu {#coluna-ordenacao-nunca-escrita}

`tags: ORDER BY, desempate, tiebreak, coluna NULL, last_activity, comentario mente, spec nao implementada, criterio fantasma, NULLS LAST, ordenacao degenera, escolha nao-deterministica`

**Contexto:** existe um `ORDER BY <coluna> DESC NULLS LAST, <fallback>` decidindo algo que
importa (qual org/tenant/registro vence quando há mais de um candidato). O comentário ao lado
descreve a regra em prosa ("last-active wins"), a spec previa preencher a coluna, o model
declara, e há até teste afirmando que a coluna **existe**. Todo mundo cita a regra como fato —
inclusive em devolutiva pra outro time.

**Causa raiz:** **ninguém nunca escreveu a coluna.** A migração criou, a spec prometeu o
`UPDATE`, e o `UPDATE` nunca foi implementado. Com 100% NULL, o `NULLS LAST` joga todo mundo pro
fallback e a ordenação **degenera silenciosamente** no critério seguinte — normalmente
`created_at DESC`, que é "a linha criada por último vence, para sempre", sem relação nenhuma com
uso. O sistema tem um critério fantasma: documentado, testado na existência, morto no efeito.

**Como detectar em 10 segundos:** `grep` por quem faz `UPDATE ... SET <coluna>` / atribui o
campo. Zero ocorrências fora de migração/model/teste-de-existência ⇒ é fantasma. Depois confirme
no banco: `SELECT count(*) FILTER (WHERE <coluna> IS NOT NULL), count(*) FROM <tabela>`.

**Solução:** (a) implemente a escrita **ou** remova o degrau — mas não deixe os dois estados
conviverem; (b) garanta **ordem total** (último degrau único, tipo `id`), senão empate deixa a
decisão pra ordem física das linhas, que muda com `VACUUM`/restore; (c) **cuidado ao ligar a
escrita**: se o critério é auto-reforçado (grava no vencedor), ligar cimenta a primeira escolha
— só torne pegajosa a decisão que teve motivo, nunca a que saiu de empate, ou um bug reversível
vira grudado.

**Regra geral:** *ordenação por coluna só vale como fato depois de ver quem escreve nela.* Vale
para qualquer campo de "última atividade", "último acesso", `daily_time_local` e afins.

**Ref:** Plexco Tasks × Plexco Coach, ADR-0013 (2026-07-23). A coluna passou ~2 meses NULL
enquanto o comentário afirmava o contrário; o efeito real mandaria a tarefa do operador pra org
do cliente dele.

---

## Lookup por identificador "normalizado" só de um lado {#lookup-normaliza-so-um-lado}

`tags: match exato, telefone, E.164, DDI, formato armazenado, normalizacao, unknown_phone, drop silencioso, regexp_replace, canonicalizacao, dado legado`

**Contexto:** a borda canonicaliza o identificador que **chega** (telefone, CPF, e-mail, código)
e faz `WHERE coluna = :valor_canonico`. Funciona pra maioria e falha pra uma minoria sem
padrão — que some **sem erro**: nada logado como falha, nenhuma resposta ao usuário, só um
contador genérico de "não encontrado".

**Causa raiz:** a coluna **armazenada** nunca foi canonicalizada. Cadastro antigo, importação,
tela sem máscara e API externa depositaram convenções diferentes na mesma coluna (com `+`, sem
código do país, com pontuação). Canonicalizar só a entrada resolve metade do problema e esconde
a outra: a comparação é entre uma forma limpa e um campo sujo.

**Solução:** normalize **os dois lados** na comparação (ex.: `regexp_replace(col,'\D','','g')`)
e trate a canonicalização da coluna como **higiene**, não pré-requisito — assim o conserto não
fica bloqueado numa migração de dado. Se precisar de uma forma "curta" (sem prefixo/DDI) como
candidato, **guarde por validação de país/tipo**: remover `55` cegamente transforma o lookup num
coringa global (`679…` é Fiji, não DDD 67).

⚠️ **Ordem importa.** Tolerar formato faz linhas que hoje não casam passarem a casar: quem tinha
1 match passa a ter N. **Tenha a regra de desempate ANTES** — senão você troca um bug silencioso
(drop) por um intermitente (escolha que oscila), que é pior. Ver
[coluna de ordenação nunca escrita](#coluna-ordenacao-nunca-escrita).

**Ref:** Plexco Tasks, ADR-0013 (2026-07-23). 6 de 12 linhas de `users.phone` estavam fora do
canônico; o telefone do próprio operador nunca resolvia.

---

## SSH: "Server accepts key" e logo "Permission denied" {#ssh-key-passphrase-sem-agente}

`tags: ssh, permission denied, publickey, passphrase, ssh-agent, batchmode, rotacao de chave, deploy travado, automacao, chave revogada`

**Contexto:** depois de uma rotação de chaves, toda automação que fala com a VPS (ssh_runner,
deploy_v2, watchdogs locais) passa a falhar com `Permission denied (publickey,password)`.
Tentar a chave nova falha igual — o que induz a culpar a rotação no servidor.

**Causa raiz:** rode `ssh -v`. Se aparecer `Server accepts key: ... ED25519` **antes** do
`Permission denied`, a pública ESTÁ autorizada no servidor — o que falha é o cliente **provar
posse** da privada. Causa quase sempre: a chave nova foi gerada **com passphrase** e não há
ssh-agent carregado. Como toda automação usa `BatchMode=yes`, o ssh não pode pedir a senha e
falha calado. Confirme: `ssh-keygen -y -f <chave> -P ""` (erro = tem passphrase) e `ssh-add -l`
(`Could not open a connection...` = sem agente). Dica extra: chave ed25519 cifrada tem ~464
bytes; sem passphrase, ~411.

**Solução:** carregue no agente (`eval $(ssh-agent) && ssh-add <chave>`) ou, melhor, use o
agente do OpenSSH do Windows como **serviço** — persiste entre reboots e mantém a chave cifrada
em disco. Remover a passphrase (`ssh-keygen -p`) funciona mas desfaz metade do ganho da rotação.
E **não esqueça** de atualizar o `SSH_KEY_PATH` (ou `IdentityFile`) que a automação usa: apontar
pra chave revogada dá exatamente o mesmo erro por outro motivo.

**Ref:** Família Milionária, rotação de 2026-07-23 (travou deploy e acesso a prod).

---

## Lista destrutiva datada pelo campo de AUDITORIA em vez do de negócio {#lista-data-auditoria-vs-negocio}

`tags: listagem, desambiguacao, data errada, criado_em, created_at, parcelamento, exclusao, perda de dado, campo de auditoria`

**Contexto:** o bot lista N itens pro usuário escolher um número (pra excluir/corrigir) e todas
as linhas aparecem com a MESMA data, ficando indistinguíveis — mas no banco as datas estão
corretas e diferentes.

**Causa raiz:** o formatador exibe o campo de **auditoria** (`criado_em`/`created_at`) em vez do
campo de **negócio** (`data_prevista`/vencimento). Registros criados na mesma transação (parcelas
de um parcelamento, importação em lote) têm `criado_em` idêntico. O bug é **invisível** no caso
comum — item criado no mesmo dia a que se refere — e só aparece com data futura, retroativa ou
lote. Procure a classe, não o caso: costuma haver o mesmo trecho copiado em 2-3 telas.

**Solução:** exibir sempre o campo de negócio. Trate como severidade alta, não cosmético: se a
data é o único campo que distingue as linhas e o fluxo pede um número pra **apagar**, o usuário
escolhe às cegas dentro de uma ação destrutiva. Teste de regressão: crie 2+ registros na MESMA
transação com datas de negócio diferentes e afirme que ambas aparecem na saída.

**Ref:** Família Milionária `312cfd1` (3 sítios em `whatsapp/service.py`; parcelamento 5x saía
com as 5 parcelas na mesma data).

---

## Gate de commit (R11) trava com "invalid_request_error: deepseek-chat" {#deepseek-chat-modelo-descontinuado}

`tags: deepseek, deepseek-chat, deepseek-v4, invalid_request_error, modelo descontinuado, review, R11, gate de commit, hook pre-commit, percus-review, nao consigo commitar`

**Contexto:** o hook pre-commit (R11) exige um `/percus-review:review` fresco (<5 min) e bloqueia o
commit. Ao rodar o review (via bypass `deepseek-review.ps1` ou pela skill), a chamada à DeepSeek
falha com `{"error":{"message":"The supported API model names are deepseek-v4-pro or
deepseek-v4-flash, but you passed deepseek-chat.","type":"invalid_request_error"}}`. Sem review
que grave `latest.jsonl`, **nenhum commit passa** — trava todos os projetos Percus de uma vez.

**Causa raiz:** a DeepSeek **descontinuou o alias `deepseek-chat`** (e `deepseek-reasoner`). Os
scripts do plugin `percus-review` (ex.: `deepseek-review.ps1`, `review-router.ps1`) têm o modelo
antigo **hardcoded como default** (`[string]$Model = "deepseek-chat"`). Enquanto o default não for
atualizado, toda invocação quebra — inclusive a auto-invocada pelo gate.

**Solução:** passe o modelo novo na chamada — `deepseek-v4-flash` (barato, serve pra review de
docs/diff pequeno) ou `deepseek-v4-pro` (diffs grandes/sensíveis):

```powershell
& "...\percus-review\<versão>\scripts\deepseek-review.ps1" -Model deepseek-v4-flash
```

Isso regrava `.deepseek/reviews/latest.jsonl` e o hook libera o commit. **Fix definitivo (dono do
canon/plugin):** trocar o default `deepseek-chat` → `deepseek-v4-flash` em TODOS os scripts do
plugin (`deepseek-review.ps1`, `deepseek-impl.{ps1,sh}` do R13, `review-router.ps1`) e no
`.sh` equivalente. Enquanto não sai, o override por `-Model` é o desbloqueio.

**Ref:** Família Milionária, checkpoint de 2026-07-24 (o `deepseek-chat` funcionou às 18:56 de
07-23 e quebrou overnight). Plugin `percus-review` 6.29.0.

---

## Transição automática nova torna um status intermediário TRANSIENTE e mata todo leitor por igualdade {#status-intermediario-transiente}

`tags: status, state machine, transicao automatica, where status =, codigo morto, suite verde, mock esconde drift, notificacao, dispatch`

**Contexto:** tiatendo, frente "estações de preparo" (2026-07-23). O pedido passou a ir de `confirmed` pra `in_kitchen`/`ready` **dentro da mesma transação** da confirmação. Nenhum pedido descansa mais em `confirmed`. Três leitores que perguntavam `status = 'confirmed'` viraram código morto **em silêncio**, com a suíte 100% verde: o sino de "novo pedido" do dashboard ficaria mudo pra sempre em todo tenant, e o comprovante Pix validado deixava o pedido como pendente no caixa (risco de cobrar de novo na entrega).

**Causa raiz:** inserir uma transição automática **remove um estado de repouso** do sistema, mas ninguém audita quem lia aquele estado. Sobrevivem só os leitores que usam *conjunto* de status (`IN (...)`, `NOT IN (...)`); morrem os que usam **igualdade**. E os testes não pegam porque tipicamente mockam o status antigo ou testam a função pura, nunca a query.

**Solução:** ao introduzir qualquer transição automática, faça um grep do estado que deixou de ser terminal (`= 'X'`, `== "X"`) em TODO o código — incluindo notificações, KPIs, relatórios e crons — antes de fechar a frente. Prefira perguntar pelo **fato** (`confirmed_at IS NOT NULL`) e não pelo **estado** (`status = 'confirmed'`). Desconfie de teste cujo mock devolve status fixo: ele passa exatamente quando a produção quebra.

**Ref:** tiatendo PROD `0.244.0`, ADR-0013; memória de projeto `feedback-confirmed-virou-status-transiente`.

---

## Cliente que "degrada gracioso" engole erro de credencial — log limpo não é prova {#degrade-gracioso-esconde-noauth}

`tags: redis, noauth, credencial, senha, degrade gracioso, fallback, silencioso, except exception, rotacao, verificar in-process, compose hardcoded`

**Contexto:** o Redis do tiatendo passou a exigir senha (2026-07-23). O relato de que "não há erro de autenticação nos logs" foi apresentado como prova de que a credencial estava certa — mas o cliente **nunca logaria** esse erro.

**Causa raiz:** `getRedis()` tem `except Exception: return None` **de propósito** (permitir deploy single-node sem Redis). Consequência não pretendida: URL sem senha, senha errada ou host errado devolvem `None` sem uma linha de log, e a aplicação cai em primitivas in-process — lock, dedup e rate-limit distribuídos **deixam de existir em silêncio**. Pior: o `docker-compose.yml` do repo ainda tinha a URL sem senha hardcoded, então um `docker stack deploy` reverteria a credencial e degradaria tudo sem avisar.

**Solução:** (1) depois de qualquer rotação/redeploy, verifique **in-process** dentro do container (`getRedis()` devolve cliente ou `None`?), nunca pelo log; (2) no compose, exija a variável (`${REDIS_URL:?}`) pra falhar cedo em vez de silenciosamente; (3) ao escrever um cliente com degrade gracioso, **separe** "não configurado" (silêncio ok) de "configurado e falhou" (tem que alarmar).

**Ref:** tiatendo `0.244.0`; memória de projeto `feedback-redis-noauth-degrada-em-silencio`.

**2ª instância (Família Milionária, 2026-07-24) — o `environment:` do stack VENCE o `env_file`.** A rotação de 23/07 atualizou postgres/redis/GOWA + o `.env` (local e prod), mas o `docker-stack.yml` fixa `DATABASE_URL`/`REDIS_URL` num bloco `environment:` que **sobrepõe** o `env_file: .env` — então rotacionar só o `.env` **não chega no container**. Dois agravantes: (a) o `deploy_v2.py` faz `tar` da pasta e shipa o stack file **LOCAL** por cima da VPS (só depois faz `sed` do image tag), e esse stack file é **gitignored** (invisível no `git status`); (b) sintoma traiçoeiro — a API fica `healthy`/`db:ok` porque o container **vive de conexões abertas de ANTES da rotação** (o Postgres não re-autentica conexão viva), e só quebra num **restart** (`asyncpg InvalidPasswordError`), enquanto o GOWA_WEBHOOK_SECRET velho **mata o inbound do bot em silêncio** (HMAC fail-closed). **Não adivinhe qual valor é o vivo pela aparência** — teste: `psql`/`redis-cli`/`curl` com cada credencial, e pro webhook compare o **comprimento** com o que o servidor que ASSINA usa (aqui o vivo era o valor "novo", mas às vezes o "velho" é que é o certo). Fix = alinhar `.env` **E** stack file (local **e** VPS), depois `docker stack deploy`. Melhoria pendente: uma fonte só (remover do `environment:` → cair no `env_file`, ou docker secrets). Memória FM `gotcha_stack_file_hardcoda_creds_sobrepoe_envfile`.

---

## Tirar um produto do superusuário do Postgres (least-privilege) num cluster compartilhado {#least-privilege-cluster-compartilhado}

tags: postgres, superuser, superusuario, least-privilege, rls, row-level-security, grant, role, alembic, ddl, cluster-compartilhado, blast-radius, sqli

**Contexto:** auditoria aponta que a aplicação conecta como `postgres` (superusuário) e que "N tabelas com RLS não estão sendo aplicadas". Antes de agir, MEÇA — a premissa costuma estar meio errada, e a parte errada é a alarmante.

**Causa raiz / achados que recorrem:**
- **RLS habilitado ≠ política existe.** `relrowsecurity=t` numa tabela só diz que o RLS está ligado; `SELECT count(*) FROM pg_policies` é quem diz se HÁ política. Ligado sem política = *deny-all* pra quem não é dono/super (e grant não vence RLS). Rode as duas queries: as tabelas "com RLS" podem ser todas de um schema morto (ex.: `auth` do GoTrue) sem política nenhuma.
- **O risco real do superusuário num cluster compartilhado é BLAST RADIUS, não RLS.** Um SQLi na app conectada como `postgres` alcança os N bancos do cluster (inclusive o de auth de outros produtos), não só as tabelas do produto.
- **Role só-DML quebra o Alembic.** O migrator precisa de DDL; separe `<prod>_app` (DML, pool 24/7) de `<prod>_migrator` (dono do schema, só migrations via `docker exec --env-file` — caminho do HOST, não vaza senha nos args).
- **`ALTER DEFAULT PRIVILEGES` exige `FOR ROLE <migrator> IN SCHEMA public`** conectado ao banco certo, e cobre 4 classes: TABLES/SEQUENCES/FUNCTIONS/TYPES (esqueça TYPES e migration com enum novo nasce inacessível).
- **`REASSIGN OWNED` é proibido em cluster compartilhado** (alcança objetos de outros bancos). Transfira posse por bloco `DO` escopado a `schemaname='public'`.
- **Sequence serial-PK não troca de dono isolada** (`ALTER TABLE seq OWNER` → "linked to table"); ela segue a tabela. Exclua `relkind='S'` do loop de ownership.
- **Enums precisam ir pro migrator** (`ALTER TYPE ... ADD VALUE` em migration futura falha se ele não for dono).
- **`GRANT CONNECT ON DATABASE` usa nome LITERAL** → num script que roda em clone E prod, parametrize o dbname (`-v dbname=... :"dbname"`), senão o grant vaza pro banco errado. `CREATE ROLE` é cluster-global: limpe as roles de ensaio (`REVOKE`/`DROP OWNED`/`DROP ROLE`).
- **A suíte pytest não roda como a app-role** se o `conftest` faz `DROP SCHEMA public` (trabalho de owner). Cubra "app precisa de algo além de DML?" por varredura estática do runtime (advisory-lock/TEMP/nextval passam pra qualquer role) + provas de conexão como a role.

**Solução:** ensaie num CLONE fiel (não no banco `_test` defasado), com sonda de grants em 5 camadas (`has_database_privilege` CONNECT → `has_schema_privilege` USAGE → `has_table_privilege` × verbos × tabelas → `has_sequence_privilege` → prova NEGATIVA conectando como a role: sem CREATE, sem BYPASSRLS, dona de 0 objetos). Cutover = trocar `DATABASE_URL` do serviço por `--env-add` (rollback em segundos). Modo de falha é BARULHENTO (`permission denied` no log, não listagem vazia) porque não há política RLS filtrando.

**Variante mais simples (1 role só, sem migrator separado):** se as migrations do produto rodam **como `postgres`** (não como uma role própria), o app-role pode ser DML-only e você NÃO precisa de `_migrator` nem de `FOR ROLE` no `ALTER DEFAULT PRIVILEGES` — o default privilege da role que cria (o próprio `postgres`) já cobre as tabelas futuras. Trade-off: o migrator segue sendo superusuário (blast-radius do migrator não some; aceitável quando o objetivo é tirar o superusuário do **caminho de 100% do tráfego**, que é o app). O gotcha de **TYPES/FUNCTIONS continua valendo mesmo nessa variante**: hoje o default do `PUBLIC` cobre EXECUTE/USAGE, mas num cluster com sweeps de least-privilege o `PUBLIC` pode ser revogado → adicione `GRANT EXECUTE ON ALL FUNCTIONS` + `ALTER DEFAULT PRIVILEGES … EXECUTE ON FUNCTIONS` + `… USAGE ON TYPES` upfront (a varredura de `count(*)` NÃO pega isso; só o `[5-T]` no runtime pegaria).

**Ref:** Plexco Tasks s147 (2026-07-23); `Plexco Tasks/docs/superpowers/specs|plans/2026-07-23-least-privilege-*` + `docs/deploy/2026-07-23-least-privilege-cutover-runbook.md`; memórias `reference_least_privilege_ensaio_gotchas`, `reference_rls_alarme_falso_auth_gotrue_lixo`. **2ª instância (variante 1-role):** Micro Investors, épico "sair de superusuário" 2026-07-23/24 — `Micro Investors/docs/superpowers/plans/2026-07-23-rls-superusuario.md` (migration 00045 desliga RLS legacy inerte; role `mi_v2_app` DML-only, `postgres` segue migrator; blindagem TYPES/FUNCTIONS aplicada).

---

## "SSH quebrou" depois de rotacionar chaves no Windows — mas a chave está OK, é o `ssh` errado {#ssh-automacao-git-bash-vs-agente-windows}

tags: ssh, rotacao de chaves, permission denied, publickey, ssh-agent, windows, git bash, msys2, named pipe, batchmode, automacao, deploy, ssh_runner, passphrase, subprocess

**Contexto:** rotação de chaves SSH (novas com passphrase, antigas revogadas). A automação (`ssh_runner`, deploy scripts) passa a dar `Permission denied (publickey)` mesmo depois de subir o `ssh-agent` e carregar a chave. O `ssh` cru pelo PowerShell conecta; o MESMO script pelo Git Bash falha — sintoma idêntico ao de chave não-autorizada, o que joga o diagnóstico pra "a rotação quebrou a chave".

**Causa raiz:** duas coisas distintas confundidas numa só. (1) A chave precisa do **ssh-agent do Windows como serviço** com a chave carregada (`ssh-add -l`), senão `BatchMode=yes` não tem como provar posse da privada com passphrase. (2) Mesmo com o agente OK, automação lançada pelo **Git Bash** resolve `ssh` pro **MSYS2 `/usr/bin/ssh`** (vem antes no PATH — cheque `which -a ssh`), que **NÃO fala com o agente do Windows** (o agente expõe um named pipe; o MSYS2 espera um socket unix) → cai só na chave em disco, que tem passphrase, e com BatchMode falha silenciosamente.

**Solução:** (a) agente do OpenSSH do Windows como serviço + `ssh-add` uma vez (persiste entre reboots, chave segue cifrada em disco); (b) no código de automação **pine o binário**: no Windows use `C:\Windows\System32\OpenSSH\ssh.exe` (agente-aware) em vez de `ssh` puro, independente do shell que lançou — `subprocess` resolve pelo PATH herdado, que muda entre Git Bash e PowerShell. Verifique do **shell em que a automação REALMENTE roda**, não do PowerShell interativo. Bônus: `subprocess` não expande `~` — passe `os.path.expanduser` no caminho da chave (o default do `os.getenv` já vem expandido, o valor do env NÃO).

**Ref:** Família Milionária 2026-07-24; `execution/ssh_runner.py` (`_sshBin()`), `deploy_v2.py`, `deploy_frontend_v2.py`; memória `project_snapshot_2026_07_23_ssh_rotacao_quebrou_automacao`.

---

## Log de diagnóstico "no ar" que nunca emitiu: sob uvicorn o root logger é mudo {#uvicorn-root-logger-mudo}

tags: logging, uvicorn, fastapi, root logger, lastResort, log.info sumiu, observabilidade, sonda, diagnostico, pii, mascara, httpx, ast, grep multi-linha

**Contexto:** shipamos uma sonda (`log.info` com as chaves de um payload) pra responder uma pergunta de contrato cross-product. Dois dias em prod, tráfego chegando (202 no access-log), e **zero linha da sonda**. O HANDOFF registrava "viva mas sem dado — só produz quando alguém responder", e a sessão seguinte ia esperar mais. Vale pra qualquer serviço FastAPI+uvicorn do kit.

**Causa raiz:** o uvicorn configura **só** os loggers `uvicorn`, `uvicorn.error` e `uvicorn.access`. O **root ele não toca** — fica em `WARNING` com `handlers = []`. Como todo módulo usa `logging.getLogger(__name__)` (level `NOTSET`, herda o root), **todo `log.info` da aplicação é descartado**. No projeto eram **98 chamadas** invisíveis, não só a sonda. O que engana é que o log de prod *parece* saudável: aparecem o access-log do uvicorn e os `WARNING`+ da app — mas estes últimos saem pelo `logging.lastResort` (stderr), não por handler configurado. Ou seja, "tem log" não é prova de que o SEU log existe.

**Solução:** (a) **verifique RODANDO, não lendo** — `docker exec $CID python -c "import logging,logging.config; from uvicorn.config import LOGGING_CONFIG; logging.config.dictConfig(LOGGING_CONFIG); import app.main; lg=logging.getLogger('app.x.y'); print(logging.getLevelName(lg.getEffectiveLevel()), logging.getLogger().handlers, lg.isEnabledFor(logging.INFO))"` — `WARNING [] False` denuncia; (b) um `logging_setup.setup_logging()` chamado no **import do `main`** (roda depois do `dictConfig` do uvicorn, que acontece antes de importar a app) somando handler no root, com level via env.

⚠️ **Duas armadilhas DENTRO do fix**, que precisam ser tratadas junto senão ele cria problema pior:

1. **Ligar INFO no root liga as libs junto.** O `httpx` emite `HTTP Request: GET <url>` por chamada — e se algum client manda dado pessoal em **query param** (no nosso caso telefone em `/user/info?phone=…`), o fix repõe no log exatamente o PII que a máscara tira. Trave `httpx`/`httpcore` em `max(nivel, WARNING)`. Confira também volume: `log.info` dentro de loop de worker sem guarda inunda.
2. **Varredura de PII tem que ser AST, não `grep`.** `grep` de uma linha não enxerga chamada de log quebrada em várias linhas — foi assim que 6 vazamentos (5 de e-mail) passaram batido numa varredura manual, e só apareceram ao trocar por `ast.walk` sobre as chamadas `log.*`. Vire teste, não checklist. E ao aplicar máscara em massa, **conte as ocorrências antes**: num arquivo nosso havia 5 `"phone": phone` e só 4 eram log — a 5ª era o envelope mandado a outro produto, contrato congelado. Substituição cega por string teria quebrado o consumidor calado.

**Ref:** Plexco Tasks s149 (2026-07-25); `backend/app/logging_setup.py`, `backend/app/utils/log_redact.py`, `backend/tests/test_log_sem_pii.py`; memória `reference_uvicorn_nao_configura_root_logger`. Parente de [#verificar-runtime-nao-estrutura](#verificar-runtime-nao-estrutura) e [#red-nunca-visto-embarca-fossil](#red-nunca-visto-embarca-fossil) — o teste da sonda passava porque logava `sorted(keys)` e teria passado com qualquer nome de chave.

---


---

<a id="fail-open-esconde-import-errado"></a>
## Guard `try/except` fail-open esconde import errado: a feature vira no-op silencioso {#fail-open-esconde-import-errado}

tags: fail-open, try except, import errado, no-op silencioso, review cross-provider, teste de wiring, migration aplicada, testes verdes

**Contexto:** salvaguarda nova, plugada num caminho crítico (gate que não pode quebrar). Envolvi a chamada num `try/except` fail-open — correto em si: uma falha ali não podia impedir de salvar a mensagem do cliente. Só que o import dentro da função apontava pra um caminho **inexistente** (`execution.integrations.whatsappNotifier` em vez de `execution.notifications`).

**Causa raiz:** o `ModuleNotFoundError` estourava no **import**, antes de qualquer lógica, e o fail-open engolia com um `logger.warning`. Resultado: **100% das execuções viravam no-op**, com migration aplicada, suíte verde (4729 testes) e deploy "saudável". A feature inteira não existia em produção e nada denunciava. Os testes cobriam só a função PURA de decisão — nunca o wiring.

**Solução:** (a) todo caminho protegido por fail-open precisa de **um teste que chame a função de verdade** (monkeypatch só nas bordas de I/O) — é o único que pega import/NameError; no nosso caso esse teste pegou, além do import, um `NameError` de módulo fora de escopo; (b) **review cross-provider antes do commit** achou o import — verificação por leitura de outro modelo pega o que o próprio autor não vê; (c) se o fail-open engolir algo que já consumiu estado (contador, flag), logue **ERROR**, não `warning`.

⚠️ **Corolário medido:** perda silenciosa também acontece no envio. No smoke em prod o WhatsApp rejeitou o alerta (`429 WA_REACHOUT_TIMELOCK`) **depois** do contador já commitado → aquele aviso se perderia pra sempre. Fix: consumir o contador, e **devolver** (UPDATE condicional) se o envio retornar falso. Assimetria proposital: alerta repetido ao operador é inofensivo, mensagem repetida ao cliente é spam.

**Ref:** tiatendo `0.249.0`/`0.250.0` (2026-07-25); `execution/core/messageRouter.py::_handoffNudge`, `tests/restaurant/test_handoffNudge.py`. Parente de [#verificar-runtime-nao-estrutura](#verificar-runtime-nao-estrutura) e [#red-nunca-visto-embarca-fossil](#red-nunca-visto-embarca-fossil).

---

<a id="handoff-mudo-sem-salvaguarda"></a>
## Conversa escalada pra humano fica MUDA e ninguém percebe (54 msgs em 34 min) {#handoff-mudo-sem-salvaguarda}

tags: handoff, bot_paused, escalonamento, atendente, reaper, virada de dia, cliente orfao, alerta unico, anti-spam whatsapp

**Contexto:** bot escala pra atendente e **cala** naquela conversa (gate salva a mensagem e retorna). O reaper devolvia ao bot só na **virada do dia**. Medido em prod: **54 mensagens do cliente em 34 minutos**, zero resposta, zero sinal novo. O único aviso foi o do instante da pausa — se o operador não vê aquele, o cliente fica órfão por até ~24h. **Foi o operador que percebeu, olhando o WhatsApp**, não o sistema.

**Causa raiz:** "escalei" foi modelado como estado terminal esperando ação humana, sem nenhum caminho de volta dentro do dia e sem reincidência de aviso. Um único alerta é um **evento**, não um **lembrete**: some no meio das notificações.

**Solução (padrão reaproveitável):** três camadas, com estado por conversa e **por EPISÓDIO** de handoff:
1. **Cliente:** UMA resposta automática na 1ª mensagem durante a pausa ("já chamei um atendente"). Nunca mais que uma.
2. **Operador:** re-alertas em marcos de tempo (5 e 10 min), **só se o cliente continuar mandando**, com teto duro.
3. **TTL de retorno** ao bot (não só virada de dia), **só se nenhum humano respondeu** — senão o bot fala por cima do atendente.

⚠️ **Duas armadilhas:** (a) os contadores têm que zerar em **TODOS** os caminhos que despausam — não só no helper "oficial": no nosso caso 4 dos 5 eram `UPDATE` cru em rotas do painel, e sem o reset um **segundo** handoff da mesma conversa nasceria "já avisado" e ficaria mudo de novo; (b) devolver ao bot sem **saída** re-escala pelo mesmo motivo → ping-pong; guarde o MOTIVO do handoff e ofereça alternativa (ex.: fora-de-área → oferecer retirada).

**Ref:** tiatendo mig 104, `execution/engine/handoffNudge.py`, `execution/engine/handoffCleanup.py` (2026-07-25).

<a id="fixture-uniforme-esconde-irregular"></a>
## Feature vira no-op DETERMINÍSTICO num caso comum e a suíte inteira fica verde {#fixture-uniforme-esconde-irregular}

tags: fixture uniforme, caso irregular, dia fechado, feriado, no-op semanal, cobertura falsa, business hours, lookback curto, folga semanal

**Sintoma:** feature nova, TDD com RED provado em cada teste, ~100 testes verdes incluindo banco real. Em produção ela simplesmente **não roda** — não com erro, sem rodar — num caso que é o MAIS COMUM do domínio. No caso medido: rotina diária que dependia de "achar o último fechamento olhando 1 dia pra trás". No tenant que **fecha na segunda** (o padrão de quase todo restaurante), a terça de manhã não achava fechamento nenhum, a função devolvia `None`, o caller abortava — e a rotina morria **toda semana**, em silêncio.

**Causa raiz:** **todo fixture tinha os 7 dias da semana preenchidos e iguais.** Um fixture uniforme não é "um caso de teste": é uma AFIRMAÇÃO de que a irregularidade do domínio não existe. Com dados regulares o teste prova só o caminho regular — e a sensação de cobertura (100 verdes) impede de procurar mais. Some-se um limiar de busca curto ("olho 1 dia pra trás") calibrado no caso regular, e o resultado é no-op onde ninguém olha.

**Solução:**
1. Antes de dar a feature por coberta, pergunte **"qual é a IRREGULARIDADE deste domínio?"** e escreva um fixture que a contenha: dia da semana vazio, data marcada como exceção/feriado, item sem o campo opcional, tenant sem a config, mês de 28 dias, turno partido.
2. Quando um helper varre "N períodos pra trás", **N tem que cobrir a maior lacuna plausível** (folga semanal + feriado emendado), e a varredura tem que **pular as exceções** (lista de datas fechadas), senão ela inventa um período que nunca existiu.
3. Se a função pode devolver "não achei", **logue WARNING nesse caminho** — um no-op mudo é indistinguível de "não havia nada a fazer".
4. Quem achou isto foi **review cross-provider reproduzindo por execução**, não lendo. Peça ao revisor pra TENTAR QUEBRAR com dados reais do domínio, não pra opinar sobre o código.

**Ref:** tiatendo `0.251.0` / Frente B reset noturno (2026-07-26); `execution/plugins/restaurant/nightlyReset.py::_lastEndedWindow`, `tests/test_nightlyResetWindows.py`. Parente de [#red-nunca-visto-embarca-fossil](#red-nunca-visto-embarca-fossil) e [#verificar-runtime-nao-estrutura](#verificar-runtime-nao-estrutura).

---

<a id="guarda-redundante-tesoura-ou-morta"></a>
## "Cinto de segurança" extra CORTA o caso legítimo — e alargá-lo vira guarda morta {#guarda-redundante-tesoura-ou-morta}

tags: guarda redundante, defensive programming, limiar, teto, janela temporal, codigo morto, falsa protecao, cap

**Sintoma:** você adiciona um limite defensivo "a mais" (teto de tempo, cap de tamanho, janela máxima) além da proteção que já existe. Ele passa a **descartar em silêncio** casos válidos. Ao perceber, o reflexo é alargar o limite — e aí ele nunca mais dispara, virando código que **lê como proteção e não protege nada**.

**Caso medido:** teto de 48h numa janela de "quem convidar de manhã". O tenant que fecha **dois dias seguidos** (dom+seg) reabre com o último fechamento 60h atrás → o teto empurrava o corte pra depois do evento, e aqueles clientes **nunca** eram convidados (o corte só anda pra frente). Alargar pra 8 dias consertou o corte e criou o problema oposto: a busca já era estruturalmente limitada a 8 dias, então o `max()` passou a nunca ativar.

**Causa raiz:** limiar defensivo só vale se você souber **qual é o maior caso legítimo em números**. Abaixo dele é tesoura; acima do limite estrutural que já existe, é decoração. E a falha da tesoura é **silenciosa** — não há erro, só ausência.

**Solução:**
1. Escreva em números o **maior caso legítimo** ("folga de 2 dias = 60h") e o **limite que o sistema já impõe**. Se a guarda nova não fica ESTRITAMENTE entre os dois, não escreva: ela é tesoura ou é morta.
2. Prefira proteção **exata** a proteção **temporal**: no caso medido, o que resolveu de verdade foi um **backfill na migration** carimbando todo o histórico como "já tratado" — sem raio pra errar. Coluna nova nasce `NULL`, e `NULL` costuma significar "elegível": carimbe o passado na própria migration.
3. **Toda guarda precisa de um teste que a veja DISPARAR.** Guarda que nenhum teste consegue ativar é código morto disfarçado — remova ou substitua.

**Ref:** tiatendo `0.251.0` (2026-07-26); `execution/core/backgroundRunner.py::_processTenantMorningQueue`, `execution/database/migrations/105_nightly_reset.sql`.

---

<a id="down-migration-view-select-star"></a>
## `DROP COLUMN` no rollback falha: uma view `SELECT *` depende da coluna nova {#down-migration-view-select-star}

tags: migration down, rollback, drop column, view depends on column, select star, cascade, orders_real, downgrade nao testado

**Sintoma:** o `up` da migration aplica limpo, mas o `down` estoura: `ERROR: cannot drop column X of table T because other objects depend on it / DETAIL: view V depends on column X`. Só aparece se você **rodar o down de verdade** — quem só lê o SQL não vê.

**Causa raiz:** views criadas como `SELECT * FROM tabela` **congelam as colunas na criação**, mas se a view for recriada (`CREATE OR REPLACE`) em algum momento DEPOIS de a coluna existir, ela passa a depender dela. Aí o `DROP COLUMN` seco fica bloqueado. A dependência depende da ORDEM histórica das migrations naquele banco — então pode falhar em prod e passar num banco fresco (ou o contrário).

**Solução:** no `down`, **derrubar a view, tirar a coluna e RECRIAR a view** com a definição da migration que é a fonte dela. ⚠️ **Nunca `DROP COLUMN ... CASCADE`**: "resolve" o erro e deixa o banco SEM a view — quebra consultas dependentes muito depois, longe da causa. Prove o ciclo completo em banco efêmero: **fresh → up → down → up → up** (a última repetição prova idempotência).

**Ref:** tiatendo mig 105 vs view `orders_real` (2026-07-26); `execution/database/migrations/105_nightly_reset_down.sql`. Parente de [#migration-numero-reciclado](#migration-numero-reciclado).

---

---

<a id="janela-reintroduz-vies-sobrevivencia"></a>
## Relatório com JANELA de período re-introduz viés de sobrevivência que você "já consertou" {#janela-reintroduz-vies-sobrevivencia}

tags: relatorio, janela, periodo, vies de sobrevivencia, dado censurado, media, mediana, gargalo, badge, etapa terminal, permanencia aberta, funil, cycle time

**Contexto:** relatório de "tempo médio parado por etapa". O viés de sobrevivência estava
identificado e tratado no plano: a média TEM que incluir as permanências **abertas** (`agora −
entrada`), senão quem ainda está parado — justamente o lento — fica fora e a etapa mais travada
aparece como a mais saudável.

**Causa raiz:** o plano definia a amostra como "o que ENTROU na janela". Isso conserta o viés
*dentro* da janela e o reintroduz *pela borda*: a tarefa parada há 60 dias **não entrou** numa
janela de 30 dias e **não saiu** (nunca saiu) — some do relatório inteiro. O pior caso vira
invisível justamente por ser o pior caso. Duas naturezas de bug moram aqui: o filtro que parecia
neutro (a janela) carrega a mesma assimetria que você acabou de remover do cálculo.

**Solução:** a base da média é `encerrou na janela` **∪** `segue aberta agora` — independente de
quando começou —, medindo a permanência INTEIRA (nunca a fatia dentro da janela). Corolários:
- **Declare a base de contagem de CADA campo** no docstring e na própria tela. Campos com bases
  diferentes (entrada por data de entrada, saída por data de saída) não se somam, e quem somar vai
  concluir que a tela está quebrada. Vale `amostra == saiu + ainda_aqui`; **não** vale
  `entrou == saiu + ainda_aqui`.
- **Taxa é fração da MESMA base do numerador.** `count/entrou` passa de 1 quando a etapa esvazia
  mais do que recebeu no período; `count/saiu` é limitada a 1 por construção.
- ⚠️ **Categoria TERMINAL não tem "tempo parado"** e envenena a mediana de comparação nos dois
  sentidos: recém-alimentada (média ~0) derruba a base e acusa de gargalo quem está só um pouco
  acima; envelhecida, absolve todo mundo. Tire-a da base **e** do diagnóstico.
- **Prove cada guarda por MUTAÇÃO:** reintroduza o bug e confirme que o teste específico fica
  vermelho com a mensagem certa. Foi assim que apareceu um teste que passava por **coincidência
  aritmética** (2,99 dias contra um corte de 3,0) — verde não prova que ele testa algo.

**Ref:** Plexco Tasks s150 (2026-07-26), `backend/app/services/stage_funnel.py` (as 6 armadilhas
no docstring), `backend/tests/test_stage_funnel.py`. Parente de
[#red-nunca-visto-embarca-fossil](#red-nunca-visto-embarca-fossil).

---

<a id="build-dir-compartilhado-tag-nova"></a>
## Deploy sobe código VELHO com tag NOVA: diretório de build compartilhado entre serviços {#build-dir-compartilhado-tag-nova}

tags: deploy, build on vps, docker, tag unica, git archive, diretorio compartilhado, codigo velho, rollout falso, frontend backend

**Sintoma:** você commita o fix, roda o deploy, a tag é nova, o `service update` converge, o
container fica `Running` — e **o defeito continua na tela**. Nada no output indica erro.

**Causa raiz:** o diretório de build na máquina remota (`/opt/<projeto>-build`) é **compartilhado
pelos deploys de todos os serviços** e fica na revisão de **quem arquivou por último**. O script de
um serviço fazia `git archive origin/master` antes de buildar; o do outro só entrava no diretório e
buildava. Deployar o segundo depois de um commit novo empacota a árvore ANTIGA com uma tag NOVA —
todos os sinais de sucesso presentes, conteúdo errado.

**Solução:** **re-arquivar dentro de cada script de deploy**, sem exceção, e **imprimir a revisão
empacotada** (`git rev-parse --short origin/master`) pra ela aparecer no log ao lado da tag. Tag
única não protege disto: ela prova que a IMAGEM é nova, não que o CÓDIGO é. Ao verificar um deploy,
compare o que está na tela com o COMMIT, não com a tag.

**Ref:** Plexco Tasks s150 (2026-07-26) — o frontend saiu 2x no commit errado antes de eu perceber.
Parente de [#verificar-runtime-nao-estrutura](#verificar-runtime-nao-estrutura).

---

<a id="aspa-simples-ssh-bash-c"></a>
## Args com aspa simples atravessando `ssh` + `bash -c` selecionam a coisa ERRADA, sem erro {#aspa-simples-ssh-bash-c}

tags: ssh, bash -c, aspas, quoting, pytest -k, selecao de testes, falso verde, paramiko, payload

**Sintoma:** `-k 'a or b'` (ou qualquer arg com aspa simples) enviado por SSH dentro de
`bash -c '...'` roda **sem erro** e reporta "1 passed" — mas selecionou testes que você não pediu, ou
nenhum dos que importavam. Você lê o verde e acha que provou algo.

**Causa raiz:** a aspa simples do arg **fecha o wrapper** `bash -c '...'`. O que sobra é reparseado
como argumentos soltos, e ferramentas como o pytest aceitam argumentos a mais sem reclamar.

**Solução:** escapar no padrão POSIX antes de montar o comando —
`args.replace("'", "'''")` — ou não passar payload por `bash -c` (subir um script por SFTP e
executá-lo). E ao ler o resultado de uma execução filtrada, **confira o número de testes
selecionados/deselecionados**, não só o "passed": foi a contagem que não fechava (2 selecionados
onde deviam ser 3) que revelou o problema.

**Ref:** Plexco Tasks s150 (2026-07-26), `vps-test.py::run_pytest`. Parente de
[#json-sed-aspas](#json-sed-aspas).

<a id="fix-vira-defeito-seguinte"></a>
## O fix vira o defeito seguinte: 3 CRITICALs em 5 rodadas, cada um filho da correção anterior {#fix-vira-defeito-seguinte}

`tags: review, CRITICAL em cascata, fix vira defeito, remedio generico, COALESCE, dupla escrita, intencao vs valor, credencial revogada, espelho stale, rodadas de revisao`

**Sintoma:** cada rodada de review acha um CRITICAL, você corrige, a rodada seguinte acha outro
CRITICAL **na sua correção**. Três das cinco vezes seguidas. Parece azar ou revisor implicante; não é.

**Causa raiz:** você está aplicando um **remédio genérico sobre o VALOR** a um problema que pede a
informação de **INTENÇÃO**. No caso real (dupla escrita de credenciais de tracking): "nunca escreva
NULL" virou `COALESCE(:v, coluna)` → isso trocou *apagar credencial* por *par incoerente* (id de um
registro com segredo de outro) **e** tornou impossível limpar qualquer campo; "então não copie nada"
→ isso deixou o espelho velho e **ressuscitou credencial revogada** no toque seguinte. Copiar tudo e
copiar nada são os dois extremos de um eixo em que a resposta certa não está.

**Solução:** parar de decidir pelo valor e passar a decidir pelo que o usuário **pediu**. Concretamente:
levar o conjunto de campos efetivamente enviados (`payload.model_dump(exclude_unset=True)` no
pydantic) **até a camada de dados**, e copiar exatamente esse subconjunto. Junto:
- parâmetro **kw-only SEM default** quando o mesmo valor significa coisas opostas em dois chamadores
  (ali, "coluna vazia" era *"o operador desconectou"* numa rota e *"não há o que espelhar"* na outra) —
  o call site esquecido quebra no import em vez de escolher em silêncio;
- e **executar contra o banco real**: os 4 primeiros remédios foram raciocínio sobre o código; o que
  encerrou o ciclo foi rodar o código real contra Postgres real, com os dois extremos virando dois
  testes que se contradizem se alguém mexer num só.

**Como perceber cedo:** se a sua correção é uma regra sobre *que valor escrever* (`COALESCE`,
"nunca NULL", "sempre copia", "nunca copia"), pergunte se o dado que falta é **a intenção de quem
chamou**. Se for, nenhuma regra sobre o valor vai fechar.

**Ref:** Paid Media Automation, fatia 1 de multiplicidade de destinos (2026-07-26), commit `6c1b635`.

<a id="skew-lib-imagem-vs-local"></a>
## Suíte verde e boot morto: a versão da lib na IMAGEM não é a da sua máquina {#skew-lib-imagem-vs-local}

`tags: skew de versao, imagem vs local, boot morto, suite verde, FastAPI, response_model, status_code 204, from __future__ import annotations, ForwardRef, docker, swarm, container removido, smoke docker run`

**Sintoma:** 818 testes passam local, o review aprova, e a task **morre no boot em produção**. O log
do serviço não ajuda porque o container falhou e o swarm já o removeu.

**Causa raiz:** skew de versão entre a imagem e o ambiente de dev. No caso real: FastAPI **0.115.6**
na imagem × **0.136.1** local. Uma rota `status_code=204` com handler anotado `-> None` (num módulo
com `from __future__ import annotations`, que transforma a anotação em `ForwardRef` → `NoneType`) é
lida pela 0.115 como *tem response_model* e o **import aborta**; a 0.136 normaliza `None` para "sem
modelo" e passa. Mesmo código, veredito oposto.

**Solução (imediata):** declarar explicitamente o que as duas versões entendem igual — ali,
`response_model=None` no decorator.

**Solução (da classe):** um passo de CI que instala o `requirements.txt` **da imagem** num venv e faz
só `python -c "import app.main"`. Isso pega a família inteira, não a instância.

**Armadilha da guarda:** o teste óbvio — inspecionar `route.response_model` no app montado — é
**teatro** no ambiente local, porque a lib nova normaliza e a asserção passa mesmo sem o fix (provado
por mutação). A guarda tem que ler o **fonte** (AST, não regex: um revisor listou 7 estilos de
declaração que regex perde e que quebram igual).

**O que salvou:** `fail-closed` no entrypoint (migração falha ⇒ não sobe) **pareado** com
`failure_action: rollback` no swarm — a task nova morreu, o pin anterior voltou sozinho e o tráfego
não caiu. Fail-closed sem rollback pareado seria crash-loop.

**Ref:** Paid Media Automation (2026-07-26), commit `b50a4e9`. Parente de
[#verificar-runtime-nao-estrutura](#verificar-runtime-nao-estrutura) e
[#build-dir-compartilhado-tag-nova](#build-dir-compartilhado-tag-nova).

## "Sessão de 30 dias" que morre em 2 segundos: o wipe do refresh token em falha TRANSITÓRIA {#refresh-wipe-transitorio}

`tags: refresh token, sessao curta, logout inesperado, volta pro otp, wipe de credencial, erro transitorio, 5xx, timeout, rotacao, familia de refresh, auth`

**Sintoma:** usuários voltam pro OTP o tempo todo apesar do refresh token de 30 dias. A auditoria de
código passa — o item "renova no 401?" está **PASS e correto**. A medição do lado do auth mostra
famílias de refresh com **vida mediana 0,0h**: nascem no login e nunca rotacionam.

**Causa raiz (a que mais machuca):** o cliente descarta a credencial em erro que **não é rejeição**.
No caso real: `if (!res.ok) { clearTokens() }` — que inclui **5xx** — mais `catch { clearTokens() }`
— que inclui **timeout/rede/CORS**. Com o servidor de auth reiniciando ou a rede oscilando, **um
soluço de 2 segundos custa a sessão de 30 dias**, em silêncio. O interceptor ainda completava o
serviço redirecionando pro `/login?expired=1`.

**Causa raiz (a irmã, mais citada e menos frequente):** *cold start* que não consulta o refresh. Se o
gate de sessão é `!!accessToken` e o refresh só roda reativamente no 401, então **sem access token
não sai request → não há 401 → nunca se apresenta o refresh**. O app vai pro login com a credencial
de 30 dias válida no storage e **zero** chamadas de refresh na aba Network.

**Solução:**
1. Descartar a credencial **somente** em rejeição definitiva do servidor (`401/403/422`). 5xx, 429,
   timeout e rede **preservam** — o servidor não disse que a sessão morreu.
2. O interceptor só derruba/redireciona se a credencial **já foi descartada** por quem sabe
   distinguir. Caso contrário: falha a request, não a sessão.
3. Gate de sessão conta **access OU refresh**. Mudar na fonte única cobre N telas sem editar N
   arquivos (no caso real, 21).
4. Refresh proativo no boot quando falta o access e sobra o refresh.
5. **Timeout** no fetch do refresh (8–10s). Sem ele, um servidor pendurado prende o single-flight
   pra sempre e enfileira toda renovação seguinte atrás dele — troca re-OTP por tela branca.

**Por que preservar em 5xx é seguro (confirmado no código do servidor):** o consumo do refresh é
posterior ao claim atômico. Em 502/503 de proxy e em 500 antes do claim, o token **não foi
consumido** e segue válido. E quando foi consumido, o filho se perdeu junto com a resposta — aquela
sessão já estava perdida. **Não existe cenário em que preservar piore a vida do usuário.**

**O perigo que sobra NÃO é o retry pós-5xx — é staleness entre abas:** aba A rotaciona e recebe o
filho; aba B, que leu o **mesmo** token antes, tenta 60s depois com o valor velho, cai fora da janela
de graça (~10s) e **queima a família viva** — matando a sessão que A acabou de renovar (RFC 6749
§10.4). Defesas: single-flight por aba; **ler o token do storage imediatamente antes de cada
chamada**, nunca de variável/closure capturada antes; e nada de backoff martelando o mesmo token.
Corolário: **"o token mudou?" não é sinal de nada** — `localStorage` é compartilhado entre abas; o
sinal confiável é estado por aba.

**Armadilha do teste:** os casos de falha transitória passam **antes e depois** do fix se você só
exercitar o boot — sem access token, o código antigo nem chegava no wipe. O teste que prova é o do
caminho do **interceptor**: access presente + API 401 + refresh 503 → a sessão tem que sobreviver.
Prove revertendo o fonte (`git stash`) e mantendo o spec: se não ficar vermelho, o teste é teatro.

**Ref:** Família Milionária (2026-07-27), commits `4f8c88e`/`75eb2bc`. Parente de
[#verificar-runtime-nao-estrutura](#verificar-runtime-nao-estrutura).

## Auditoria cross-repo que lê o CHECKOUT LOCAL vira evidência circular {#auditoria-cross-repo-working-tree}

`tags: auditoria cross-repo, working tree, origin, evidencia circular, checkout local, git fetch, alerta retirado por engano, prova de codigo, revisao entre times`

**Sintoma:** um time audita o repo do outro, conclui "vocês já estão cobertos" e **retira um alerta
procedente**, citando linhas de arquivo como prova. O time auditado quase arquiva um defeito real.

**Causa raiz:** a auditoria leu os arquivos do **working tree** do outro repo, não de
`origin/<branch>`. Como havia uma sessão editando naquele momento — **em resposta ao próprio
alerta** — o auditor enxergou o efeito do que ele mesmo causou e reportou como prova de que o alerta
era desnecessário. Evidência circular perfeita: quanto mais rápido o outro time corrige, mais
convincente fica o argumento de que não havia o que corrigir.

**Solução:** auditoria cross-repo lê **`git show origin/<branch>:<arquivo>`**, sempre. O checkout
local pode conter trabalho em andamento, stash aplicado, ou branch diferente.

**Do lado de quem RECEBE a devolutiva:** se um documento cita o *seu* código como evidência, confira
contra `origin` antes de aceitar — inclusive (e principalmente) quando a conclusão é elogiosa. Um
`git grep -c "<símbolo citado>" origin/main -- <path>` devolvendo **0** encerra a discussão em
segundos. Elogio que bate com o que você acabou de escrever e ainda não publicou é sinal de alarme,
não de conforto.

**Ref:** Família Milionária × auth-service (2026-07-27),
`docs/cross-product/2026-07-27-auth-retrata-retirada-familia-e-responde-5xx.md` — o auditor
retratou-se e adotou a regra do `origin/`.

> **Nova entrada?** Copie o bloco-modelo abaixo, preencha, e adicione no Índice.
>
> ```

## Cliente de API que devolve `None` no erro faz o produto inteiro achar que ENTREGOU {#provider-none-vira-entrega}

`tags: provider none entrega recusa retry fila pending idempotencia envio whatsapp`

tags: mensagem nao entregue, provider devolve None, WhatsApp recusou, 400 INVALID_JID, 429 rate limit, fila de retry vazia, pending_messages, achou que enviou, SENT REJECTED DROPPED, desfecho explicito, self-loop guard, idempotency key, duplicar mensagem

**Sintoma:** mensagens que o provider RECUSOU aparecem como enviadas. A fila de retry existe,
está implementada e testada — e NUNCA recebe nada. Ninguém percebe porque não há erro: o log da
recusa fica no cliente HTTP, e a camada de cima segue como sucesso.

**Causa:** o wrapper do provider engole a resposta ruim e devolve `None`
(`if status < 300 and code == "SUCCESS": return data` … `return None`), e o chamador só faz
`await client.send(...)` sem olhar o retorno. Como não LEVANTOU, "deu certo".

**Como achar:** mande de propósito pra um destino que o provider recusa (número reservado,
credencial inválida) e pergunte ao BANCO, não ao log: a linha entrou na fila de retry? Se a
resposta for "zero linhas", o produto está mentindo. Teste unitário não pega porque todo mundo
simula falha **levantando exceção** — que não é como esse tipo de envio falha.

**Como resolver:** o envio passa a declarar um **desfecho explícito**, e são TRÊS, não dois:

| Desfecho | Quem causou | Retenta? | Vai pra fila? |
|---|---|---|---|
| `SENT` | provider aceitou | — | — |
| `REJECTED` | provider recusou / rede caiu | sim | sim |
| `DROPPED` | **decisão nossa** de não enviar (guarda de segurança, destino inválido) | não | **NÃO** |

O `DROPPED` separado não é preciosismo: enfileirar um descarte deliberado faz a fila entregar
depois exatamente a mensagem que a guarda existia pra impedir. E desfecho **desconhecido** (caminho
novo que esqueceu de declarar) deve cair como `REJECTED` + log de erro — fail-safe na direção da
entrega, nunca na do silêncio.

**Armadilhas ao aplicar (as duas custaram uma rodada cada):**
- A tabela da fila costuma ter FK obrigatória (`conversation_id NOT NULL`). Há callers que
  despacham sem esse contexto — passar a enfileirar transforma perda silenciosa em **exceção no
  meio do envio**, que é pior. Sem o contexto: reporta e loga alto, não enfileira.
- **Timeout depois da entrega** é indistinguível de recusa se o wrapper engole toda exceção. O
  retry pode DUPLICAR. Decida conscientemente e ESCREVA a decisão no código; se duplicata doer, o
  lugar de separar "resposta com erro" de "sem resposta" é o wrapper, não o chamador.

**Sintoma-irmão pra procurar no mesmo repo:** algum chamador que já tentava ler o retorno
(`ok = await send(...)`; `status = "success" if ok is not False`) — ele estava escrito esperando um
bool que nunca existiu, e contabilizava 100% de sucesso. Achar isso confirma o diagnóstico.

Visto em: tiatendo `0.253.1` (2026-07-27), achado por smoke em produção depois de a suíte inteira
(4900+) e duas reviews cross-provider passarem.

## Mock do DAO esconde erro de CHAVE e de serialização — se a mudança é de banco, o teste é de banco {#mock-dao-esconde-chave}

`tags: mock dao chave lookup normalizacao jsonb serializacao teste banco postgres`

tags: mock esconde bug, DAO, chave de lookup, normalizacao de telefone, E164, JSONB volta string, set_type_codec, teste de banco, postgres efemero, ida e volta, invariante de persistencia

**Sintoma:** a feature tem testes de sobra (dezenas, todos verdes) e não funciona contra o banco
real. Ou pior: funciona hoje e quebra quando o caller muda de formato.

**Causa concreta que apareceu:** a fachada GRAVAVA com a chave crua (`+5567999…`) e LIA com a chave
normalizada (só dígitos). Escrita e leitura em chaves diferentes → o estado some **em silêncio**.
Todo teste passava porque mockava o DAO: o mock devolve o que você guardou, na chave que você usou.
Havia ainda o irmão da mesma família: JSONB que volta como **string** quando o driver não tem codec,
e o `.get()` do consumidor levanta `AttributeError` atrás de um `try/except` fail-open.

**Como resolver:** ao mudar invariante de persistência (o que grava, o que apaga, qual a chave),
escreva UM teste que faça a **ida e volta no banco de verdade** — gravar, ler, e usar o valor lido
no consumidor real. Num projeto onde os testes de DB pulam sem DSN, isso significa rodar o recorte
num Postgres efêmero antes de considerar pronto.

**Regra prática:** mock prova FLUXO; banco prova CHAVE, TIPO e DEFAULT. Mudou fluxo, mocke. Mudou
schema/chave/serialização, não tem jeito: banco.

## Guarda que o entrypoint real nunca alcança: teste de componente ISOLADO cria a ilusão {#guarda-morta-entrypoint}

`tags: guarda morta inalcancavel entrypoint teste isolado camadas subconjunto`

tags: guarda morta, codigo inalcancavel, teste isolado engana, entrypoint real, ordem das camadas, subconjunto de gatilho, defesa em profundidade falsa, fronteira entre guardas

**Sintoma:** você escreve uma proteção, testa, passa — e ela nunca roda em produção, porque outra
camada consome o evento um passo antes. Fica um código que LÊ como proteção e não protege nada
(veja também §"Cinto de segurança" extra CORTA o caso legítimo).

**Como achar:** compare os CONJUNTOS de ativação das duas camadas. No caso real, a de cima ativava
com `estado ∈ A` e `token ∈ B`; a de baixo, com `estado ∈ A'` e `token ∈ B'`, e valia
`A' ⊆ A`, `B' ⊆ B` — ou seja, toda vez que a de baixo ativaria, a de cima já tinha comido o turno.
Subconjunto é o sinal: se o gatilho da sua guarda é subconjunto do gatilho de quem vem antes, ela é
inalcançável.

**Por que o teste não pegou:** ele chamava o componente DIRETO, mockando o vizinho. O isolamento que
torna o teste rápido é o mesmo que apaga a ordem real das camadas.

**Como resolver:** apague a guarda morta (não a deixe "por garantia") e trave a FRONTEIRA com um
teste que exercita o **entrypoint de verdade**, provando qual camada atende cada janela. Documente a
relação de subconjunto no comentário — é ela que alguém vai quebrar sem perceber.

Visto em: tiatendo, correção do "número solto no bot admin" (2026-07-27).

Visto em: tiatendo, N19 (2026-08-05) — variante de BYPASS PARCIAL, não guarda morta total. O gate
de `bot_paused` (`messageRouter._stageLoadConversation`, Stage 2) funciona perfeitamente pra
mensagens que não casam nenhum intent do Stage 0b (`_maybeHandleRestaurantNiche`, que roda ANTES).
Mas o conjunto de ativação do Stage 0b (saudação/cardápio/horário/opt-out) é ORTOGONAL ao de
`bot_paused=True` — não subconjunto dele, mas também não disjunto — então pra QUALQUER mensagem que
caia na interseção (ex.: cliente pausado manda "oi"), o Stage 0b atende primeiro e o gate de pausa
nunca é alcançado nesse turno específico. Achado só ao FORÇAR o estado real via `pauseBot()` (não
SQL cru) e mandar uma mensagem real — nenhum teste unitário isolado (que mocka o vizinho) pegaria,
pelo mesmo motivo do sintoma original desta entrada. Generaliza o "Como achar": a pergunta certa não
é só "B é subconjunto de A?" (bypass total) — é "A ∩ B é vazio?" (query completa: existe qualquer
mensagem que ative as duas camadas?). Se não for vazio E a camada de cima roda primeiro E não
delega, a de baixo é inalcançável PRA ESSE SUBCONJUNTO, mesmo continuando viva pro resto.

---

## Ausência por design não é falha — e o teste sintético não distingue as duas {#ausencia-por-design-vs-falha}

`tags: teste sintetico, crawler, varredura automatizada, evento nao disparou, dedupe por sessao, sessionStorage, exclusao deliberada, validacao HTML5, GA4, conversao, dado real, falso negativo, silencio`

**Sintoma:** uma varredura automatizada clica CTAs e submete formulários de um site, e o relatório
volta dizendo que N deles "não dispararam evento". Conclusão natural, e errada: a instrumentação
está quebrada.

**O que estava acontecendo:** três comportamentos **projetados** produziam o mesmo silêncio que uma
falha produziria.
1. **Deduplicação por sessão** — `leadOnce(metodo)` grava em `sessionStorage` e o segundo disparo do
   mesmo método é pulado. Quem clica em 3 botões de WhatsApp gera **1** lead, que é o correto.
2. **Exclusão deliberada** — CTAs de captação de estoque ("anunciar/avaliar meu imóvel") são
   excluídos de propósito para não inflar o otimizador de mídia.
3. **Recusa de formulário inválido** — o código não dispara conversão em form que não passa na
   validação HTML5. E o preenchimento sintético do crawler ("PMA DIAGNOSTICO" num `<select>`
   obrigatório) produz exatamente um form inválido.

**Como resolver:** antes de declarar falha a partir de teste sintético, **procure o mesmo evento no
tráfego real**. Uma query no log de eventos com o campo `method` resolveu em 30 segundos o que a
varredura tinha deixado ambíguo: os leads reais chegavam por `form` **e** por `whatsapp`.

🔑 **A regra:** teste sintético prova que algo **funciona** (disparou = funciona). Ele **não** prova
que algo está quebrado — silêncio pode ser dedupe, exclusão de negócio ou validação. Para provar
quebra, use dado real. E se o próprio relatório traz um veredito tipo `cruzamento_nao_aplicavel`,
ele já está avisando que não dá pra concluir dali.

Visto em: Paid Media Automation, diagnóstico do funil da Imobiliária Uni (2026-07-27).

---

## O ponteiro estava no PLANO e eu não o segui: improvisar spec sobre design já aprovado {#ponteiro-no-plano-nao-seguido}

`tags: plano, ponteiro nao seguido, spec duplicada, handoff de design, retrabalho, gitignore esconde artefato, ler o PLANO antes, conselho, artefato ja aprovado`

**Sintoma:** escrevi do zero uma spec de feature — com requisitos, riscos e critério de pronto — e
rodei conselho nela. Depois o operador apontou que já existia um **handoff de design em alta
fidelidade**, encomendado e aprovado por ele, cobrindo a mesma tela: README de ~200 linhas, 3
protótipos navegáveis e 6 screenshots. O estado vazio do design **era** o wizard que eu especifiquei.

**A parte incômoda:** o `PLANO.md` do projeto **já registrava** o handoff, com caminho, na linha
`[0] Plano da UI — depende do handoff do Claude Design (…já entregue e lido)`. Não foi conhecimento
perdido: foi ponteiro não seguido. A pasta estar no `.gitignore` explica por que ela não aparece em
busca de código, mas **não** explica ter ignorado a linha do plano.

**Como resolver:** antes de escrever spec de qualquer tela, **procure ativamente por artefato de
design anterior** — `grep -ri "handoff\|design" docs/PLANO.md` e um `ls` na raiz do projeto (pastas
gitignored não aparecem em busca de código nem em `git ls-files`). Se existir, a spec **implementa**
o handoff em vez de redesenhar; o papel dela vira dizer o que entra em cada fatia, o que o backend
precisa entregar e como se verifica.

⚠️ **Corolário sobre perguntar:** tendo achado o design, perguntei ao operador se ele queria o design
dele **ou** a minha improvisação. Não era decisão real, e ele reagiu a isso. Quando uma das opções é
obviamente superior por um critério que o operador já estabeleceu, escolher é seu trabalho.

Visto em: Paid Media Automation, funil da jornada (2026-07-27).

---

## Conselho: `status: ok` NÃO significa que o membro respondeu {#conselho-status-ok-content-vazio}

`tags: conselho, council-orchestrator, status ok, content vazio, deepseek mudo, reasoning_tokens, llama tautologia, finding falso, cross-claude, N de 3 responderam, quorum`

O `council-orchestrator` marca `status: "ok"` quando a chamada HTTP deu certo — **mesmo com
`content: ""`**. Numa sessão o **DeepSeek devolveu conteúdo vazio 3 vezes seguidas** (analyze de
spec e pre-mortem de plano, prompts de ~2,8k tokens), gastando **1024 de 1024 tokens de completion
inteiramente em `reasoning_tokens`** e não emitindo resposta. Quem lê o `status` conclui que o
conselho rodou.

**Como detectar:** olhe `responses[].content`, não `status`. Vazio = membro caiu.
**Efeito:** o canon exige ≥2 provedores para aprovar spec. Com o DeepSeek mudo e a Llama
produzindo genérico, o conselho fica **abaixo do mínimo sem avisar**.

⚠️ **A Llama passa no `status` e no `content`, e ainda assim pode não valer nada.** No mesmo dia ela
devolveu, num pre-mortem, três tautologias: *"se a atualização não foi feita corretamente, o plano
pode falhar"*. E num analyze pediu para especificar o que dois requisitos já especificavam —
**findings falsos**, que só não viraram retrabalho porque foram conferidos contra a fonte.

**O que fazer:** quando o conselho vier vazio ou genérico, dispare o **Cross-Claude (subagente
Sonnet)** com o prompt e **mande ele ler os arquivos** que o artefato cita. Foi o único membro que
produziu achado real nas duas rodadas — inclusive um CRITICAL que teria feito uma fatia inteira ir
a produção sem mudar nada.

**Reporte sempre "N de 3 responderam".** Conselho parcial apresentado como completo é pior que
conselho nenhum.

**Relacionado (mesma classe, medição posterior e mais completa):**
[#conselho-perna-vazia-teto-tokens] — a causa do `content` vazio é o **teto de `max_tokens`** contra
um modelo de raciocínio. Leia os dois como um só: aqui está o sintoma no consumidor, lá está a conta.

Visto em: Plexco Tasks, s151 (2026-07-27).

---

## Pre-mortem de plano: mande o revisor LER o código, não só o plano {#pre-mortem-revisor-le-o-codigo}

`tags: pre-mortem, conselho, plano, revisor, ler o codigo, arquivos vizinhos, cross-claude, tool use, teste que passa com bug vivo, funcao isolada, caminho real`

Um plano de 5 tasks para "a transcrição parar de sumir" estava **correto em tudo que afirmava** e
ainda assim **não mudaria nada em produção**. Ele consertava o truncamento em dois lugares que
conhecia (`tasks_bot_v1.py`, `_triagem_create.py`) e ignorava um terceiro, **anterior aos dois**,
que era o que decidia (`wa_media_enrich.py:155` cortava em 255 antes de o handler ser chamado).

O revisor que leu **só o plano** (Llama) não tinha como ver. O que leu **os arquivos citados**
(Cross-Claude, 27 tool-uses) achou em uma passada — e achou junto que o teste do plano **passaria
com o bug vivo**, porque exercitava a função isolada em vez do caminho real.

**Regra prática:** no pre-mortem, liste no prompt os arquivos que o plano toca **e os vizinhos do
caminho de execução**, e peça explicitamente: *"o plano faz afirmações sobre estes arquivos —
verifique"*. Um plano internamente coerente pode estar consertando o lugar errado, e essa classe de
erro é invisível de dentro do documento.

**Sinal de alerta correlato:** se o teste do plano chama a função diretamente com dados "limpos",
pergunte de onde vêm os dados **em produção**. Foi exatamente a diferença entre verde falso e
verde real.

Visto em: Plexco Tasks, s151 (2026-07-27).

---

## Org de teste limpa não expõe topologia — só comportamento {#org-limpa-nao-expoe-topologia}

`tags: E2E, org de teste, seed, dado limpo, topologia, grafo, reentrada, hierarquia, ciclo, coleção vazia, item orfao, falso verde, dado adverso`

Uma tela de grafo passou no E2E autenticado (org descartável, dados semeados) e estava **quebrada
na org real do operador**: setas com coordenadas negativas apontando para fora do canvas e a pílula
de taxa por cima do texto do cartão.

Causa: a geometria ligava sempre `from.right → to.left`, assumindo destino à frente. A org real
tinha **reentrada** (item que volta para uma etapa anterior, ou aresta entre dois nós da mesma
coluna); a org de teste não. O backend **já tratava** reentrada — era o desenho que assumia fila.

**Regra:** E2E em org limpa prova **comportamento** (persistiu, transicionou, respondeu), não
**forma do dado**. Feature que depende da topologia (grafo, árvore, ciclo, hierarquia) exige semear
a topologia adversa de propósito, ou olhar uma base real. Verde em org limpa é **falso verde** para
essa classe.

Vale para além de grafo: hierarquia profunda, coleção vazia, item órfão, ciclo — qualquer forma que
a org nova não produz sozinha.

Visto em: Plexco Tasks, s151 (2026-07-27).


---

## Marcar uma entidade como "fora do padrão": filtre os EMISSORES, não só os leitores {#marca-varre-emissores-e-leitores}

`tags: flag, marcar entidade, fora do padrao, conversa administrativa, tenant de teste, leitores, emissores, broadcast, reengajamento, varredura dupla, medir no banco, silenciar sem devolver, horario comercial`

Ao criar uma flag do tipo "esta linha não é do tipo normal" (conversa administrativa, usuário
interno, tenant de teste, conta de sistema), a varredura óbvia é a dos **leitores**: métricas,
relatórios, boards, exports. Foi o que fiz — e fechei a frente com números medidos, achando que
tinha coberto.

No dia seguinte a pergunta do conselho foi *"e broadcast/re-engajamento?"*. A medição em produção
respondeu numa coluna: `last_reengage_sent_at = 2026-06-12`. **A pessoa já tinha recebido**, meses
antes e em silêncio, um texto escrito para outro público.

**Por que a lista dos leitores não bastou:** filtrar leitor conserta **relatório**; filtrar emissor
conserta **o que a pessoa recebe no celular**. O segundo é o que o usuário final percebe.

**Como aplicar:** ao introduzir a marca, varra DUAS listas antes de fechar —
1. quem **LÊ** a entidade (métrica, resumo, board, export);
2. quem **ENVIA** para ela (cron de reengajamento, broadcast, lembrete, alerta, convite, recuperação
   de carrinho) — e para cada um pergunte *"o texto é escrito para quem?"*.

E **meça no banco se já aconteceu** (`last_*_sent_at`, contadores de envio) em vez de raciocinar se
é possível. A resposta veio de uma coluna, não de uma dedução.

⚠️ Corolário que quase virou o defeito seguinte: **calar sem devolver é trocar de defeito.** Silenciar
um automatismo numa entidade e excluí-la dos coletores que a reativariam a deixa muda para sempre. O
retorno entra no mesmo commit — e, se for silencioso, ele **não pode herdar o gate de horário
comercial** dos coletores que mandam texto (senão o silêncio dura a noite inteira).

Visto em: tiatendo, 2026-07-28 (`0.254.0`/`0.255.0`).

---

## Brief de design que cita a fonte pelo NOME propaga erro invisível {#brief-cita-token-nao-nome}

`tags: design, brief, handoff de design, fonte, tipografia, token, ff-sans, comentario desatualizado, mockup, altura do componente, documentacao nao testada`

Um brief de redesenho dizia "Space Grotesk + JetBrains Mono". Eu copiei isso de um **comentário
desatualizado** no template base; o produto carregava **Geist** havia muito tempo. O designer
calibrou o mockup na métrica da fonte errada, e a altura prevista do componente (148px) não bateu com
a implementada (160px) — diferença que só apareceu depois de construir.

**Regra:** no brief, cite o **token** (`--ff-sans`, `--ff-mono`), não o nome da família. Token é
verificável e não mente; nome é cópia, e cópia envelhece. Se precisar citar o nome para o designer se
orientar, **leia do arquivo de tokens na hora**, nunca de um comentário.

Vale para qualquer valor de design no brief: cor, raio, sombra, escala. Comentário em template é
documentação **não testada** — envelhece em silêncio e vira fonte de verdade por acidente.

Visto em: tiatendo, 2026-07-28 (rodada 1 do card recusada; brief corrigido para a rodada 2).

---

## Layout que depende de menu lateral colapsável: `@container`, não media query {#container-query-menu-colapsavel}

`tags: css, container query, container-type, inline-size, media query, menu lateral, sidebar colapsavel, largura util, preview mente, responsivo, layout`

Um componente precisava rearranjar-se quando ficava estreito. O reflexo é `@media (max-width: …)` —
e estaria **errado metade das vezes**: a tela tinha menu lateral de largura variável (68px recolhido
/ 248px expandido). Com o menu aberto a 1920 o componente é mais estreito do que com o menu fechado a
1280, mas a media query enxerga só a janela e responde igual nos dois casos.

**Regra:** quando a largura útil do componente depende de algo que não é a janela (menu colapsável,
painel lateral, split view), o gatilho é `container-type: inline-size` no ancestral + `@container`.
A pergunta que decide: *"a largura deste componente muda sem a janela mudar?"* Se sim, media query
é a ferramenta errada.

**Ao medir o resultado, simule a casca real** (menu + conteúdo) no preview. Um preview que renderiza
o componente solto numa página de 1800px mente sobre a largura da coluna — e foi o que fez a primeira
rodada ser aprovada no preview e recusada na tela.

Visto em: tiatendo, 2026-07-28 (card do quadro de pedidos, `0.257.0`).

---

## Mesma regra escrita em dois interpretadores (.ps1 + .sh) diverge calada {#regra-duplicada-ps1-sh}

`tags: duplicacao, ps1, sh, bash, powershell, paridade, gate, router, lista hardcoded, drift entre implementacoes, case-insensitive, fonte unica, teste que raspa fonte`

**Sintoma:** o gate protege quando roda por um caminho e não protege pelo outro — ou pior, ninguém
nota, porque cada máquina/agente usa só um dos dois. Nenhum erro aparece.

**Causa raiz:** a mesma lista/regra existe em duas implementações (array no `.ps1`, cadeia
`[[ =~ ]]` no `.sh`) e nada força as duas a concordarem. No caso real eram **três** cópias: os
testes ainda **raspavam a regex do fonte `.ps1`** com `[regex]::Matches(...)` — então (a) o `.sh`
nunca era testado e (b) o padrão que não casava com a regex de raspagem (`'^\.env'`, que não começa
com `(`) ficou anos sem cobertura. Divergência achada: `-match` do PowerShell é **case-insensitive**
por padrão e `[[ =~ ]]` do bash é **case-sensitive** — `backend/Auth/` escalava num e não no outro.

**Solução:** a regra vira **dado**, num arquivo lido pelos dois (e pelos testes). Restrinja a
sintaxe ao subconjunto comum aos dois motores (`[0-9]`, não `\d`; nada de `(?...)`) e tenha **teste
de paridade**: mesma entrada nos dois executáveis, mesma saída. Sem o teste de paridade, a fonte
única volta a divergir na primeira "correção rápida" de um lado só. Teste que lê o **fonte** em vez
do **dado** é pior que não ter teste: quando a lista sai do fonte, ele passa a extrair lista vazia e
o teste negativo ("não é sensível") passa por vacuidade.

**Ref:** `CANON_VERSION.md` v6.31.0 (router de pasta sensível); report "Melhoria na VPS" 2026-07-27.

---

## Saída de `jq`/`python` no Windows vem com CRLF e o `\r` mata a regex em silêncio {#crlf-mata-regex-git-bash}

`tags: crlf, \r, carriage return, jq, python, git-bash, windows, regex nao casa, padrao morre calado, command substitution, tr -d, msys`

**Sintoma:** um padrão lido de arquivo/JSON simplesmente **não casa**, sem erro nenhum. O mesmo
padrão, colado à mão no shell, casa. No caso real, cada projeto declarava seus caminhos sensíveis
num JSON e o router lia, aceitava e ignorava — silenciosamente.

**Causa raiz:** `jq` e `python` no Windows escrevem **CRLF**. `$(...)` remove só o `\n` final, então
cada linha chega com `\r` colado no fim. Uma regex terminada em `$` vira `...$\r` e não casa com
nada. Um path comparado por igualdade também nunca bate. Some ao fato de que ler o mesmo dado por
`sed`/`grep` costuma **mascarar** o problema (`[[:space:]]` inclui `\r`), e o bug fica restrito a um
dos caminhos de leitura.

**Solução:** todo dado que vem de processo externo passa por `tr -d '\r'` antes de virar
regex/comparação. E teste a **pipeline de verdade** (o script rodando com o arquivo real), não a
lógica de matching isolada: em teste unitário as strings vêm limpas e o bug não aparece.

**Ref:** `CANON_VERSION.md` v6.31.0 (achado enquanto se testava o próprio fix, 2026-07-27).

---

## Hook em PowerShell bloqueia commit legítimo vindo do git-bash (path `/d/...` e `-c` ≠ `-C`) {#hook-ps-path-msys-e-match-case}

`tags: hook, pre-commit, powershell, git-bash, msys, /d/, cygdrive, path windows, -match case-insensitive, -cmatch, falso positivo, PERCUS_HOOKS_DISABLED, exit 128`

**Sintoma:** o hook barra o commit dizendo que não há review — mas o review existe e está fresco. A
mensagem de diagnóstico mostra um caminho estranho, tipo `\d\Claud Automations\repo\.deepseek\reviews`,
ou um "git root" que nem é diretório (`commit.gpgsign=false`).

**Causa raiz (duas, independentes):**
1. O agente roda `cd "/d/Claud Automations/repo" && git commit`; o hook extrai o dir e entrega esse
   path **MSYS** para o `git` do **Windows** → `exit 128`, o hook cai no fallback e vai procurar o
   review num caminho inexistente.
2. `-match` do PowerShell é **case-insensitive**: em `git -c commit.gpgsign=false commit`, o `-c` de
   configuração casa no padrão de `-C <dir>` e o "repo target" vira `commit.gpgsign=false`.

**Solução:** normalizar `/d/...` e `/cygdrive/d/...` para `D:\...` antes de qualquer chamada a
binário Windows, e usar `-cmatch` onde a distinção maiúscula/minúscula **é** semântica (`-C` vs
`-c`). Vale a regra geral: **flag que muda de significado com o case exige `-cmatch`**.

Por que isso importa mesmo falhando "pro lado seguro": gate que bloqueia o caminho legítimo ensina a
desligar o gate (`PERCUS_HOOKS_DISABLED`) — e aí ele deixa de existir de verdade. Falso positivo
recorrente custa a proteção inteira.

**Ref:** `CANON_VERSION.md` v6.31.1; testes em
`plugin/percus-review/tests/pre-commit-path-resolution.tests.ps1`.


## Flag de "já processei" que mente produz PERDA e DUPLICAÇÃO ao mesmo tempo — e uma esconde a outra {#flag-ja-processei-que-mente}

`tags: idempotencia, _preSaved, pre-salvo, duplicata, mensagem perdida, webhook, batch, pipeline inbound, persistencia, contrato de flag, defeitos de sinais opostos`

**Sintoma:** você investiga "o item X não é gravado" e a contagem no banco parece desmentir a
suspeita (há linhas de X, então "não perde"). Meses de dados dizem que está tudo bem. Ao mesmo tempo,
ninguém reclama de duplicata — porque duplicata não dispara alarme: o total fica ALTO, a lista parece
completa, e nenhum contador acusa falta.

**Causa raiz:** um flag booleano do tipo `_preSaved` / `alreadyHandled` / `processed` cujo CONTRATO
("este item já está persistido") não é honrado nas duas pontas:
1. quem **carimba** o flag o faz incondicionalmente, mas só persiste um subconjunto
   (ex.: `if text:` — então o item sem texto é marcado como salvo sem ter sido) → **PERDA**;
2. quem **deveria ler** o flag não lê (ex.: gates que gravam "pra trilha de auditoria") → **DUPLICAÇÃO**.

Os dois defeitos têm a MESMA raiz e sinais opostos, então se cancelam na hora de procurar: quem
duplica parece não ter perdido nada, e é por isso que a suspeita original nunca fecha.

**Solução:**
- Teste as DUAS direções no mesmo commit: o caso em que o flag mente pra mais (perde) e o caso em que
  quem deveria lê-lo não lê (duplica). Um teste só deixa o outro defeito passar.
- Faça quem carimba persistir TUDO que é persistível (não só o caminho feliz), e todo ponto de escrita
  ler o flag antes de escrever e carimbá-lo depois.
- **A metadata é o melhor delator de autoria.** Quando a mesma chave lógica aparece 2×, compare a
  metadata das duas linhas: o formato de cada uma aponta o arquivo que a escreveu. Foi assim que os 5
  pontos de escrita apareceram, sem ler o código todo.
- Consulta que acha o defeito sem saber onde ele está (janela + `lag`):
  `lag(content) OVER (PARTITION BY <conversa> ORDER BY created_at)` e filtrar
  `content = prev_content AND created_at - prev_at < interval '5 seconds'`; agrupe **por mês** pra
  saber se é defeito VIVO ou fóssil de uma era antiga do sistema.

**Armadilha ao consertar:** se "não há nada a persistir" (evento de protocolo, payload vazio), o flag
deve ficar **True** — "não sobrou nada pra jusante gravar". Marcá-lo False por "honestidade" faz cada
evento vazio virar uma linha placeholder FANTASMA, porque o save a jusante costuma ser
`conteudo or "[placeholder]"`. O contrato certo é "não há pendência", não "eu gravei".

**Ref:** tiatendo `0.259.0` (2026-07-29) — 3711 pares idênticos com o mesmo `messageId`, 54 em julho;
`execution/webhooks/inboundPipeline.py`, `execution/core/messageRouter.py` (5 pontos de save),
`tests/test_inboundPersistenceContract.py`.


## Ao proteger alguém de um envio, o filtro tem que caber na CHAVE de cada emissor {#filtro-cabe-na-chave-do-emissor}

`tags: emissor, destinatario, filtro, guarda, is_admin, chave de busca, multi-tenant, outbound proativo, varredura`

**Sintoma:** você fecha o vazamento num emissor e replica "o mesmo filtro" nos outros. Um deles
continua alcançando quem deveria estar protegido — e o teste do filtro copiado passa.

**Causa raiz:** cada emissor encontra o destinatário por uma **chave diferente** (conversa, telefone,
tabela de clientes, JID de configuração). Uma marca gravada em UMA dessas entidades (ex.: uma coluna
`is_admin` na tabela de conversas) simplesmente não alcança o emissor que busca por outra chave —
registros criados por canais que nascem sem aquela entidade (loja web, painel) ficam órfãos e passam
pelo filtro sem nem serem avaliados.

**Solução:** ao varrer emissores, responda DUAS perguntas por emissor, não uma: (1) ele pode alcançar
quem quero proteger? (2) por qual CHAVE ele acha o destinatário? O filtro mora na chave dele — e onde
duas chaves coexistem, a guarda é dupla. Comparação de telefone é sempre por DÍGITOS
(`regexp_replace(x,'[^0-9]','','g')`): um lado guarda E.164 com `+` e o outro sem, e comparar cru casa
ZERO linhas **passando como sucesso** — falha silenciosa.

**Ref:** tiatendo `0.258.0` (2026-07-29); `scripts/auditAdminReach.py` mediu 0 ocorrências ANTES do
fix — medir também serve pra saber que não há o que consertar.

---

## `<input type="date">` mostra mm/dd mesmo com a página inteira em pt-BR {#input-date-formato-idioma-navegador}

`tags: input date, formato de data, dd/mm/aaaa, mm/dd, locale, lang, navegador em ingles, mascara, PatternFormat, react-number-format, showPicker, picker nativo`

**Sintoma:** usuário com o navegador em inglês vê datas `mm/dd/aaaa` numa página inteiramente
pt-BR; pôr `lang="pt-BR"` no HTML não muda nada.

**Causa raiz:** o formato de EXIBIÇÃO do `<input type="date">` nativo segue o **idioma da
interface do navegador**, não o `lang` da página — testado nos 3 casos (sem `lang`, `en-US`,
`pt-BR`): renderizam igual. Não existe fix por atributo.

**Solução:** componente próprio que preserva o picker nativo: input de texto com máscara
digitável `dd/mm/aaaa` (na FM: `PatternFormat` do `react-number-format`, dep que já estava no
bundle pro campo de dinheiro — zero dependência nova) + um `<input type="date">` **oculto**
(opacity 0, 1×1, `tabIndex={-1}`, `aria-hidden`) ancorando o botão de calendário via
`el.showPicker()` com fallback `el.focus()`. O contrato com o form continua ISO
(`aaaa-mm-dd`), idêntico ao input que foi substituído: digitação completa e válida emite ISO,
incompleta/inválida emite `''` — a validação de obrigatório do form segue intacta e os
call-sites não mudam de shape. Implementação de referência:
`Familia-Milionaria/familia-frontend/src/components/DateInput.tsx`.

**Ref:** FM commit `cbbd4e6` (2026-07-28) + spec `tests/e2e/date-mask.spec.ts` (digitou
dd/mm/aaaa → POST ISO; incompleta → zero POST; picker sincroniza a máscara).

---

## scp pra caminho remoto com colchetes (`[id]` de rota Next) falha por glob no lado remoto {#scp-colchetes-glob-remoto}

`tags: scp, ssh, glob, colchetes, [id], next.js app router, upload vps, cat redirect, wc -c`

**Sintoma:** subir `src/app/batch/[id]/page.tsx` por `scp` falha ("no match") ou o arquivo não
chega onde deveria.

**Causa raiz:** o lado remoto do scp passa o caminho pelo shell — `[id]` vira classe de
caracteres de glob e o alvo deixa de ser literal.

**Solução:** `ssh host "cat > '/caminho/batch/[id]/page.tsx'"` com o conteúdo no **stdin**
(aspas simples no remoto; alvo de redirection não sofre glob). Conferir depois com `wc -c`
local × remoto. Foi a receita do deploy da FM sob uplink degradado (subir só os alterados,
NOVO antes do MODIFICADO, + `deploy_*_v2.py --quick`).

**Ref:** FM 2026-07-28 (deploy do frontend `20260728-004439`).

---

## Módulo fail-open: "quebrado" e "corretamente desligado" ficam idênticos de fora, e o teste passa nos dois {#fail-open-esconde-teste-vacuo}

`tags: fail-open, feature flag, allowlist, dark launch, teste vacuo, mutation testing, assert_not_awaited, AsyncMock, gate silencioso, LLM, timeout`

**Sintoma:** o teste do gate de uma feature flag / allowlist passa. Você apaga a linha de
produção que implementa o gate. **O teste continua verde.**

**Causa raiz:** num módulo fail-open, o gate e a falha real convergem para a **mesma saída
observável**. Com o gate apagado, a execução segue até a chamada externa (LLM, HTTP, etc.), que
levanta — por credencial ausente no ambiente de teste, timeout, o que for —, o `except Exception`
do fail-open engole, e a função devolve exatamente o mesmo `ok=False` que o gate devolveria.
Resultado igual, mecanismo oposto. Asserir o resultado não distingue os dois.

Isso é grave porque **o gate costuma SER o dark launch**: se ele regride, a feature liga para
todo mundo em produção e a suíte inteira continua verde.

**Solução:** não asserte só o resultado — asserte que **o efeito colateral caro não aconteceu**.
Mocke a dependência externa e verifique que ela não foi chamada:

```python
llm = AsyncMock(return_value={"itens": [{"titulo": "nao devia chegar aqui"}]})
with patch.object(S.settings, "FEATURE_ENABLED", False), \
     patch.object(S.Service, "chamada_cara", llm):
    r = await S.entrypoint(texto, org_id="qualquer")
assert r.ok is False
llm.assert_not_awaited()      # <- é isto que dá dente ao teste
```

E escreva a **contraprova**: a org DENTRO da allowlist tem que CHEGAR na dependência. Sem ela,
uma allowlist que bloqueia todo mundo também passaria no teste de cima.

**Como descobrir se você já tem esse buraco:** mutação. Apague a linha de produção do gate, rode
a suíte, e veja se alguma coisa fica vermelha. Verde = o gate não tem teste.

**Ref:** Plexco Tasks s154 (2026-07-28), `wa_structurer.py`. Achado por mutação durante a
implementação: com o gate `if not settings.WA_STRUCTURER_ENABLED or not _org_allowed(org_id)`
removido, **7 passed**. Vale para qualquer guarda absorvida por `except` genérico — flag,
allowlist, rate-limit, circuit breaker.

---

## `ORDER BY created_at` não ordena um lote: `now()` é hora da TRANSAÇÃO {#created-at-nao-ordena-lote}

`tags: postgres, now(), current_timestamp, server_default, created_at, ordenacao, lote, batch, flake, transaction time, statement_timestamp, clock_timestamp`

**Sintoma:** N linhas criadas juntas (um lote, um fan-out, um import) saem na ordem certa quando
você testa, e um dia saem trocadas — sem ninguém ter mexido na query.

**Causa raiz:** `created_at` com `server_default=func.now()` grava `now()` do Postgres, que é
**hora do início da TRANSAÇÃO**, não do statement. Todas as N linhas do mesmo commit recebem o
**timestamp idêntico**. `ORDER BY created_at` então não desempata nada e o Postgres devolve a
ordem física do heap — que para poucas linhas num seq scan coincide com a de inserção, até deixar
de coincidir. Colunas de posição costumam nascer 0 em todas e não ajudam.

Medido em produção: 9 tarefas de um mesmo fan-out, `count(DISTINCT created_at) = 1`. E mais
revelador — a chamada de transcrição rodou **3 segundos depois** do timestamp que ficou gravado,
porque a transação já estava aberta.

**Solução:** ordene pelo que o **produtor** emitiu, não pelo que o banco carimbou. No teste, leia
os ids da lista que o próprio código montou (o retorno, o `side_effects`, o log) e resolva as
linhas nessa ordem. Se a ordem precisa sobreviver no banco, grave uma coluna de sequência
explícita — não confie em tempo. (`statement_timestamp()`/`clock_timestamp()` avançam dentro da
transação, mas ainda são tempo: continuam podendo empatar.)

**Ref:** Plexco Tasks s154 (2026-07-28), `test_wa_decomposicao.py` — três asserções de ordem
passavam por sorte; viraram `_tarefas_da_leva(db, result)`, que lê os ids do `side_effect`.

---

## Schema `strict` que OBRIGA o campo mas não ENSINA quando preenchê-lo produz silêncio, não erro {#strict-schema-campo-sem-instrucao}

`tags: structured outputs, function calling, strict, tool schema, prompt, openai, campo obrigatório, regressão silenciosa`

**Sintoma:** um recurso simplesmente para de acontecer. Nada estoura, nada loga, nenhum teste
fica vermelho. No caso real: "quero falar com um atendente" deixou de escalar para humano.

**Causa raiz:** ao trocar o contrato do LLM eu reescrevi o system prompt do zero e esqueci
**quatro** dos campos do schema (`atendente`, `entrega`, `endereco`, `pagamento`). Como o
schema é `strict`, todo campo está em `required` — então o modelo **é obrigado a preencher**
e devolve `false`/`null` para o que não entendeu que devia usar. O contrato continua válido, o
parse continua funcionando, a suíte continua verde. O recurso só some.

**Solução:** ao criar ou reescrever um tool schema, faça a checagem cruzada explícita —
**todo campo do schema tem uma linha de instrução no prompt?** É uma lista de dois conjuntos e
leva um minuto. E quando o schema substitui um anterior, faça o diff dos dois PROMPTS, não só
o dos schemas: o schema novo pode estar completo enquanto o prompt novo está pela metade.

**Corolário do mesmo caso** (contrato declarativo, "o LLM diz como o estado deve ficar"):
enuncie a **consequência da omissão**, não só a instrução positiva. "Repita as linhas que
permanecem" foi lido como sugestão; o que faltava era "toda linha que você NÃO incluir será
REMOVIDA". A regra positiva e a consequência negativa não são a mesma frase para um LLM.

**Ref:** tiatendo, frente do carrinho declarativo (2026-07-29), commit `6740202`.

---

## Guarda contra ação destrutiva tem que ser testada com PERGUNTAS, não só com comandos {#guarda-destrutiva-testar-com-perguntas}

`tags: regex, detecção de intenção, nlp, guarda, remoção, falso positivo, revisão adversarial, assimetria`

**Sintoma:** a proteção contra "apagar sem o cliente pedir" passa em todos os testes e mesmo
assim apaga.

**Causa raiz:** os testes exercitavam **comandos** ("tira o X", "troca o X pelo Y"). Ninguém
testou **perguntas**. A regex de intenção de troca casava `melhor\s+[oa]` e `muda|mudar`, então
`"melhor a G ou a M?"` e `"muda alguma coisa se eu pedir sem cebola?"` — perguntas comuns, sem
intenção nenhuma de remover — **autorizavam a exclusão**. Pior: o cliente em dúvida entre
tamanhos é exatamente o turno em que o LLM mais erra o estado desejado. A guarda desligava
justamente quando era mais necessária.

**Solução:**
1. Teste a guarda com o corpus que ela vai encontrar de verdade: perguntas, comparações,
   dúvidas, bordões ("não, pera..."), negações ("nunca tira X"), e a palavra dentro de outra
   palavra ("Cola" dentro de "e**scola**" — case por `\b`, nunca por substring).
2. Autorize **por item**, não por mensagem: um "tira o X" legítimo não pode liberar um corte no
   Y que ninguém pediu.
3. Exija desambiguação quando o alvo é ambíguo: com dois tamanhos do MESMO prato no carrinho,
   nomear o prato não identifica a linha — peça o tamanho.
4. Escolha o lado para o qual a guarda falha, e escreva isso no código. Falhar **fechado**
   (perguntar sem precisar) custa um turno de conversa; falhar **aberto** (apagar) custa o
   dinheiro do cliente. Endureça só o lado aberto e **documente o custo aceito**, senão o
   próximo leitor "conserta" o que era deliberado.

**Ref:** tiatendo, `execution/engine/restaurantCartDiff.py` (2026-07-29), commits `51784a2`
→ `5571ba7`. Três rodadas de revisão, três furos, todos no desenho — nenhum no código gerado.

## Contrato que manda o LLM REPETIR o estado inteiro copia da fonte errada quando há histórico {#contrato-declarativo-copia-do-historico}

`tags: llm, contrato declarativo, histórico, janela de contexto, alucinação, prompt, medição, isolar variável, recorte por tempo, lastro`

**Sintoma:** um contrato declarativo ("devolva o estado desejado COMPLETO, repetindo o que
permanece") passa a inventar itens quando a janela de contexto tem histórico de conversa. Um "oi bom
dia" cria um pedido de 3 itens; uma frase de encerramento adiciona um produto.

**Causa:** o prompt tem DUAS fontes do estado — o bloco estruturado autoritativo (`PEDIDO ATUAL:
(vazio)`) e as mensagens anteriores, onde o próprio bot RECITOU o estado ("Seu pedido: 1× X — R$ 80").
A instrução "repita o que permanece" não diz de ONDE repetir, e o modelo resolve a contradição
copiando do texto conversacional. Se a busca de histórico não tem recorte de TEMPO, a sessão de
ontem entra na janela de hoje.

**Como medir (isole UMA variável):** mesmo turno, mesmo estado, N rodadas, variando só o histórico.

    history=None            3/3 correto
    history=COMPLETO        3/3 alucina
    history=SÓ DO USUÁRIO   3/3 alucina — e de forma ESTÁVEL

🪤 **Filtrar por PAPEL não resolve, e engana.** As mensagens do usuário são justamente as que
NOMEIAM as entidades; tirar as do bot deixa o resultado determinístico, o que num teste parece
*mais estável* e continua 100% errado. O que resolve é o recorte por TEMPO, ancorado na vida do
objeto em edição (o rascunho/sessão), não num número de mensagens.

🪤 **Recorte por tempo não cobre o caso da MESMA sessão.** Se a alucinação nasce de um histórico de
minutos atrás, nenhum recorte razoável a remove — só uma guarda no lado da escrita. Subir só o
recorte faz o defeito sumir dos casos fáceis e **parecer resolvido**, que é pior que o estado
anterior, onde pelo menos se sabia que estava quebrado.

**Guarda no lado da escrita:** exigir LASTRO no turno para cada mutação. Cuidado com a assimetria
que engana: se a mutação tem uma dimensão de QUANTIDADE, um lastro booleano sobre a ENTIDADE não
fecha buraco nenhum — o modelo aluciná o número com a entidade corretamente nomeada. O lastro
precisa amarrar entidade **e** número, e o excesso deve ser CORTADO ao justificado em vez de
recusado inteiro.

Relacionado: {#fail-open-esconde-teste-vacuo}, {#strict-schema-campo-sem-instrucao}.

## `xfail` que sempre xpassa é pior que teste nenhum {#xfail-que-xpassa-anuncia-defeito-que-nao-demonstra}

`tags: pytest, xfail, golden, llm, fixture, medição, assert fraco, teste vácuo`

**Sintoma:** você mede um defeito em produção, escreve o teste que o captura, marca `xfail` com a
evidência no `reason`… e ele **xpassa**. Aí você enriquece a fixture pra reproduzir, e ele xpassa de
novo.

**O que fazer:** TIRAR a marca. Um `xfail` que nunca falha anuncia um defeito que ele não demonstra
— quem ler o `reason` vai acreditar que o caso está coberto e monitorado, e não está. A evidência
de produção vai pro documento que gente lê (PLANO/HANDOFF/spec), e o teste fica asserindo só o que
de fato prova, com o limite escrito no docstring.

🪤 O motivo mais comum de não reproduzir é a **fixture pequena demais**: uma confusão entre entidades
vizinhas precisa da densidade do catálogo real (dezenas de itens que compartilham token e rótulo).
Com 6 ou 9 itens o modelo acerta.

Regra irmã, e vale mais que a economia de um teste vermelho: **nunca enfraquecer um assert para
acomodar variância de LLM**. Golden que reprova vira `xfail` com motivo ESCRITO e frente própria —
jamais um `>=`, um `in`, ou uma tolerância "por robustez". Foi um `>= 1` "por robustez" que deixou um
pedido de 3 itens chegar ao banco com 2.

## Rota que ainda não existe devolve 404 — e isso deixa o teste VERDE sem implementação {#rota-inexistente-deixa-teste-verde}

`tags: tdd, fastapi, 404, teste vácuo, mutação, fase vermelha, escopo multi-tenant, idempotência`

**Sintoma:** você escreve o teste do endpoint antes do endpoint, roda a fase vermelha e ele
**passa**. Não é sorte nem cache: o framework devolve **404 para rota ausente**, e o banco fica
intacto porque nada rodou. Justamente os testes mais rigorosos são os que caem nessa.

Três numa sessão só (Plexco Tasks, s155):

| O teste | Por que ficou verde sem código |
|---|---|
| escopo de org (`assert status == 404`) | rota ausente **também** dá 404 |
| idempotência (`primeira == segunda`) | os 2 POSTs deram 404 e os dois lados eram `None` |
| atomicidade ("nada mudou de projeto") | nada mudou porque **nada rodou** |

**O que fazer, em ordem de força:**

1. **Prova por mutação.** Apague a linha de produção que o teste deveria proteger e confirme que ele
   cai; reponha. Numa delas, trocar o filtro de organização por um `select` sem filtro matou
   **exatamente** o teste de escopo e nenhum outro — é esse sinal que você quer ver.
2. **Assere o contrato observável** — `(status, corpo)` — em vez do estado final. `200 +
   {"cancelled": false}` distingue no-op limpo de erro engolido; "o carimbo não mudou" não distingue.
3. **`assert_not_awaited`** na chamada externa quando há fail-open: "não chamou" e "chamou e falhou"
   produzem a mesma saída.

Relacionado: {#fail-open-esconde-teste-vacuo}, {#xfail-que-xpassa-anuncia-defeito-que-nao-demonstra}.

## Magic-link mintado server-side morre no consume: `context_mismatch` {#magic-link-server-side-context-mismatch}

`tags: auth, magic-link, whatsapp, webhook, device fingerprint, context_mismatch, precedente`

**Sintoma:** o produto manda um magic-link por um canal assíncrono (WhatsApp, e-mail de worker) e o
usuário clica minutos depois: **"link expirou ou já foi usado"**. Não é TTL, não é preview do
mensageiro consumindo o código de uso único — o log do auth-service diz `outcome=context_mismatch`.

**Causa:** o auth-service **vincula o magic ao IP/UA de quem o mintou** (device fingerprint). Num
caminho que responde a webhook não existe browser no instante da emissão, e não há
`forwarded_for`/`user_agent` do usuário para propagar. O fingerprint do container nunca vai bater
com o aparelho de quem clica. Só funciona quando quem minta é a request do próprio browser.

**O que fazer:** mandar o **link simples** para a tela de destino. Quem tem sessão longa entra
direto; quem não tem cai no login — e o login precisa preservar o destino (`?next=`, com guard de
path relativo). Magic que falha é **beco sem saída**: a página de erro é do auth-service e não
conhece o destino, então o usuário perde o objeto de vista.

🪤 **A lição que custou mais que o bug:** o plano citava um call-site existente como prova de que o
padrão funcionava — e a **docstring daquele próprio call-site** avisava que ele falha
`context_mismatch` nesse cenário. **Precedente que EXISTE não é precedente que FUNCIONA**; ler as
três linhas do docstring custava menos que o deploy.

Relacionado: {#rota-inexistente-deixa-teste-verde}.

---

## Depois de um `DROP TABLE`, "voltar a tag" não é rollback {#drop-table-rollback-pareado}

`tags: rollback, drop table, migração, alembic, deploy, swarm, docker service update, container saudável, 500 no request, gate negativo, pg_dump`

**Sintoma:** você reverte a imagem para o pin anterior, o `docker service ls` mostra `1/1`, o
healthcheck passa — e o cliente vê 500 numa tela específica.

**Causa:** a imagem anterior lê a tabela que a migração dropou. Isso **não quebra no boot** (não é
erro de import, não é conexão) e **não quebra a suíte** (que usa banco fake). Só falha no request.

**O que fazer:**

1. Escreva o rollback **pareado** no `docker-compose.swarm.yml`, junto do pin — é o arquivo que quem
   reverte abre: `alembic downgrade <rev-anterior>` **ANTES** do `docker service update`.
2. `pg_dump -t <tabela>` **antes** de aplicar, e diga no docstring que o downgrade recria a
   **estrutura**, não as linhas. Prometer rollback completo é mentira silenciosa.
3. **Gate negativo na imagem**: `grep -r` provando que o nome da tabela **não está** no artefato.
   Verifique que ele **reprova a imagem anterior** — gate que passa em tudo não prova nada.
4. Ordem de deploy: **código primeiro** (que já não lê), migração depois.

Aplicado em 2026-07-29 (Paid Media, fatia 0028).

---

## Defeito que o serviço remoto ACEITA é latente, não risco {#defeito-latente-aceito}

`tags: defeito latente, dado malformado, httpx, ReadTimeout, str(exc) vazio, mensagem de erro vazia, espaço em identificador, normalizar na porta, string vazia vs None, medir antes de classificar`

**Sintoma:** você acha um dado malformado em produção (um id com espaço, um corpo de erro vazio) e
classifica como risco. Ninguém nunca reportou nada.

**Causa:** o serviço remoto tolera. **Não há incidente, não há alerta, e ninguém investiga um envio
que funciona** — o defeito espera o dia em que outra ponta compara por igualdade.

**O que fazer:** **meça antes de classificar.** Dois casos medidos no mesmo dia:

- `fetch_error:` gravando corpo vazio — **8 de 8 registros em 30 dias**, porque as exceções de rede
  do `httpx` (`ReadTimeout`, `ConnectTimeout`, `ConnectError`, `RemoteProtocolError`) são levantadas
  **sem argumento** e `str(exc)` é `""`. Grave sempre o **tipo** da exceção, mesmo quando há
  mensagem: corpo vazio não é só inútil, é **ambíguo** (não se distingue de "o servidor respondeu
  vazio").
- `meta_pixel_id` com espaço à esquerda — **o Meta aceitou**, 7 de 7 eventos recebidos. Latente, não
  quebrado. Normalize **na porta** (o dado sujo não chega a existir) e faça `"   "` virar `None`,
  nunca `""`: vazio numa coluna que o dispatch lê significa "configurado com nada" e monta URL sem
  id; `None` significa "não configurado", que é o que tela e monitor sabem ler.

Relacionado: {#drop-table-rollback-pareado}.

---

## `docker exec` sem `-i` engole o stdin — e vazio parece resposta {#docker-exec-stdin}

`tags: docker exec, stdin, heredoc, psql, resultado vazio, falso negativo, linha de controle, CRLF, git bash, VPS`

**Sintoma:** você roda uma checagem via heredoc (`docker exec pg psql -f /dev/stdin <<SQL`) e o
retorno vem **vazio**. Vazio parece "não há dependências", "não há linhas", "está limpo".

**Causa:** sem `-i`, o `docker exec` não conecta o stdin; o `psql` lê EOF e não executa nada. O
comando retorna 0.

**O que fazer:** `docker cp` do arquivo `.sql`/`.py` e execute por caminho — e **inclua sempre uma
linha de CONTROLE** no output (`SELECT 'CONTROLE: total='||count(*)`). Se ela não aparecer, o vazio
era do canal e não do banco. Corolário: script enviado de máquina Windows chega com **CRLF** e o
bash da VPS morre com `$'\r': command not found` — rode do worktree clonado pelo git, não do arquivo
enviado.

---

## `service update` diz "converged" mas o serviço continua na imagem VELHA (rollback silencioso) {#swarm-converged-e-rollback}

`tags: docker swarm, service update, converged, rollback_completed, UpdateStatus, healthcheck, CRLF, entrypoint.sh, exec no such file or directory, shebang, no-resolve-image, force, deploy, windows, tar, gate de imagem`

**Contexto:** deploy de imagem construída no próprio VPS (sem registry). `docker service update --image ... --no-resolve-image` respondeu `verify: Service X converged` — e o serviço continuou rodando a tag antiga, com a task de 3 horas atrás intacta. `--force` também "convergiu" sem trocar nada.

**Causa raiz:** o swarm SUBIU a task nova, ela reprovou no healthcheck, ele reverteu, e a mensagem `converged` é sobre **o rollback ter convergido**, não sobre o update ter dado certo. O sinal está em `docker service inspect X --format "{{.UpdateStatus.State}}"` → **`rollback_completed`**. `docker service ls` mostra a imagem do spec vigente (a velha), o que reforça a ilusão de que o comando não foi executado.

**Por que a task nova morria:** `exec /usr/local/bin/entrypoint.sh: no such file or directory` — o arquivo EXISTE. O shebang estava `#!/bin/sh` seguido de CR+LF, então o kernel procurava um interpretador com `\r` no nome. O contexto de build tinha sido empacotado no Windows. Diagnóstico: `file entrypoint.sh` → *"with CRLF line terminators"*, ou `head -c 20 entrypoint.sh | od -c` mostrando o `\r`.

**Fix:** `sed -i "s/\r$//" entrypoint.sh && chmod +x entrypoint.sh` no contexto, rebuildar. Varrer o contexto inteiro em busca de outros `.sh` com CR antes.

**Duas armadilhas que amplificam:**
1. **Gate de conteúdo não vê fim de linha.** Seis gates do tipo `docker run --entrypoint sh <img> -c "test -f ... && grep -q ..."` passaram TODOS na imagem morta. O único gate que pega é **subir o container e bater no health**: `docker run -d --env-file <env real> --network <rede real> <img>`, esperar ~20s, `docker ps --format "{{.Status}}"` (tem que dizer `healthy`) + `curl -sf localhost:8000/health`. Fazer isso ANTES do `service update`, sempre.
2. **Serviço SEM healthcheck aceita a imagem morta em silêncio.** O serviço irmão (worker ARQ, sem healthcheck) engoliu a mesma imagem quebrada e reportou `1/1` + `completed`. Ou seja: o serviço que tinha healthcheck protegeu mentindo "converged"; o que não tinha desprotegeu dizendo a verdade. **Depois de qualquer deploy, confira `UpdateStatus.State == completed` E `service ps` mostrando task nova ("Running N seconds ago"), serviço por serviço.**

**Env real sem vazar segredo:** `docker inspect <container-rodando> --format "{{range .Config.Env}}{{println .}}{{end}}" > /tmp/x.env` e usar `--env-file`. A rede certa vem de `docker inspect <container> --format "{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}"` — chutar `<stack>_default` falha (aqui era `network_swarm_public`).

**Ref:** Paid Media Automation, deploy `crm-140bebb` (2026-07-29). Relacionado: [imagem local sem registry](#swarm-local-image-resolve), [build pipe mascara exit](#deploy-pipe-mascara-exit).

---

## `alembic upgrade head` não vê a migration nova: ela mora DENTRO da imagem {#alembic-head-mora-na-imagem}

`tags: alembic, migration, docker, deploy, ordem de deploy, upgrade head, docker cp, aditiva, rollback nao pareado, imagem, base64, md5`

**Contexto:** plano de deploy dizia "aplicar a migration ANTES da imagem" (correto em princípio: com a imagem nova primeiro, o código escreve numa tabela que ainda não existe e loga `relation does not exist` a cada tick). Rodei `docker exec <container-prod> alembic upgrade head` → **nenhuma saída, e `alembic current` continuou na revisão anterior**.

**Causa raiz:** o arquivo `versions/NNNN_*.py` é COPIADO para dentro da imagem no build. O container em produção roda a imagem ANTIGA, que não contém a revisão nova — para o alembic dela, a revisão anterior **é** o head. Não há erro: ele "aplica tudo até o head que conhece", que é nada. `alembic heads` confirma (mostra a revisão velha).

**Fix (quando a migration é ADITIVA):** injetar só o arquivo no container em execução e rodar ali —
`docker cp NNNN_x.py <container>:/app/alembic/versions/` → `docker exec <container> sh -c "cd /app && alembic heads && alembic upgrade head"`. É inócuo porque a imagem antiga não lê o objeto novo. O arquivo some no próximo deploy, quando a imagem nova já o traz.

**Transferir o arquivo sem SFTP/registry:** base64 em blocos por SSH e conferir MD5 dos dois lados — fatiar em ~20k chars, `printf "%s" "<chunk>" >> f.b64`, `base64 -d f.b64 > f.py`, `md5sum`. Sem o MD5 você não sabe se truncou.

**Se a migration NÃO for aditiva** (drop/alter destrutivo), o `docker cp` não resolve: aí a ordem é imagem→migration e você aceita a janela de erro, ou para o serviço. E lembre que `DROP` torna o rollback **pareado** — ver [rollback pareado](#drop-table-rollback-pareado).

**Conferir sempre em `information_schema`/`pg_constraint`, nunca na saída do alembic.**

**Ref:** Paid Media Automation, migration `0029_crm_signal_state` (2026-07-29).

---

## CHECK bicondicional ACEITA a linha proibida quando o discriminante é NULL (UNKNOWN passa) {#check-bicondicional-unknown}

`tags: postgres, check constraint, three-valued logic, UNKNOWN, NULL, IS DISTINCT FROM, pg_constraint, conrelid, conname, idempotente, migration, mutation testing, invariante estrutural, schema`

**Contexto:** constraint escrita para tornar um invariante impossível de violar ("contagem existe SE E SOMENTE SE o estado é 'medido'"), porque a regra em código dependia de alguém lembrar de checá-la.

```sql
CHECK ( (state = 'medido'  AND count IS NOT NULL)
     OR (state <> 'medido' AND count IS NULL) )
```

**Causa raiz:** com `state = NULL` os dois ramos avaliam **UNKNOWN**, e `UNKNOWN OR UNKNOWN = UNKNOWN` — e **CHECK só rejeita quando o resultado é FALSE**. A linha proibida entra. A "totalidade" do bicondicional estava delegada ao `NOT NULL` da coluna, que vive em OUTRO statement — e num `CREATE TABLE IF NOT EXISTS`, justamente o que pode ser pulado numa reaplicação.

⚠️ **`IS DISTINCT FROM` NÃO resolve:** `state IS DISTINCT FROM 'medido'` com NULL dá `UNKNOWN OR FALSE = UNKNOWN`, também aceito.

**Fix:** tornar o CHECK auto-suficiente — `CHECK (state IS NOT NULL AND ( ...os dois ramos... ))`. Custo zero, e a barreira deixa de depender de cláusula alheia.

**Segundo furo na mesma migration — a guarda de idempotência:**

```sql
IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_x') THEN ALTER TABLE ...
```

`conname` é único por **TABELA**, não por banco. Com dois schemas no mesmo banco (ex.: `tracking` + `public`, `search_path` cobrindo os dois), a guarda casa a constraint da OUTRA cópia, **pula o ADD e a migration reporta sucesso com a tabela sem o CHECK**. Fix: `AND conrelid = 'tabela'::regclass`.

**Como os dois foram achados (é isto que replicar):** nenhum apareceu em leitura nem em review de prosa. Apareceram em **mutation testing** — remover cada conjunto do CHECK e rodar a suíte. 5 de 8 mutações passavam VERDES. A prova final foi executar o DDL contra um `postgres:17` efêmero e ver o banco **recusar** as 7 linhas ilegais; depois remover o CHECK e ver 5 testes ficarem vermelhos. Guarda que ninguém viu reprovar não é guarda. Ver [Postgres efêmero para testes destrutivos](#pg-efemero-testes-destrutivos).

**Bônus da mesma frente — teste-espelho satisfeito pelo DOCSTRING:** testes que afirmam sobre o TEXTO do arquivo (`assert "coluna" in SRC`) são satisfeitos pelo cabeçalho de documentação, que costuma listar exatamente as mesmas colunas/constraints. Remover uma coluna do `CREATE TABLE` passava VERDE. Quanto melhor o docstring, mais cego o teste. Fix: recortar o alvo antes de afirmar (`SRC.split("CREATE TABLE ...")[1].split(chr(34)*3)[0]`) e prender o TIPO junto do nome.

**Ref:** Paid Media Automation, `crm_signal_state` (2026-07-29).

---

## 404 "por design" transforma erro de tenancy em bug invisível {#404-por-design-esconde-tenancy}

`tags: multi-tenant, organization_id, 404 vs 403, enumeration, org homonima, RF-17, escopo de org, identity_id, membership, link compartilhavel, deep-link, diagnostico`

**Contexto:** um recurso org-scoped devolve **404 tanto para "não existe" quanto para "existe em outra
org"** — decisão de segurança correta e comum (403 confirmaria a existência do recurso alheio, virando
oráculo de enumeração). Um link legítimo, mandado por WhatsApp/e-mail ao próprio dono do dado, falhava
para sempre com "não encontrado".

**Causa raiz:** **três organizações com o MESMO nome de exibição** ("Hub Operacional"), criadas em
horas diferentes e distinguíveis só pelo `slug` — e um deles nem parecia (`ads4pros`). O canal de
entrada (webhook de WhatsApp) resolveu o remetente por **telefone** e gravou na org A; o browser da
mesma pessoa loga por **e-mail**, numa identidade diferente, com membership só na org B. Duas linhas
de `users` para o mesmo humano, `identity_id` distintos, nenhuma interseção.

**Por que ninguém viu antes:** a UI mostra o **nome** da org, não o id. Três orgs homônimas são
indistinguíveis na tela, no switcher e no log. E o 404 correto por segurança é lido pelo time como
"o dado sumiu" ou "o link expirou" — não como "você está na org errada". A tela ainda dizia *"tente
recarregar a página"*, conselho que nunca resolveria.

**Diagnóstico (a ordem que funciona):**
1. Chamar o endpoint **direto pela API**, com o token do browser, e confirmar o status cru
   (`404 {"detail":"..."}`) — separa problema de front de problema de escopo.
2. `GET /me/organizations` → qual é a org **ativa** e quais a identidade alcança.
3. No banco: `SELECT id, name, slug, created_at FROM organizations WHERE name ILIKE '<nome>'` —
   **é aqui que os homônimos aparecem**; sem este passo você fica procurando bug de código.
4. `SELECT organization_id, identity_id, email, phone FROM users WHERE identity_id = '<iid do JWT>'` vs
   o `user_id` gravado no recurso. Se não houver interseção, o 404 é **permanente**, não timing.

**Fix (dois níveis):**
- **Produto:** link org-scoped deve carregar contexto de org (ou o login deve cair na org que dona o
  recurso). E o front tem que ramificar em `status === 404` com mensagem honesta + saída ("ir para X"),
  em vez de "recarregue".
- **Dado:** consolidar homônimos, ou dar membership. E **proibir orgs com nome idêntico** — ou pelo
  menos exibir o `slug` no switcher quando houver colisão de nome.

⚠️ **Corolário para allowlists por org:** ligar uma feature para `ORG_A,ORG_B` quando o operador só
navega em `ORG_A` faz a feature "funcionar em produção" e ser **invisível para quem testa**. O
registro de deploy dizia "as 2 orgs do operador" — e uma delas não era acessível a ele.

**Ref:** Plexco Tasks s156 — tela da leva `[4-C]` travada 1 sessão inteira por isto, atribuído a
"falta o operador abrir".

---

## "Camada velha" que a camada nova referencia N vezes não está velha — está pendente de migração {#camada-velha-ainda-apontada}

`tags: refactor de estrutura, camada legada, arquivar, .archive, git mv, migracao de canon, v1 v2, ponteiro cruzado, casca fina, medir antes de mover, aposentar documento`

**Sintoma:** você move a "camada antiga" pra `.archive/` (ou renomeia/deprecia), o `git mv` roda
limpo, os testes passam — e o resultado é um diretório chamado *archive* que a camada nova precisa ler.
No caso real, o `README` recém-escrito dizia "nada em `.archive/` é lido por agente" enquanto o índice
do canon **novo** apontava pra lá. Contradição na mesma árvore, criada pelo próprio commit.

**Causa raiz:** confundir **substituído** com **antigo**. Um documento só está aposentado quando
existe destino vivo para o que ele responde. Se a camada nova ainda aponta pra ele, a camada nova é
uma **casca fina**: ela roteia, mas o conteúdo continua do outro lado.

**Solução — meça antes de mover.** Conte os ponteiros vivos por destino, excluindo registro histórico:

```bash
git mv <camada-velha> .archive/  # faça o move num branch, so pra medir
git diff | grep "^+" | grep -o "archive[/\\][A-Za-z0-9_./-]*" | sort | uniq -c | sort -rn
```

Zero ponteiro = aposentadoria de fato, siga. Dezenas = **o move é o erro**: o trabalho real é migrar
conteúdo (reescrever no formato novo), e isso é uma fase por bloco, não um commit. Reverta o move,
guarde o patch, e corrija só o **roteamento** (quem entra primeiro), declarando a camada como
"pendente de migração" com o número medido — assim ninguém tenta o atalho de novo.

Sinal de que você está no atalho errado: a varredura de referências fica enorme (dezenas de arquivos)
e você começa a reescrever ponteiro de skill, template e hook pra apontar pra dentro de `archive/`.

**Ref:** kit Percus 2026-07-29 — 89 ponteiros vivos (`01_REGRAS` 25×, `02_INFRA` 17×), incluindo o
`v2/referencia/README.md`; move revertido, virou fase de migração de conteúdo. Relacionado:
[[regra-duplicada-ps1-sh]].

## Guarda que lê o FONTE some junto com a string que ela procura {#guarda-fonte-strip-string}

tags: teste-guarda, guarda estrutural, regex no source, tokenize, docstring, falso-negativo,
mutation testing, anti-regressão, python, ast, teste-espelho

**Sintoma.** Você escreve um teste-guarda que lê o código-fonte e reprova a reintrodução de um
padrão proibido. Ele passa. Você reintroduz o defeito de propósito — e **ele continua passando**.
Falso-negativo silencioso: a guarda existe, dá verde, e não guarda nada.

**Contexto.** Guarda de fonte quase sempre precisa ignorar comentário e docstring, senão ela reprova
pela **explicação** do defeito que mora ao lado do código (e a reação natural de quem vê o vermelho é
apagar a documentação para "consertar"). A forma óbvia de ignorar é tokenizar e descartar
`tokenize.COMMENT` e `tokenize.STRING`.

**Causa raiz.** O padrão proibido normalmente **contém uma string literal** — `headers.get("referer")`,
`os.environ["PROD"]`, `execute("DROP ...")`. Descartar todo token `STRING` remove justamente o
argumento que a regex procura. A guarda passa a olhar `headers . get ( , )`.

Uma segunda armadilha na mesma família: reconstruir o fonte por `tok.line` **não** remove nada —
`.line` devolve a **linha física inteira**, então o comentário volta de carona em qualquer outro token
da mesma linha.

**Solução.**
1. Reconstrua a partir de `tok.string`, nunca de `tok.line`.
2. Descarte `COMMENT` sempre, mas descarte `STRING` **só quando for docstring** — string sozinha numa
   linha lógica: o token significativo anterior é `NEWLINE`/`NL`/`INDENT`/`DEDENT`/`ENCODING` e o
   seguinte é `NEWLINE`. String usada como **argumento** fica.
3. **Prove por mutação, sempre:** reintroduza o defeito, veja o vermelho, restaure, veja o verde.
   E prove o outro lado: confirme que a guarda **passa** com o comentário explicativo presente.
   Guarda que nunca foi vista reprovando não é guarda — e esta classe de defeito só aparece assim.

**Ref.** Achado em 2026-07-29 em `Paid Midia Automation`, `services/tracking/tests/test_guarda_referer_header.py`
(guarda contra a volta do fallback do header `Referer`). Ver também `#red-nunca-visto-embarca-fossil`.

## Preflight CORS recusado: o serviço fica verde e só o browser do usuário quebra {#preflight-cors-falha-silenciosa}

tags: cors, preflight, OPTIONS, CORSMiddleware, access-control-allow-origin, origin recusada,
400 Disallowed CORS origin, curl esconde, healthcheck verde, falha invisivel, browser bloqueia

**Sintoma.** "Os usuários não conseguem entrar" / "o app não fala com o serviço central" — enquanto
todo monitor diz que está tudo bem: serviço `healthy`, `/health` 200, log do serviço limpo, backend
próprio intacto, build e testes do frontend passando.

**Causa.** O `CORSMiddleware` está recusando a origin: `OPTIONS` (preflight) devolve
`400 Disallowed CORS origin` **sem** `access-control-allow-origin`. O browser bloqueia antes de
enviar o body — nenhuma request chega ao handler, então **nada erra em lugar nenhum que se monitore**.
`curl` normal esconde: sem `Origin` + `Access-Control-Request-Method` você recebe 200 e conclui que
está bem.

**Diagnóstico (2 comandos).**
```bash
# 1) o preflight real
curl -s -o /dev/null -w "%{http_code}" -X OPTIONS <url> \
  -H "Origin: <sua-origin>" -H "Access-Control-Request-Method: POST"     # 200 esperado; 400 = recusada

# 2) o CONTROLE — uma origin de OUTRO produto que você sabe que funciona
#    passa? => a lista está recortada.  falha também? => o middleware/serviço é que quebrou.
```
No browser, da origin real: `fetch(...)` com `TypeError: Failed to fetch` **sem status** = bloqueado
no preflight; com status legível = chegou.

**Correções.** A causa mais comum é env sobrepondo o default versionado do código
(`CORS_ALLOWED_ORIGINS` no service spec). Estado correto costuma ser **sem** o env:
`docker service update --env-rm CORS_ALLOWED_ORIGINS <servico>`.

**Duas armadilhas que custaram horas (caso real 2026-07-30, 6 produtos fora por ~11h):**

1. **Falso-verde por população errada.** O smoke de CORS de um dos produtos rodou durante o incidente
   e devolveu **15/15 verde** — foi reportado como prova de saúde. Ele não errou no que mediu: mediu
   **só os origins dele**. O modo de falha perigoso de um smoke não é errar um item, é **acertar todos
   os itens da lista errada e imprimir PASS**. Regras: mudança em serviço compartilhado se verifica
   pela lista do **dono do serviço**; lista vazia é **FATAL**, nunca "0/0 passou"; exigir `ACAO`
   **ecoando a origin** (`*` deve reprovar — com `Authorization` o browser recusa wildcard).
2. **Gate pós-deploy não cobre regressão que chega sem deploy.** O incidente entrou por um
   `docker service update` disparado de fora, num dia sem deploy do serviço. Um gate pós-deploy teria
   ficado mudo o incidente inteiro. Cobertura real exige verificação **periódica**.

**Corolário.** Resposta de erro (401/422) **sem** `ACAO` quando a origin é permitida é sintoma do
mesmo bug, não comportamento separado do middleware — e enquanto durar, o cliente **não consegue
distinguir "sessão morta" de "falha de rede"**, o que quebra qualquer regra do tipo "só descarte o
refresh token em 401".

---

## A mutação sobreviveu: o código está certo e a prova de que precisa estar não existe {#mutacao-sobrevive-predicado-quase-certo}

tags: mutation testing, mutacao sobrevive, predicado quase certo, cobertura cega, OPEN_CONDITION,
enfraquecer predicado, prova por mutacao, dado que nao distingue, TDD

**Sintoma.** Você escreve o teste antes do fix (vermelho), aplica o fix (verde), e por hábito roda a
prova por mutação. Mas em vez de só **apagar** a linha de produção, você a troca pelo **"quase
certo"** — um predicado mais fraco que resolve o mesmo caso. E a suíte **continua verde**.

**Caso real (Plexco Tasks, s157, RF-9).** O `GET /levas/{id}` passou a excluir tarefa terminal pelo
predicado canônico `OPEN_CONDITION` (`completed_at IS NULL AND cancelled_at IS NULL`). Dois testes
novos, escritos antes do fix, tinham falhado pelo motivo certo. Trocando `OPEN_CONDITION` por
`completed_at IS NULL` sozinho: **11 passed**. A mutação não morreu.

**Por quê.** O caminho que os testes exercitavam (`mark_terminal(cancelled=True)`) carimba **os
dois** marcadores. Então, para aqueles dados, os dois predicados são indistinguíveis. O código
escolhido estava certo — e o teste não sabia disso.

**Por que isso importa mais do que parece.** Um teste que não distingue o predicado correto do
"quase certo" **autoriza a simplificação errada no futuro**. A próxima pessoa olha
`completed_at IS NULL AND cancelled_at IS NULL`, acha redundante, simplifica, roda a suíte, vê verde
e commita. O defeito volta em dado legado ou em qualquer caminho que carimbe só um marcador.

**Como resolver.** Não basta apagar a linha: **enfraqueça** o predicado e veja se algo morre. Se
nada morrer, o buraco não é o código — é a cobertura. Feche com um teste que **semeie diretamente o
estado que só o predicado forte distingue**, mesmo que nenhum caminho de produção o gere hoje:

```python
meia_cancelada.cancelled_at = datetime.now(timezone.utc)
meia_cancelada.completed_at = None   # estado que o modelo PERMITE
```

Documente **no próprio teste** por que aquele estado importa (colunas nullable e independentes, +
a docstring do predicado canônico que diz checar as duas), senão alguém o apaga como "impossível".

**Regra prática.** Onde houver predicado canônico com mais de uma condição, a bateria de mutação
tem que incluir **cada condição removida isoladamente** — não só o predicado inteiro apagado.
Predicado composto com teste que só exercita o caso "ambos verdadeiros" é teste vácuo numa dimensão.

**Relacionado:** [#404-por-design-esconde-tenancy] (erro que parece feature) ·
[#guarda-fonte-strip-string] (guarda que some com o que procura).

---

## Sessão de 30 dias que "não persiste": como provar de que lado está o defeito {#sessao-30-dias-nao-persiste}

tags: refresh token, rotacao, sessao de 30 dias, re-OTP, cold start, descarte em falha transitoria,
clearTokens, delete_cookie, 401 e so, 422 RequestValidationError, rolling update, localStorage entre
abas, AbortController, auth-service, consumer

**Origem:** auth-service, 2026-07-25 → 07-30. Operador reportou re-OTP "em todos os projetos".
Resultado: **6 de 7 consumers** tinham o mesmo defeito, o auth estava correto.

### A métrica que decide (não use auditoria de código)

Auditoria de código dá **falso PASS**. A prova é a **rotação do refresh token em produção**. No
auth-service, via `scan_iter("auth:refresh:*")` + payload JSON de cada chave:

- **rotações** = tokens com `used_at` preenchido.
- **vida da família** = `max(created_at) - min(created_at)` da mesma família = quanto tempo aquela
  sessão se sustentou renovando.
- `parent_id=None` + `used_at=None` + 1 token = **família criada no login que nunca renovou**.

Leitura: vida mediana **0,0h** = o `rt` é emitido e nunca usado. Sessões de **20+ dias vivas** em
outro consumer = prova positiva de que o servidor está correto (use isso pra inocentar o auth em
vez de argumentar).

### Os dois defeitos que o checklist ingênuo não pega

1. **COLD START** — o refresh só existe no caminho reativo (interceptor de 401). No boot **não sai
   request nenhuma** → não há 401 → não há refresh → tela de login com o `rt` de 30 dias intacto no
   storage. "Renova no 401?" passa e a sessão morre assim mesmo.
   *Teste de 30s:* apagar **só o access token**, F5 com Network aberto. Tem que sair
   `POST /token/refresh` → 200.

2. **DESCARTE EM FALHA TRANSITÓRIA (o dominante)** — `clearTokens()` / `delete_cookie()` em
   **qualquer** não-2xx ou no `catch` de rede/timeout. Um 502 de 3s destrói a sessão de 30 dias.
   **Não vira incidente: vira "o pessoal anda relogando mais".** O gatilho mais comum é o **próprio
   rolling update do serviço de auth** (segundos de 502 no proxy), então atinge **todo mundo ao
   mesmo tempo**.
   *Regra:* descartar credencial **só** quando o servidor **confirma** sessão morta. No contrato
   Percus isso é **`401` e só** — `403` não é emitido nessa rota e **`422` é o
   `RequestValidationError` do FastAPI** (body malformado = drift de contrato). Com 422 na lista, o
   dia em que o schema mudar apaga a sessão de **todos os usuários de todos os produtos**.

3. **A segunda metade, que todo mundo esquece:** consertar o `doRefresh` preserva a credencial
   (resolve o **custo**), mas se o **chamador** tratar todo `null` como sessão morta o usuário
   continua sendo **expulso** pro `/login` (a **interrupção**). Exige as duas metades.

### Armadilhas de sinal (custaram bug real)

- **Não use "ainda existe refresh token?" como prova de falha transitória** — o interceptor pode ter
  **rotacionado** logo antes, e aí uma identidade rejeitada (conta desativada, token válido)
  rotacionaria pra sempre sem nunca deslogar. Use estado **por aba** (contador de refreshes OK).
- **`localStorage` é compartilhado entre abas** — "o token mudou?" é sinal contaminado, e uma aba
  parada reapresentando o `rt` velho **queima a família** da aba que acabou de renovar.
- Quem passar a **aguardar** o refresh no boot precisa de **timeout** (`AbortController`), senão
  troca re-OTP por tela branca. O abort conta como transitório.

---

## Auditar código de OUTRO repo: leia a ref publicada, nunca o working tree {#auditar-outro-repo-ref-publicada}

tags: auditoria cross-repo, working tree engana, evidencia circular, git show origin, ref publicada,
branch default nao e main, symbolic-ref, grep por stack, falso-negativo, retirada de suspeita

**Origem:** mesma sessão. Custou uma "retirada de suspeita" errada, que quase encerrou um defeito
real que estava deslogando usuário em produção.

O checkout local de outro projeto pode conter **trabalho em andamento de outra sessão**. Eu li o
working tree, vi o fix que o time estava escrevendo **em resposta ao meu próprio alerta**, e reportei
como prova de que o alerta era desnecessário — **evidência circular**.

- ✅ `git show origin/<ref>:<arquivo>` · ❌ abrir o arquivo do checkout.
- ⚠️ **A ref publicada nem sempre é `main`.** Num dos repos o `origin/main` era um snapshot antigo e
  a branch deployada era `origin/onda-minus-1/migracao-supabase`; noutro o default era `master`.
  Confirme com `git branch -r --contains <commit>` ou `git symbolic-ref refs/remotes/origin/HEAD`.
- Ao varrer um padrão em N repos, **greppe por stack**: `clearTokens|clearCookie` não acha Python
  (`delete_cookie`) — deu falso-negativo justamente no repo que tinha o bug.

---

## Config que só o browser vê: env stale sobrepondo o default do código {#env-stale-sobrepondo-default}

tags: env override, CORS_ALLOWED_ORIGINS, config apodrece, default no codigo, swarm, tasks recriadas,
falha silenciosa no servidor, TypeError Failed to fetch, smoke pos-deploy, OPTIONS por origin,
cross-product

**Origem:** P0 de 2026-07-30 — 11h com login quebrado em 6 produtos.

Um `CORS_ALLOWED_ORIGINS` explícito no env do Swarm sobrepunha o default do código (que era gerado,
versionado e completo) e recusava 7 origins. **A falha é silenciosa do lado do servidor:** serviço
`healthy`, log limpo, nada erra — quem quebra é o browser do usuário (`TypeError: Failed to fetch`,
porque o preflight volta 400 sem `access-control-allow-origin`).

- **Padrão:** env override de lista **apodrece**. Prefira o default no código (gerado de um manifesto
  versionado) e trate o env como escape hatch temporário.
- **Sintoma de que o env está mandando:** o valor efetivo do processo ≠ o literal do código. Leia o
  processo vivo, não o repo.
- **Gatilho comum:** a mudança de env só entra em vigor quando as **tasks são recriadas** — pode
  ficar meses armada e detonar num restart qualquer.
- **Cuidado cross-product:** o script de outro produto pode estar escrevendo no seu serviço. Procure
  o consumidor declarado (`grep -rl 'SEU_ENV' /opt /root --include='*.yml' --include='*.yaml'`).
- **Defesa:** smoke pós-deploy de `OPTIONS` por origin, esperando **200 + `ACAO`**. Transforma falha
  invisível em falha barulhenta.

**Relacionado:** [#preflight-cors-falha-silenciosa] — mesmo P0, visto do outro lado: lá está **como
diagnosticar** o preflight recusado; aqui, **por que o env chegou nesse estado**.

---

## Parser de "1/2" nascido numa pergunta numerada lê quantidade como sim/não no texto livre {#token-lista-numerada-vaza}

`tags: parser, sim/nao, yes/no, isYes, isNo, opcao numerada, lista numerada, texto livre, quantidade, numero da casa, falso positivo, helper reusado, opt-in, acao destrutiva, endereco apagado, par assimetrico`

**Origem:** tiatendo, 2026-07-31 — o bot descartou o endereço de um cliente porque ele pediu
"uma coca cola **2** litros".

Um parser de sim/não nasceu para uma pergunta com **opções numeradas** ("Responda: 1️⃣ Sim  2️⃣ Não")
e por isso tinha `"1"` em `_YES` e `"2"` em `_NO`. O mesmo helper passou a ser usado num fluxo de
**texto livre**, onde 1 e 2 não são opções — são quantidade, número de casa e nome de rua:

    isNo("quero uma coca cola 2 litros") -> True     isNo("rua 2 de setembro")  -> True
    isNo("apartamento 2")               -> True     isYes("1 marmita G")       -> True

- **A regra:** token de **opção numerada** só vale dentro da pergunta que **imprimiu a lista**. Fora
  dela, "2" é o número dois. Faça o modo numerado ser **opt-in** (`numbered=True`), nunca o default —
  assim o caller novo nasce seguro em vez de herdar a armadilha.
- **Como caçar:** não procure o helper; procure os **prompts numerados**
  (`grep -rn "1️⃣" --include=*.py`) e cruze com quem responde a eles. Depois varra os callers do
  helper no **repo inteiro** (inclusive `scripts/` e testes), não só no módulo.
- **Por que passa despercebido:** o dano não é exceção nem log — é uma decisão **plausível** tomada
  com a palavra errada. No caso medido, virou ação **destrutiva** (apagar endereço já coletado).
- **Espelho:** o mesmo projeto já tinha corrigido a direção oposta (o "1" do admin colidindo com a
  rotina matinal) e não olhou o outro lado. Corrigiu-se um lado do par assimétrico.

**Relacionado:** [Guarda contra ação destrutiva](#guarda-destrutiva-testar-com-perguntas) — aqui o token errado ALIMENTA um guard cuja reação
ao "não" é destrutiva; os dois juntos transformam um pedido de bebida em perda de dado.

---

## Fact-check da review marca finding REAL como "INFUNDADO" porque não conseguiu verificar {#fact-check-infundado-e-nao-verificado}

`tags: fact-check, F3, INFUNDADO, nao verificado, finding filtrado, review, cross-provider, deepseek, latest.jsonl, bloco Audit, falso negativo, escopo de mudanca, cp1252, PYTHONIOENCODING`

**Origem:** tiatendo, 2026-07-31 — 4 findings de review cross-provider filtrados numa sessão; **2
eram reais** e viraram código.

O pipeline de fact-check (F3) classifica findings e **remove do output principal** os que marca como
`INFUNDADO`. O motivo mais comum não é "a alegação é falsa" — é **"não foi possível verificar (sem
path verificável ou arquivo ausente)"**. São coisas diferentes, e o filtro trata igual.

- **A regra:** *"não consegui verificar"* ≠ *"infundado"*. **Sempre leia o bloco Audit** e os findings
  filtrados antes de commitar. O custo de ler 4 parágrafos é minúsculo perto do de perder o achado.
- **Onde ficam:** `.deepseek/reviews/latest.jsonl` (o campo `findings` traz o texto integral).
  ⚠️ No Windows, `print` estoura em `cp1252` — use `PYTHONIOENCODING=utf-8` +
  `sys.stdout.reconfigure(errors="replace")`.
- **Padrão dos que sobrevivem ao filtro:** findings sobre **escopo de mudança** ("você trocou a
  semântica de X, varreu todos os callers?") e sobre **ambiguidade de entrada** — justamente os que
  exigem olhar fora do diff, que é o que o verificador automático não consegue fazer.

**Relacionado:** [Review que aborta com binário](#revisor-aborta-com-binario) — outro jeito de a review sair vazia parecendo
limpa.

---

## Review volta vazia parecendo limpa: o revisor ABORTOU por causa de um binário no diff {#revisor-aborta-com-binario}

`tags: review, deepseek, abort, binario, mp3, asset, diff, review vazia, sem findings, falso verde, commit separado, codigo nao revisado`

**Origem:** tiatendo, 2026-07-31.

O revisor cross-provider (DeepSeek) tem regra de **recusar diffs que contenham binários**. Ao incluir
3 `.mp3` num commit, ele abortou a revisão inteira e devolveu **um único finding procedural** — o
código do mesmo commit **não foi revisado**, e o resultado tinha a aparência de uma review limpa.

- **A regra:** asset binário vai em **commit separado**. Código e binário no mesmo diff = código sem
  revisão, silenciosamente.
- **Sintoma:** review devolve só um finding falando do próprio binário/da própria regra, sem citar
  nenhuma linha de código. Isso é abort, não aprovação.

---

## Postgres reclama de "column X does not exist" onde X é um VALOR seu (aspas comidas pelo ssh) {#ssh-heredoc-come-aspas}

`tags: ssh, heredoc, aspas simples, single quote, shell quoting, postgres, UndefinedColumnError, column does not exist, asyncpg, psycopg, parametro, erro que parece de schema`

**Origem:** tiatendo, 2026-07-31 — ~20 min perdidos com um erro que não parecia de aspas.

`ssh host 'python - <<"EOF" ... EOF'` — o corpo vai dentro de uma string **single-quoted** do shell
local. Toda aspa simples do Python/SQL é **comida**, e `status='active'` chega ao servidor como
`status=active`. O Postgres então reclama:

    UndefinedColumnError: column "active" does not exist

que não aponta pra aspas em lugar nenhum — parece erro de schema.

- **A regra:** dentro de `ssh '...'`, nunca use literal de string com aspa simples. Passe valores como
  **parâmetros** (`$1`, `$2` no asyncpg / `%s` no psycopg) ou use aspas duplas no Python.
- **Sintoma-assinatura:** o banco reclama de uma **coluna com o nome do seu valor**. Se o "nome da
  coluna" do erro é um dado seu, são as aspas.

---

## Lição escrita em prosa não impede reincidência — o conserto tem que morar num gate {#licao-em-prosa-reincide}

`tags: e2e, playwright, teste que escreve em producao, afterEach, globalTeardown, cleanup, licao aprendida, post-mortem, reincidencia, dado de cliente, lixo de teste`

**Origem:** Família Milionária, 2026-07-28 → 2026-07-31 (a mesma falha, duas vezes, a segunda pior).

Em 28/07 o e2e autenticado deixou lixo em produção e o post-mortem registrou a lição certa: *"spec de
CRUD contra prod precisa de cleanup em `afterEach`, não no fim do corpo do teste"*. O lixo foi
limpo. **Em 31/07 aconteceu de novo, maior**: 62 lançamentos falsos somando R$ 162.000 na conta do
operador, contra R$ 84.000 de dado real — e **56 deles nem foram criados pelo teste**, foram
materializados pelo scheduler a partir de 4 recorrências que sobreviveram a um teste vermelho.

A lição estava escrita e mesmo assim reincidiu, porque **dependia de alguém lembrar**.

- **A regra:** quando a mesma falha reincide, não reescreva a lição — mude o lugar dela. Cleanup
  pertence ao **config** (`globalTeardown`, que roda passando ou falhando e cobre até spec que ainda
  não existe), não a um hábito por spec. Doc não é enforcement.
- **Ordem importa no sweep:** apague o **template de recorrência ANTES** dos lançamentos. Enquanto o
  template vive, o scheduler repõe o que você acabou de apagar.
- **O filtro que autoriza apagar em produção é o código mais perigoso do repo** — isole numa função
  própria, com teste próprio, afirmando contra os **nomes REAIS** do banco. Use `startsWith`, não
  `includes`: é a diferença entre limpar teste e destruir dado de cliente.
- **Sintoma-assinatura:** o dashboard do dono mostra dado com prefixo de teste; o volume do lixo
  supera o real; e a conta "cresce sozinha" entre rodadas (é recorrência materializando).
- **A doença por trás do sintoma:** suíte autenticada apontando pra **produção** com token de gente
  real. Cleanup é curativo; usuário de teste em faixa reservada é a cura.

---

## Alarme falso treina todo mundo a ignorar o alarme de verdade {#alarme-falso-mata-o-alarme}

`tags: playwright, globalTeardown, config.projects, --project, falso positivo, ruido, storageState, mtime, deteccao de rodada`

**Origem:** Família Milionária, 2026-07-31 — pego na própria verificação do fix acima.

A 1ª versão do teardown gritava *"🚨 ficou lixo em PRODUÇÃO"* ao fim de uma rodada
`--project=publico`, que **não cria nada**. Um alerta que dispara quando não há problema treina o
time a ignorá-lo — e foi assim que uma suíte morta passou 3 semanas despercebida.

- **Gotcha concreto:** `config.projects` no `globalTeardown` **NÃO** é filtrado por `--project` —
  numa rodada `--project=publico` ele ainda lista o `chromium`. Não serve pra saber o que rodou.
- **O sinal honesto:** o **mtime do `storageState`**. Só o `auth.setup` o escreve, e só o projeto
  autenticado depende dele; reescrito depois que o processo subiu = a rodada autenticada aconteceu
  agora. De quebra separa token expirado **antes** (nada rodou, nada criado) de expirado **no meio**
  (aí há lixo órfão, e o alarme é legítimo).
- **A regra:** antes de escrever um alerta, pergunte "quando ele dispara sem haver problema?". Se a
  resposta não for "nunca", ele nasce ruidoso e morre ignorado.

---

## O aviso promete o que o gate não entrega (promessa e decisão em módulos diferentes) {#promessa-e-decisao-separadas}

`tags: feature que mente, copy, enforcement, gate, bonus, acesso, paywall, billing, admin, classe de defeito`

**Origem:** Família Milionária — bot em 28/07, billing em 31/07. A **mesma classe**, em camadas diferentes.

O painel admin tinha um botão *bonificar* que estendia `familias.acesso_bonus_ate` e mandava no
WhatsApp *"🎁 sua família ganhou N meses de acesso bônus"*. Mas o **único** gate de acesso
(`familiaTemAcesso`, usado pelo 402 da API e pelo paywall do bot) lia só `Subscription.status`. O
campo era enfeite na listagem do admin. O usuário recebia a promessa e continuava bloqueado.

Três dias antes, no bot: o card dizia *"me diz o que tá errado pra eu corrigir"* e o handler só sabia
corrigir 3 dos 5 campos.

- **Onde procurar essa classe:** todo lugar que **escreve uma promessa** (copy, aviso, card, e-mail)
  sem que o mesmo commit toque o código que **decide**. Quando promessa e decisão moram em módulos
  diferentes (admin escreve, billing decide), nada acusa a divergência — nem tipo, nem teste.
- **Agravante:** o model até documentava a verdade (*"overlay visual — não altera a subscription"*),
  enquanto o texto ao usuário dizia o contrário. **Comentário honesto não conserta aviso mentiroso.**
- **Teste que pega:** afirme o EFEITO, não a escrita. "Depois de bonificar, o usuário CONSEGUE
  escrever" — não "o campo foi gravado".

---

## Mock de função de BANCO no arquivo de mocks de REDE → erro que não fala do seu problema {#mock-de-banco-em-arquivo-de-rede}

`tags: pytest, fixture, mock, outbound, FOREIGN KEY constraint failed, sqlite, uuid fake, harness de teste, erro enganoso`

**Origem:** Família Milionária, 2026-07-29 — mordeu 7 arquivos de teste antes de alguém arrumar a causa.

`tests/harness/outboundPatches.py` existe pra mockar o que sai pra **rede**. Alguém pôs ali
`catService.getOutrosId` — que é uma função de **banco** — devolvendo um UUID fixo
(`00000000-…-0001`) que não existe como linha. Resultado: todo teste que gravasse a entidade morria
com `FOREIGN KEY constraint failed`, um erro que **não menciona categoria nenhuma**.

Cada um dos 6 arquivos anteriores contornou localmente (re-mockando pro id real) em vez de remover o
mock. E um deles chegou a **abrir mão de uma asserção** por causa disso — a armadilha custou
cobertura, não só tempo.

- **A regra:** arquivo de mocks tem um escopo declarado. Função que não bate com o escopo não entra —
  e quando o contorno local aparece pela 2ª vez, o problema é a causa, não o contorno.
- **Sintoma-assinatura:** erro de integridade referencial que não cita a entidade que você está
  criando + vários arquivos de teste com o mesmo `monkeypatch` defensivo copiado.

---

## Ferramenta de monitoramento roda INERTE com os testes verdes: `source` de outro script clobrou o entry point {#source-clobra-entry-point}

`tags: bash, source, shell, funcao sobrescrita, main, monitor inerte, cron, teste unitario passa, falso verde, colisao de nomes`

**Origem:** auth-service, 2026-07-30 — o vigia de CORS subiu quebrado e só apareceu ao rodar na VPS.

`cors-watch.sh` faz `. cors-smoke.sh` no fim (pra reusar uma função) e **depois** chama `main`. Só
que os dois arquivos definiam `main()`. Como o `source` vem **depois** das definições, a `main` do
smoke sobrescreveu a do watch: o cron rodava o smoke e ia embora — **sem estado, sem alerta, sem
log**. Os 20 testes unitários passavam porque carregam **só** o watch, onde não há colisão.

- **A regra:** script que faz `source` de outro é dono de um namespace compartilhado. Nome genérico
  (`main`, `log`, `init`, `run`, `cleanup`) é colisão esperando acontecer — prefixe o entry point
  (`watch_main`) e **teste a ausência de colisão**, não só o comportamento.
- **O assert que pega a classe inteira** (não só a ocorrência):
  ```sh
  _funcs_of() { bash -c 'set +u; source "$1" >/dev/null 2>&1; declare -F' _ "$1" | awk '{print $3}' | sort; }
  comm -12 <(_funcs_of a.sh) <(_funcs_of b.sh)   # tem que sair VAZIO
  ```
- **Sintoma-assinatura:** o script "roda" (exit 0) e produz a saída do arquivo **sourceado**, mas
  nenhum efeito colateral próprio (arquivo de estado não criado, log próprio ausente).
- **Lição de método:** teste unitário que carrega um só arquivo **não** exercita o wiring. Rode a
  ferramenta pelo caminho real (o do cron) antes de chamar de pronta.

---

## Como saber se um cron/monitor MORREU: batimento periódico não serve — só dead-man's switch {#deadman-switch-nao-batimento}

`tags: cron, watchdog, monitor, heartbeat, batimento, dead man switch, silencio, alerta, quem vigia o vigia, observabilidade`

**Origem:** auth-service, 2026-07-30/31 — desenho corrigido pelo time Micro Investors antes de virar código.

Um monitor que só fala quando algo quebra tem um modo de falha invisível: **monitor morto e monitor
saudável são indistinguíveis**, porque os dois são silenciosos. Um `crontab -e` distraído, ou um
`git pull` de deploy abortando em working tree suja, e ninguém sabe.

**A correção intuitiva está errada.** "O monitor manda um resumo periódico (vivo, N ciclos)" **não**
resolve: se ele morre, o resumo simplesmente **não chega** — e "não chegou nada" é indistinguível de
"semana tranquila". Move o problema de *silêncio parece saúde* para *silêncio parece saúde, com mais
passos*.

- **O desenho que funciona (dead-man's switch):** o monitor **carimba** (arquivo, chave, endpoint) e
  **outro processo** alerta quando o carimbo passa da validade.
- **Por quê:** alertar na **presença** de um evento falha aberto (evento não veio = silêncio);
  alertar na **ausência** exige alguém contando o tempo — é o único desenho em que **morrer gera
  sinal**.
- **Regra dura:** quem alerta tem que ser processo **diferente** do que pode morrer. O monitor
  auto-verificando-se é justamente o processo que pode não estar rodando.
- **Implementação barata:** um watchdog que já existe checa o `mtime` do arquivo de estado
  (`age > 3 ciclos` = morto). Não crie infra nova — e **peça** ao dono do watchdog em vez de editar
  a ferramenta de outro produto.

---

## Auditar SPA em produção de fora: bata na ROTA INTERNA, nunca em `/` {#auditar-spa-rota-interna}

`tags: SPA, deploy, 404, chunks, bundle, landing page, Next.js, Vite, auditoria externa, curl, falso alarme`

**Origem:** auth-service → Micro Investors, 2026-07-31 — quase virou alarme de "produção fora do ar".

Ao conferir se um fix está no ar, testei `https://app2.<produto>.com/` e achei **os 12 chunks JS
retornando 404**. Conclusão aparente: app quebrado. Errado — `/` era uma **landing Next.js** (SSR,
por isso o conteúdo aparecia) e o app é um **SPA Vite em `/dashboard`**, cujos 6 assets resolvem
`200` normalmente. Dois apps no mesmo host, roteados por path.

- **A regra:** o host raiz frequentemente não é o app. Bata em rota que só existe logado
  (`/dashboard`, `/app`) e confira o **shell** que volta (SPA costuma ser um HTML de ~1-2 KB com
  `<div id="root">`).
- **Sinal de que você está na página errada:** HTML grande com muito texto renderizado (SSR/marketing)
  + chunks que não resolvem; ou `_next/image` respondendo 200 enquanto `_next/static/*` dá 404.
- **Antes de alarmar outro time:** repita com User-Agent de browser, em coletas consecutivas, e
  cheque um segundo host/rota. Alarme falso custa credibilidade — ver [#alarme-falso-mata-o-alarme].
- **Complementar:** pra auditar o **código** de outro repo use a ref publicada
  ([#auditar-outro-repo-ref-publicada]); pra auditar o que está **no ar**, use a rota interna.

---

## Consumer novo "não consegue enviar OTP": audience nunca foi registrada no auth-service {#audience-nao-registrada-otp-falha}

`tags: otp, audience, invalid_audience, 422, audience not registered, onboarding consumer, novo produto, assert_audience_known, whatsapp nao envia, toast generico, versao do cliente, falso alarme, otp_require_existing_account, anti-relay-abuse, docker secret, database_url, run/secrets, ssh key sem passphrase`

**Sintoma:** um consumer (produto/LP/app) reporta "OTP não envia" — no browser aparece um toast
genérico tipo *"Não foi possível enviar o código. Tente novamente."* A tentação é achar que o cliente
está numa versão desatualizada do contrato, ou que é WhatsApp/GOWA caído.

**Causa raiz real (neste caso e provavelmente em qualquer consumer NOVO):** `POST /otp/request`
devolve **422 `error_code=invalid_audience` / "Audience not registered"** — a dependency
`assert_audience_known` (E1 strict) rejeita qualquer `audience` que não exista na tabela
`auth.audiences`. Um consumer pode ter o código 100% correto (payload certo, endpoint certo) e ainda
assim falhar porque **ninguém inseriu a linha da audience dele em produção** — geralmente porque o
`docker-compose.yml`/env do consumer já tinha o nome da audience (`AUTH_SERVICE_AUDIENCE=xxx-site`)
mas o onboarding do lado auth-service (registrar no banco) nunca aconteceu.

**Como confirmar rápido (sem adivinhar):** reproduza a chamada exata do consumer com `curl` direto
no endpoint público (`POST /otp/request` com o mesmo `channel`/`destination`/`audience`). Se vier
`422 invalid_audience`, achou — não precisa investigar GOWA, CORS, nem pedir log pro outro time.
Antes de pedir qualquer coisa a um consumer, cheque também se a chamada dele é **server-to-server**
(Next.js API route, etc.) — se for, CORS não pode ser a causa, mesmo que outro incidente de CORS
esteja rolando ao mesmo tempo.

**A parte que MAIS importa — não registre com o default:** `otp_require_existing_account` no schema
`Audience` é `true` por padrão (fail-secure, anti-relay-abuse, ligado ao incidente
`otp_abuse_incident_2026-06-09`). Se você registrar a audience nova SEM pensar nesse campo, o `422`
some — mas se o consumer não tiver um caminho de **provisionamento de identidade**
(`/internal/identities`), todo envio passa a ser **descartado em silêncio**
(`log.warning("otp.request.no_account", outcome="dropped_no_account")`) porque nenhuma conta
pré-existe pra aquele destino. Você troca um erro visível por um "sucesso" fake (o cliente recebe
`202` e nunca chega WhatsApp nenhum) — pior que o bug original, porque agora nem aparece erro.
**Antes de decidir o valor:** `grep -ri "internal/identities" <repo-do-consumer>` — se não achar nada,
é um gate aberto por design (ex.: LP com verificação de WhatsApp, sem sistema de conta) e
`otp_require_existing_account=false` é o valor certo. Se achar chamada de provisionamento, deixe
`true` (ou omita — é o default).

**Como aplicar em produção quando SSH/porta de DB não cooperam:** a porta pública do Postgres
(`161.97.129.138:5432`) pode não ser alcançável de uma sessão de dev, e a chave SSH "oficial" pode
estar com passphrase trancada. Nesse caso: (1) teste chaves alternativas mais antigas
(`~/.ssh/fm-ci-deploy`, `~/.ssh/id_rsa`) — `ssh-keygen -y -P "" -f <chave>` confirma sem passphrase
sem tocar no servidor, e elas costumam continuar válidas mesmo após uma rotação de credenciais nova;
(2) uma vez dentro da VPS, **não existe `DATABASE_URL` como env var solta no container** — em prod
o Pydantic Settings usa `secrets_dir="/run/secrets"`, então o valor real está no arquivo
`/run/secrets/database_url` **dentro do container** (leia esse arquivo, não `os.environ`); (3)
`docker cp` um script Python pro container e rode com `docker exec <cid> python /caminho/script.py`
— o container já tem `asyncpg` instalado, não precisa psql. O cache de audiences (TTL padrão 60s,
por-processo, sem invalidação cross-réplica quando você insere direto no banco em vez de usar o
`PUT /admin/audiences/{id}`) pode levar até 1 minuto pra pegar a linha nova — teste com `curl` de novo
antes de declarar sucesso, mas na prática às vezes já pega na primeira tentativa seguinte.

**Armadilha à parte (custou caro nesta sessão):** `export $(grep PADRAO .env | xargs)` quando o
`grep` não acha nada vira `export` **sozinho** — e `export` sem argumento **lista TODAS as env vars**
do shell, vazando qualquer API key que esteja no ambiente (não só as do `.env` do projeto) direto no
output/transcript. Sempre confira que a substituição de comando não ficou vazia antes de rodar
`export $(...)`, ou monte a variável com `grep ... | cut -d= -f2-` isolado, nunca em linha com
`export`.

**Ref:** auth-service → `ads4pros-site` (repo `ADS4PROS-Site`, LP `/lp1`/`/lp2`), 2026-07-31.
`docs/cross-product/2026-07-31-auth-para-ads4pros-otp-nao-envia-pedido-do-log-de-erro.md`. Schema:
`services/api/app/models/audience.py` (`otp_require_existing_account`); gate:
`services/api/app/modules/audiences/dependencies.py` (`assert_audience_known`); drop silencioso:
`services/api/app/modules/otp/router.py` (`outcome="dropped_no_account"`). Irmão: incidente de abuso
que criou o campo, `otp_abuse_incident_2026-06-09`.

---

## Conselho devolve "3 providers ok" com uma perna vazia e outra cortada (teto de tokens × modelo de raciocínio) {#conselho-perna-vazia-teto-tokens}

`tags: conselho, council, orchestrator, deepseek, cross-claude, groq-llama, max_tokens, 1024, reasoning_tokens, resposta vazia, truncado, finish_reason, length, stop_reason, max_tokens, status ok, falso verde, pre-mortem, consenso falso`

**Origem:** percus-kit, 2026-07-31 — o pre-mortem do plano 2 devolveu "3 providers chamados" quando
só **um** havia respondido.

Duas falhas encaixadas, e é a segunda que transformou a primeira em silêncio.

**A primeira é o teto de tokens contra modelo de raciocínio.** Em modelos como `deepseek-v4-pro`, os
`reasoning_tokens` contam **dentro** de `completion_tokens`. Com `max_tokens = 1024`, uma pergunta
difícil faz o modelo gastar o teto inteiro pensando e devolver `content: ""`. Medido no mesmo dia,
lado a lado:

| Chamada | completion | reasoning | sobrou pra resposta |
|---|---|---|---|
| pergunta curta | 611 | 498 | 113 → respondeu |
| pre-mortem com plano inteiro | 1024 | 1024 | **0 → vazio** |

Do ponto de vista do HTTP, os dois deram **200**. Não há erro para capturar.

**A segunda é o provider chamar isso de sucesso.** O código gravava `status = "ok"` sempre que a
chamada não lançava exceção, sem nunca olhar o conteúdo. Na mesma rodada, o Cross-Claude bateu no
mesmo teto por outro caminho — devolveu texto **cortado no meio de uma frase** — e também foi
reportado como `ok`. Duas das três pernas degradadas, zero sinal.

- **A regra:** `HTTP 200` ≠ resposta. Classifique **três** estados, não dois: `ok`, `empty`
  (conteúdo vazio ou só espaço) e `truncated` (`finish_reason == "length"`, ou `stop_reason ==
  "max_tokens"` na API da Anthropic). Vazio e cortado nunca podem se chamar `ok`.
- **O aviso tem que nomear a causa**, não só o sintoma. "vazio" manda procurar erro de API;
  "gastou o teto raciocinando, suba `max_tokens`" manda consertar o que é.
- **O agregador tem que dizer a conta.** `providers_called` não é `providers que responderam` — se
  quem lê precisa derivar isso, alguém vai ler errado. Emita `respostas_usaveis: N de M` e liste as
  degradadas em stderr.
- **Como caçar:** procure `status\s*=\s*"ok"` em qualquer wrapper de API. Se estiver numa linha que
  não olha o conteúdo, é este bug. Depois confira `max_tokens` contra a natureza do modelo — teto
  que serve para modelo sem raciocínio é pequeno demais para modelo com.
- **Por que passa despercebido:** o consumidor recebe uma lista com o número certo de elementos.
  Contar elementos dá o resultado esperado; só ler o conteúdo revela que um deles está vazio.

**Relacionado:** [Fact-check marca REAL como INFUNDADO](#fact-check-infundado-e-nao-verificado) — a
mesma confusão entre "não consegui" e "não tem", uma camada acima.

---

## `alias.coluna` vira `funcao(alias)` e o erro mente sobre a causa {#alias-coluna-vira-funcao}

`tags: postgres, group by, notacao funcional, coluna inexistente, count, must appear in the GROUP BY clause, erro que mente, information_schema, sql`

**Sintoma:** um `SELECT` trivial, sem nenhum agregado à vista, falha com
`column "t.id" must appear in the GROUP BY clause or be used in an aggregate function`.

```sql
-- isto parece uma consulta comum e não é
SELECT t.id, t.name, c.signal, c.count, c.checked_at
FROM crm_signal_state c JOIN tenants t ON t.id = c.tenant_id
```

**A causa:** o Postgres trata `alias.nome` e `nome(alias)` como **equivalentes** (notação funcional).
Quando `count` **não existe** como coluna de `c`, o parser não desiste — ele resolve `c.count` como
`count(c)`, que é o **agregado**. A consulta passa a ter um agregado, e o Postgres reclama, com toda
a razão, que `t.id` não está no `GROUP BY`.

**Por que isso engana:** o erro aponta para `t.id`, que está perfeito, e não menciona `c.count`, que é
o culpado. Ninguém procura nome de coluna inexistente quando o erro fala de `GROUP BY` — o instinto é
mexer no agrupamento, e mexer no agrupamento faz a consulta rodar devolvendo outra coisa.

- **A regra:** erro de `GROUP BY` em consulta que não tem agregado ⇒ **suspeite de nome de coluna que
  colide com função** (`count`, `min`, `max`, `sum`, `avg`, `length`, `abs`, `left`, `right`,
  `upper`, `lower`, `now`...). Confira a coluna **no catálogo** antes de tocar no agrupamento.
- **Como confirmar em um passo:**
  `SELECT column_name FROM information_schema.columns WHERE table_name = '<tabela>'`.
  Se o nome não estiver lá, era isto.
- **Prevenção barata:** ao explorar tabela desconhecida, comece por `SELECT *` e leia as colunas de
  verdade, em vez de escrever a lista de memória. Foi assim que o caso real apareceu: a coluna
  chamava-se `measured_count`, não `count`.
- **Vale além do Postgres:** a mesma notação funcional existe em qualquer engine que a suporte. O que
  não varia é a lição — **a mensagem de erro do banco aponta onde ele tropeçou, não onde você errou.**

---

## Rótulo curto casa DENTRO de outra palavra e escolhe a coisa errada (no caminho do dinheiro) {#rotulo-casa-dentro-de-palavra}

`tags: substring, fronteira de palavra, word boundary, regex, lookaround, match de rotulo, alias, sinonimo, tamanho, variante, catalogo, falso positivo, dicionario de excecoes, matcher, ILIKE, includes, indexOf, nlp`

**Sintoma:** o sistema escolhe um item/opção/rótulo que o usuário **não** citou, sem erro nenhum no
log. O texto do usuário "contém" o rótulo — mas por acidente, dentro de outra palavra.

**Caso real (tiatendo, 2026-07-31, `sabor-do-teste`):** o rótulo de variante *Torre* casou dentro de
"tor**resmo**". A frase *"quero retirar o torresmo da feijoada"* **adicionou** *Feijoada Torre —
R$ 80,00* ao carrinho, calada. Mesma classe, outras formas: "G" dentro de "**G**uaraná", "Cola"
dentro de "e**scola**", "coca" dentro de "Coca-Cola Zero", "info" dentro de "sentry**info**@".

**Causa raiz:** teste de pertinência de string cru — `rotulo in texto`, `ILIKE '%x%'`, `.includes()`,
`indexOf() >= 0` — entre **texto livre do usuário** e **rótulo curto de catálogo**. Quanto mais curto
o rótulo, maior a chance; rótulo de tamanho tem **uma letra**.

**Solução:**
1. **Fronteira de palavra, nunca substring.** Isso mata a **classe**. A alternativa — lista de
   exceções ("torresmo não é Torre") — **nunca fica pronta**: cada catálogo, tenant e idioma traz
   palavras novas, e a lista só cresce depois de cada prejuízo.
2. **Prefira lookarounds a `\b`** quando o rótulo pode terminar em caractere não-word ("P+", "1L?",
   "500ml."): `re.search(rf"(?<!\w){re.escape(needle)}(?!\w)", hay)`. Com `\b`, um rótulo terminado
   em `+` **inverte o sentido do limite** e o match aparece/some onde você não espera.
3. **Falhe FECHADO:** dúvida devolve "não casou" e o sistema **pergunta**, em vez de escolher — o
   custo de um turno a mais é menor que o de cobrar item que ninguém pediu.
4. **Prefixo não é grupo.** Declare rótulos como chaves **distintas** ("torre" × "torre e meia"),
   senão o hint de um casa o rótulo do outro. Se hoje funciona por acidente (a função devolve `None`
   pros dois), amanhã quebra: transforme o acidente em invariante travada por teste.
5. **Normalização interna não pode vazar pro usuário.** Se você colapsa "torre e meia" → `torreemeia`
   para sobreviver ao separador de chunks, **restaure** antes de ecoar — o cliente leu "torreemeia"
   na pergunta do bot.

**Como caçar:** `grep -rn " in \|ILIKE '%\|\.includes(\|\.indexOf(\|LIKE '%"` restrito aos módulos que
comparam entrada do usuário com nome/rótulo/alias de catálogo. Toda ocorrência é suspeita até provar
que os dois lados são vocabulário fechado.

**Ref:** tiatendo, `_wholeWordIn` em
`D:\Claud Automations\tiatendo\execution\engine\restaurantOrderFlow.py:154`, commit `c1ced5b`,
PROD `0.266.0`. Irmãos: [#guarda-destrutiva-testar-com-perguntas] (a mesma armadilha num guard de
remoção), [#smoke-prod-feature-llm] (conjunto fechado de formas aceitas para ref vinda de LLM),
[#classificar-formato-corrompe].

---

## Teste que passa EM CIMA do defeito: o exemplo escolhido é o único em que o bug não aparece {#teste-passa-em-cima-do-defeito}

`tags: teste vacuo, teste decorativo, exemplo escolhido, fixture, mutacao, prova por mutacao, reverter o fix, suite verde mentirosa, regressao, red green, TDD, cobertura cega, nome do teste, review nao pega`

**Sintoma:** existe um teste que **nomeia exatamente** o comportamento em questão, ele está **verde**,
e o defeito está **vivo em produção**. Ninguém desconfia dele justamente porque o nome é bom.

**Causa raiz:** o teste escolheu o exemplo em que o **mecanismo do defeito não pode disparar**. O
assert está certo; o dado é que desvia da armadilha.

**Casos reais (tiatendo — três no MESMO dia, 2026-07-31).** O mais didático: um teste "provava" que,
ao trocar de endereço, a **rua nova** era preservada — e usava a **única rua fora da lista de
endereços salvos**. O defeito era exatamente *a rua salva casar antes de o número novo ser lido*; com
uma rua que não está na lista, ele **não tem como acontecer**. Em produção, *"hoje é na Rua Major
Capile, 500"* entregava no **2680**. Os outros dois tinham a mesma assinatura: fixture sempre com o
YAML preenchido (o fallback nunca via YAML vazio) e asserção sobre o caminho feliz de um guard cuja
falha morava no caminho não previsto.

**Detecção — só um método funciona: mutação.**
1. Reverta o fix (ou enfraqueça a linha) e rode **apenas** os testes que dizem proteger aquilo.
2. Se continuarem **verdes**, o teste é decoração — não protege nada e ainda **autoriza a regressão**,
   porque o próximo leitor confia no nome.
3. Faça isso **no momento em que escreve o fix**, não numa auditoria futura: é quando custa 30
   segundos.

**Por que review e conselho não pegam:** ambos leem o **nome** e o **assert**, que estão corretos. A
distância entre o exemplo e o mecanismo do defeito não está no diff — está no dado.

**Regra prática:** ao escrever teste que "prova" que X é preservado/escolhido/ignorado, escolha o
exemplo **em que o mecanismo do defeito está ativo** (a rua que ESTÁ na lista, o apartamento que
colide, o rótulo que é prefixo de outro, o YAML vazio). O exemplo fácil entra como **segundo** caso,
nunca como único.

**Ref:** tiatendo 2026-07-31, commits `4039f7a` (round 1 do review R11 achou o teste da rua) e
`c1ced5b` ("2 testes que passavam EM CIMA do defeito que diziam proteger"). Vizinhos, com recortes
diferentes: [#red-nunca-visto-embarca-fossil] (teste que nunca ficou vermelho),
[#mutacao-sobrevive-predicado-quase-certo] (mutação no **predicado**, não no exemplo),
[#fixture-uniforme-esconde-irregular] (fixture uniforme escondendo o caso irregular do lado da
produção), [#xfail-que-xpassa-anuncia-defeito-que-nao-demonstra].

---

## Guard CERTO sem caminho alternativo produz o OPOSTO do que protege {#guard-sem-caminho-alternativo}

`tags: guard, guarda, except Exception, or vazio, fallback, degradar pro neutro, ausencia de prova, prova de ausencia, fail-open, fail-closed, lado da falha, par assimetrico, acao destrutiva, pausa, blip de banco, classe de defeito, varredura`

**Sintoma:** um guard revisado, aprovado e **correto no caso previsto** é a causa do pior estrago do
sistema — e a fala/ação dele é a mais errada possível **sobre justamente o domínio que ele protege**.

**A forma abstrata:** guard correto no caso previsto cuja reação ao caso **NÃO previsto** (`except`,
`else`, `or []`, `None`) produz o **OPOSTO** do que ele protege, em vez de **degradar pro neutro**.
Quase sempre: **ausência de prova tratada como prova de ausência**.

**Casos medidos (tiatendo — 4 reincidências só em 2026-07-31):**
- Guard que impede o LLM de inventar dinheiro, **sem** caminho determinístico para "quanto fica meu
  pedido?" → respondia *"seu pedido ainda não foi fechado"* a quem perguntou o total.
- Guard que apaga o refresh cookie quando o auth diz que a sessão morreu; `None` também acontecia em
  **timeout** → destruía sessão de 30 dias **viva**.
- **Forma nova, a mais cara:** falha de leitura das zonas de entrega (`except` tratado igual a "zero
  linhas", com `or []`) fazia o bot **afirmar** *"esse endereço está fora da minha área de entrega"*,
  **pausar o bot** e **limpar o checkout**. O mesmo era dito quando o bot simplesmente **não entendeu
  a frase**. Ou seja: *o guard produziu a afirmação factual mais errada possível sobre a própria área
  de cobertura* — e ainda executou o destrutivo em cima dela.

**Como achar (greps que rendem, em ordem de retorno):**
1. **`except Exception`** — o de maior retorno. Leia o que vem **depois**, não o log.
2. `or []` / `or {}` / `?? []` colado em leitura de banco/API — "não consegui ler" virando "não
   existe".
3. Cliente de API que devolve `None`/`null` no erro e é usado como **valor de negócio**.
4. Toda **ação destrutiva ou irreversível** (pausar, limpar, apagar, cobrar, cancelar, banir) — e
   **suba** dali: quem chega aqui com dado incompleto?
5. **Par assimétrico:** um `if` que trata como um só dois casos de custo oposto ("não atendemos ali"
   × "não deu pra saber"). Esses dois precisam de ramos diferentes, sempre.
6. **O NOME do teste:** um teste chamado `..._cai_no_fallback` costuma **cimentar** o defeito em vez
   de proteger — cf. [#teste-passa-em-cima-do-defeito].

**Solução:**
- **Separe os casos:** "zero linhas" ≠ "exceção". Só o primeiro autoriza o fallback.
- No caso não previsto, **degrade pro neutro**: perguntar, repetir, escalar — e **nunca** executar o
  destrutivo nem **afirmar** fato sobre o domínio.
- **Escreva no código o lado para o qual o guard falha** e o custo aceito. Sem isso, o próximo leitor
  "conserta" o que era deliberado.
- Achou um, **varra a classe**: o padrão vem em cacho (uma varredura rendeu 5 de uma vez).

**Ref:** tiatendo — catálogo em
`D:\Claud Automations\tiatendo\docs\auditoria-guard-sem-caminho-alternativo-2026-07-29.md`, verbete
em `D:\Claud Automations\tiatendo\CONTEXT.md`; commits `5c8363f` (5 guards de uma vez), `4039f7a` e
`4f369ca` (zonas de entrega). Irmãos: [#guarda-destrutiva-testar-com-perguntas],
[#fail-open-esconde-teste-vacuo], [#guarda-redundante-tesoura-ou-morta],
[#degrade-gracioso-esconde-noauth], [#provider-none-vira-entrega], [#gate-confirmacao-dead-end].

---

## Guarda de ação externa barra o COMMIT porque a MENSAGEM cita a ação {#guarda-casa-a-mensagem-nao-a-acao}

`tags: hook, PreToolUse, external-action-guard, R20, push, commit, heredoc, mensagem de commit, falso positivo, matcher, tool_input.command, bloqueio inesperado, uso vs mencao`

**Origem:** percus-kit, 2026-07-31 — um `git commit` foi barrado por uma guarda de push. E depois,
para fechar o círculo, ela barrou também a **escrita deste verbete**, porque o texto aqui contém o
literal que ela casa.

O `external-action-guard` casa padrões (push, `gh pr comment`, `slack-cli`, …) contra
`tool_input.command`, que é a **string inteira** do comando — o corpo do heredoc de `-F -` incluído.
Uma mensagem de commit que *descreve* uma ação externa é, para a guarda, indistinguível de
*executar* uma. Falar sobre a ação vira fazer a ação.

- **Sintoma:** commit bloqueado com `BLOCK (R20)`, e o campo `Comando:` do erro mostra o corpo
  inteiro da mensagem, não um comando externo.
- **Contorno imediato:** reformular ("a mesma ação externa barrada pela tool Bash" em vez do literal),
  ou escrever o arquivo pelo editor em vez de heredoc no shell. O commit é legítimo; quem está
  errado é o casamento.
- **A regra geral:** guarda que casa por regex na linha de comando inteira não distingue **uso** de
  **menção**. Vale para qualquer payload que carregue prosa: `-F -`, `<<EOF`, `-m "..."`. O conserto
  de verdade é casar só o **comando efetivo**, não o corpo.
- **Por que passa despercebido até morder:** o bloqueio parece correto à primeira vista — a string
  *está* ali. Só relendo o `Comando:` inteiro fica claro que ela está dentro do texto.

**Relacionado:** [#fail-open-esconde-teste-vacuo] — o par simétrico: lá a guarda não vê o que devia,
aqui ela vê o que não é.

---

## Hook que sai 0 não consegue avisar ninguém: stderr e stdout são invisíveis no caminho de sucesso {#hook-que-sai-zero-nao-avisa}

`tags: hook, PreToolUse, exit 0, stderr, stdout, invisivel, aviso que ninguem le, SessionStart, health check, Claude Code, settings.json, canal visivel, bash, auto-lockout`

**Origem:** percus-kit, 2026-07-31 — medido com sondas, ao desenhar um fallback "barulhento" que
teria sido barulho no vácuo.

Duas sondas registradas no mesmo evento `PreToolUse`, uma escrevendo em **stderr** e outra em
**stdout**, ambas saindo **0**. A chamada seguinte rodou normal e **nenhuma das duas apareceu** — nem
na saída da ferramenta, nem como aviso. Só a terceira sonda, que escrevia num arquivo, deixou rastro.

| Caminho | A saída aparece? |
|---|---|
| hook `PreToolUse` que sai **0** | **não** — nem stderr, nem stdout |
| hook `PreToolUse` que sai **2** | sim (é como um BLOCK se mostra) |
| hook `SessionStart` que sai 0, escrevendo em **stdout** | sim (é como um gate de início se mostra) |
| hook `SessionStart` que sai 0, escrevendo em **stderr** | **não** — ver [#sessionstart-stderr-nunca-aparece] |

- **A regra:** aviso no caminho de sucesso **não existe**. Se um hook precisa dizer algo sem
  bloquear, o lugar é `SessionStart` (ou um arquivo que alguém leia depois), nunca uma escrita antes
  de um `exit 0`.
- **Como isso vira bug:** você escreve o aviso, confere lendo o código, conclui que "avisa", e o
  usuário nunca vê. Pior que não avisar — porque você para de procurar outro canal.
- **Como confirmar em 2 min:** registre duas sondas triviais (uma em stderr, outra em stdout, ambas
  `exit 0`) no `settings.json` do projeto e dispare uma ferramenta. Mudança em `settings.json` de
  projeto vale na hora, sem reiniciar a sessão.
- **Atenção:** o shell que executa o `command` de um hook (nesta máquina) é **`/usr/bin/bash`**, não
  PowerShell nem cmd — a doc oficial diz PowerShell no Windows e não foi o observado. Sonda em
  sintaxe errada devolve erro de sintaxe do bash, e `command` malformado sai não-zero, o que em
  `PreToolUse` **bloqueia a ferramenta inteira** (auto-lockout observado; a saída é por uma tool que
  o matcher não cubra).

**Relacionado:** [#plugin-cache-nao-recebe-fix] — o mesmo desenho de "parece que está ligado e não
está", uma camada abaixo.

---

## "Atualizei a credencial e continua falhando": env var herdada vence o .env, em silêncio {#env-var-vence-dotenv}

`tags: credencial, .env, variavel de ambiente, DEEPSEEK_API_KEY, api key invalida, precedencia, dotenv, User scope, Windows, atribuicao errada, rotacao de token`

**Origem:** Micro Investors, 2026-07-31 — revisor DeepSeek fora do ar por horas, com a causa
diagnosticada errada duas vezes antes de alguém comparar as fontes.

O revisor falhava com `Authentication Fails, Your api key: ****6032 is invalid`. O operador
rotacionou a chave e atualizou o `.env` do projeto. **Nada mudou.** O carregador faz
`if (-not $env:CHAVE) { <carrega .env> }` — ou seja, **o arquivo só é lido quando a variável não
existe**. A sessão tinha herdado a chave velha da variável de ambiente **do usuário no Windows**, que
vencia o arquivo sem dizer nada. Como a variável é a mesma em toda a casa, o revisor estava quebrado
em **todos** os projetos, não só naquele.

- **A regra:** "env var tem precedência sobre `.env`" é o padrão quase universal (dotenv,
  pydantic-settings, docker compose) e é o que se quer em produção — mas inverte a intuição de quem
  debuga: você edita o arquivo, vê o valor certo lá, e o processo segue usando outro.
- **Como diagnosticar em 30s, sem imprimir segredo** — compare os últimos 4 caracteres e o
  comprimento das **três** fontes:
  ```powershell
  $env:X.Substring($env:X.Length-4)                                   # o que o processo usa
  ((Select-String .env -Pattern '^X=').Line -split '=',2)[1].Trim()   # o que o arquivo diz
  foreach ($s in 'Process','User','Machine') { [Environment]::GetEnvironmentVariable('X',$s) }
  ```
- **Conserto:** na **origem** (`SetEnvironmentVariable(...,'User')`), não só no arquivo — senão
  volta na próxima sessão. O processo em execução mantém o valor antigo no escopo `Process`, então
  dentro da sessão corrente ainda é preciso sobrepor inline a cada chamada.
- **A armadilha de atribuição:** o plugin tinha se auto-atualizado no mesmo intervalo, e a versão
  nova virou "a causa" por pura coincidência de horário. **Antes de culpar o que mudou junto,
  compare as fontes da credencial** — é mais barato e mata a hipótese errada na hora.

**Relacionado:** [#hook-que-sai-zero-nao-avisa] — mesma família: o que está configurado não é o que
está rodando.

---

## Banco novo para um segundo tenant quando a cadeia de migrations não roda do zero {#tenant-novo-cadeia-migrations-quebrada}

`tags: multi-tenant, duplicacao, pg_dump schema-only, migrations nao replayam, _migrations seed, GRANT matview, ALTER DEFAULT PRIVILEGES, REVOKE CONNECT PUBLIC, isolamento, least-privilege, Postgres`

**Origem:** Micro Investors, 2026-07-31 — provisionamento do 2º tenant por duplicação total.

Produto single-tenant precisava servir um segundo cliente com **separação física** (banco próprio +
stack própria). O caminho `tenant_id` em todas as tabelas foi descartado no pre-mortem. O primeiro
obstáculo foi inesperado: **as migrations não sobem um banco do zero** — a cadeia inicial referenciava
um schema (`auth`) que uma migration posterior **dropou**, então replayar quebra no meio.

**Receita que funcionou:**
1. `pg_dump --schema-only --no-owner --no-privileges` do banco vivo. **Os dois flags são o ponto:**
   sem eles o dump carrega os GRANTs da role do tenant A, e a credencial de um alcança o banco do
   outro — matando a separação que motivou o trabalho.
2. Role própria por tenant, com os mesmos grants. **`GRANT` nominal nas matviews:**
   `ALTER DEFAULT PRIVILEGES ... ON TABLES` **não cobre** `MATERIALIZED VIEW` (relkind `m`) — matview
   nova nasce ilegível e a falha só aparece no runtime da app.
3. **Semear a tabela de controle de migrations** com o que já foi aplicado, senão o runner considera
   o banco virgem e tenta replayar a cadeia que não roda.
4. **Re-aplicar o endurecimento que não vem no dump.** Tudo que foi feito com `GRANT`/`REVOKE` direto
   em produção (e não como migration) desaparece com `--no-privileges`. Se existe nota do tipo "se o
   DB for recriado, re-aplicar", é agora.
5. **`REVOKE CONNECT ON DATABASE ... FROM PUBLIC` nos DOIS bancos.** No Postgres o `PUBLIC` tem
   `CONNECT` por padrão: sem isso, **toda role de login do cluster** abre sessão no banco de todos.
   Ler não consegue (sem grant de tabela), mas enumera catálogo e consome slot.

**Como provar o isolamento (e não só afirmar):** teste as duas direções com **credenciais válidas**.
Testar com senha errada devolve `password authentication failed` e não prova nada sobre permissão — o
verde esperado é `FATAL: permission denied for database`. Fecha com a sentinela em
`pg_stat_activity`: cada API na sua base, com a sua role.

**Custos a assumir por escrito:** todo deploy sai em dose dupla; a migration precisa rodar nos dois
bancos (runner com o banco hardcoded vira dívida imediata); não existe visão consolidada entre
tenants; e o frontend, se assar config no build, precisa de **uma imagem por tenant** — com gate
**fail-closed** no build, porque o modo de falha silencioso é o frontend de um cliente falando com a
API do outro.

**Relacionado:** [#env-var-vence-dotenv] — as duas mordem por "o que está no arquivo não é o que está
valendo".

---

## Task dada como "fechada" com prova que só cobria metade do canal: hook fala por stderr num `SessionStart` que sai 0, e nunca aparece {#sessionstart-stderr-nunca-aparece}

`tags: SessionStart, hook, stderr, stdout, exit 0, health check, canario observacional, hook_success, transcript jsonl, Claude Code, prova incompleta, assinatura em stderr`

**Origem:** percus-kit, 2026-07-31 — canário observacional de um health check que tinha sido dado
como fechado numa sessão anterior.

Um health check em `SessionStart` (sempre `exit 0`, por contrato — nunca pode travar a sessão) tinha
sido validado com a prova "`SessionStart` produz saída visível", baseada num hook `echo` de exemplo
que falava por **stdout**. O health check em si falava por **stderr**, seguindo a convenção de
assinatura-em-stderr usada pelas guardas (`PreToolUse` que sai 2 mostra stderr — faz sentido lá). Na
sessão seguinte o banner esperado não apareceu. A tentação é reabrir o restart e torcer; em vez disso,
o `.jsonl` da própria sessão foi lido direto (`~/.claude/projects/<projeto>/<session_id>.jsonl` ou o
equivalente sob `CLAUDE_CONFIG_DIR`), procurando os registros `"type":"hook_success"` com
`"hookEvent":"SessionStart"`.

- **O que os registros brutos mostram, campo a campo:** cada `hook_success` tem `stdout`, `stderr`,
  `content` e `exitCode` **separados**. Comparando os 3 hooks que rodaram na mesma abertura: os 2 que
  escreviam em `stdout` tinham `content` populado (e apareceram); o que escrevia em `stderr` saiu 0,
  com a mensagem certa gravada no campo `stderr` do registro — e `content` vazio. `content` vazio é o
  que decide se aparece pra quem lê a sessão; não é o `exitCode`.
- **Por que a prova original não pegou isso:** ela testava "o evento dispara e o texto aparece" com
  UM exemplo (stdout). Generalizar de "stdout aparece" pra "SessionStart aparece" pulou a variável que
  importava. A mesma classe do item já registrado em [#hook-que-sai-zero-nao-avisa] (stderr é
  invisível em sucesso) — só que ali a medição parou em `PreToolUse` e a suposição vazou pra
  `SessionStart` sem reteste.
- **Como confirmar em 2 min, sem esperar reabrir nada:** rode o hook manualmente com stdout/stderr
  redirecionados pra arquivos separados (`comando 1>out.txt 2>err.txt`); se a mensagem cai em
  `err.txt`, ela não vai aparecer em `SessionStart` mesmo saindo 0. Ou leia o `.jsonl` da sessão atual
  e confira o campo `content` do `hook_success`, não só se o processo rodou.
- **Conserto:** hooks observadores de `SessionStart` (contrato: sempre exit 0, nunca bloqueiam) devem
  falar por stdout. A convenção de assinatura-em-stderr fica só pras guardas (`PreToolUse`/exit 2),
  onde o canal é comprovadamente visível.

**Relacionado:** [#hook-que-sai-zero-nao-avisa] — mesma família, um nível mais fundo: nem todo canal
"visível" é visível igual.

---

## Função de "abandonar/encerrar" duplicada sem os irmãos: grava o status terminal mas esquece a trilha E o estado efêmero associado {#abandonar-duplicado-sem-trilha-e-estado-efemero}

`tags: append-only, trilha de auditoria, estado orfao, pendencia orfa, transacao atomica, funcao
duplicada, UPDATE solto, cleanup path, terminal state, DRY, side effect esquecido, tiatendo,
markAbandoned, order_status_transitions`

**Origem:** tiatendo, 2026-08-02 — dois achados (Pix cobrado sobre pedido `abandoned` sem trilha
nenhuma; saudação "oi" caindo no LLM genérico e alucinando um pedido fantasma) pareciam problemas
diferentes e tinham a MESMA causa raiz.

Um módulo tinha **3 funções que fazem a mesma coisa** — marcar um pedido como `abandoned` — cada
uma escrita em momento diferente por motivo diferente (`draftCleanup.abandonStaleDrafts`,
`nightlyReset`'s sweep, `orderModel.markAbandoned`). As duas mais antigas faziam **3 coisas** na
mesma transação: (1) `UPDATE status='abandoned'`, (2) `INSERT` na tabela de trilha de auditoria
(append-only), (3) `DELETE`/limpeza de qualquer estado efêmero associado (pendência aberta,
sessão em curso) que apontava pro pedido. A terceira função (`markAbandoned`, escrita depois, pra
um caminho de cleanup diferente — caixa/checkout web) fazia **só a primeira**: um `UPDATE` solto.

- **Como os dois sintomas pareciam problemas diferentes:** o achado 1 (dinheiro) mostrava um
  pedido `abandoned` com 0 linhas na tabela de trilha, enquanto os vizinhos tinham 2 cada — lido
  como "falta uma linha de auditoria", um problema de OBSERVABILIDADE. O achado 2 (conversa)
  mostrava uma saudação pura gerando uma resposta alucinada de LLM — lido como um buraco no guard
  de intent-routing, um problema de LÓGICA DE CONVERSA. Nenhum dos dois nomeava "abandonar sem
  limpar o estado associado" até se investigar o CAMINHO (qual função abandonou o pedido? o que
  ela faz e o que ela NÃO faz comparada às irmãs?), não só o SINTOMA.
- **O fio que conectou os dois:** a função sem trilha (`markAbandoned`) também não limpava a
  pendência — e essa pendência órfã (associada a um pedido que já não existe como `draft`) é
  exatamente o que fazia o guard de saudação (que defere pro LLM genérico quando há QUALQUER
  pendência viva não-trivial) rotear pro caminho errado. **A ausência de auditoria e a
  pendência órfã eram o MESMO buraco visto de dois ângulos** — não dois bugs.
- **Como confirmar rápido:** ache TODAS as funções do módulo que escrevem o mesmo status terminal
  (grep pelo valor do enum, ex. `'abandoned'`, `'cancelled'`, `'expired'`). Compare o CORPO delas
  lado a lado — não só a assinatura. A mais nova ou a menos usada costuma ser a que "esqueceu" um
  dos passos que as outras fazem juntas, porque foi escrita depois, isolada, resolvendo só o
  sintoma imediato de quem a criou.
- **Conserto:** reescrever a função faltante pra fazer as MESMAS 3 coisas das irmãs, na MESMA
  transação (não idempotência frouxa — `UPDATE ... RETURNING` como árbitro de que algo realmente
  mudou, e só então `INSERT` trilha + `DELETE` estado efêmero, condicionados ao `RETURNING` não
  vir vazio).
- ⚠️ **"Achar TODAS as funções" é mais estrito do que parece — a instância PARCIAL do bug conta
  também.** No mesmo módulo do tiatendo existe uma 4ª função (`abandonDraftForRestart`) que
  grava a trilha corretamente mas **ainda não limpa** a pendência associada — o mesmo buraco,
  só que pela metade. Não foi corrigida na mesma rodada (o gatilho dela é diferente: dispara no
  MESMO turno em que o cliente já mandou mensagem nova, então a janela de pendência órfã é bem
  mais estreita). Ao comparar os corpos lado a lado, não pare no primeiro "essa não tem os 3
  passos" — confira se as que TÊM os 3 passos realmente os têm todos, ou se alguma tem 2 de 3.

**Relacionado:** [#flag-ja-processei-que-mente] — parente de padrão: os dois casos são uma
única causa raiz produzindo dois sintomas que parecem não-relacionados até alguém seguir o
CAMINHO em vez do sintoma. Aqui a causa raiz é "função irmã incompleta"; lá é "flag que mente".
Também [#discriminador-parcial-reintroduz-bug] — mesma classe ("reusar a lógica da irmã sem
copiar TODOS os passos/ramos"), achada 1 dia depois no MESMO projeto, desta vez num guard de
confirmação de endereço em vez de num cleanup de pedido abandonado.

---

## `Response`/`fetch` com corpo em status 204/205/304 lança TypeError — mesmo ArrayBuffer vazio não é `null` {#response-204-corpo-lanca-typeerror}

`tags: fetch, Response, NextResponse, 204 No Content, 205, 304, passthrough, proxy, BFF, TypeError, null body status, ArrayBuffer vazio, ArrayBuffer.byteLength zero nao e null`

**Contexto:** um BFF/proxy genérico que repassa qualquer resposta de upstream (`new Response(body,
{status: upstream.status, ...})`, `body = await upstream.arrayBuffer()`) funciona para todo status
que os callers existentes exercitam (200, 4xx, 5xx) — e quebra só quando um NOVO caller passa por um
endpoint que devolve **204/205/304**. O bug fica latente por meses: o helper compartilhado nunca foi
testado nesse caminho porque nenhum caller anterior batia nele.

**Sintoma:** `TypeError: Response constructor: Invalid response status code 204` (ou mensagem
equivalente em runtimes diferentes) ao construir `new Response(buf, {status: 204})` — mesmo quando
`buf` é um `ArrayBuffer` de **0 bytes**. A mensagem de erro não deixa óbvio que o problema é "corpo
presente", porque um buffer vazio não parece "ter corpo" pra quem lê o código.

**Causa raiz:** o Fetch spec proíbe corpo em respostas com status 204/205/304 ("null body status").
A implementação do `Response`/`NextResponse` verifica se `body !== null` — um `ArrayBuffer(0)` **não
é** `null`, é um valor válido (só que vazio), então a checagem de "tem corpo" dispara mesmo sem
nenhum byte de conteúdo. `body: undefined` também conta como presente em alguns runtimes; só `null`
explícito passa.

**Solução:** no passthrough genérico, checar o status ANTES de decidir o que passar como body:

```ts
const NULL_BODY_STATUSES = new Set([204, 205, 304]);
return new NextResponse(NULL_BODY_STATUSES.has(upstream.status) ? null : body, {
  status: upstream.status,
  statusText: upstream.statusText,
  headers: respHeaders,
});
```

Teste que prova (não só documenta) o fix: construir um `Response(null, {status: 204})` real e passar
pelo passthrough, sem mock do `Response` nativo — o bug só aparece com a implementação real do
runtime, um mock ingênuo de `Response` não reproduz a checagem do spec.

**Como achar isso ANTES de escrever código novo:** se você está criando um caller novo pra um
endpoint que pode devolver 204 (DELETE, PUT sem corpo de retorno) através de um helper de
passthrough JÁ EXISTENTE e compartilhado por outros callers, pergunte "algum caller anterior desse
helper já bateu em 204/205/304?" — se não, é caminho morto não coberto, não caminho testado.

**Ref:** achado no Task 6 da fatia "multiplicidade de destinos" (Paid Media Automation, 2026-08-03) —
`DELETE /destinations/[did]` e `PUT /destinations/[did]/secret` foram os primeiros callers de
`passthroughResponse` (`web/src/lib/tracking-client-auth.ts`) a devolver 204; `crm/signals` e
`excluded-domains` (callers anteriores) só bateram 200/4xx/5xx.

---

## Teste que verifica ESTADO FINAL não pega regressão de ORDEM entre duas chamadas assíncronas {#teste-estado-final-nao-pega-ordem}

`tags: teste, ordem de chamada, call order, mock, AsyncMock, side_effect, estado final, race, regressao silenciosa, park antes de consumir, TDD, subagent-driven-development`

**Sintoma:** um teste assíncrono mocka duas funções (A e B) chamadas em sequência dentro da função
sob teste, e só verifica o ESTADO FINAL de um dict/contexto compartilhado (ex.: "o valor X foi
gravado?") — não a ORDEM em que A e B rodaram. O teste passa mesmo se a implementação trocar a
ordem das duas chamadas, porque o efeito do mock (`dict.update()`) acumula independente de
sequência.

**Causa raiz:** quando o efeito colateral do mock é cumulativo (um dicionário que recebe
`.update()` de múltiplas chamadas), a asserção de estado final é insensível a QUAL chamada rodou
primeiro — só prova que ambas rodaram, não em que ordem. Se a correção depende de ordem (ex.:
"parkear o valor ANTES de chamar a função que vai consumi-lo"), esse teste não é uma trava real
contra a regressão que ele nomeia no docstring.

**Solução:** trocar a asserção de estado final por uma asserção de ORDEM, usando uma lista
compartilhada e `side_effect` que anexa um marcador em cada mock:
```python
ordem = []
async def _upd(cid, customerContext=None):
    if customerContext and customerContext.get("chave_alvo"):
        ordem.append("park")
async def _consome(*a, **kw):
    ordem.append("consome")
    return [...]
# patch com AsyncMock(side_effect=_upd) / AsyncMock(side_effect=_consome)
assert ordem == ["park", "consome"]
```
Prova real da trava: troque as duas linhas da implementação de lugar (mutação manual) e confirme
que o teste fica vermelho antes de aceitar como pronto — se ficar verde com a ordem trocada, a
asserção não protege nada.

**Ref:** revisão de qualidade da Task 6, plano C11/C12 (tiatendo, 2026-08-03) —
`test_metodo_de_pagamento_ja_escolhido_sobrevive_a_troca` em
`tests/restaurant/test_handleModeSwitchC1220260803.py`; achado por um code-quality-reviewer
subagent que mutation-testou a asserção antes de aprovar.

---

## Reusar "o mesmo discriminador" de uma função irmã sem copiar TODOS os ramos reintroduz o bug que a irmã já corrigiu {#discriminador-parcial-reintroduz-bug}

`tags: discriminador, guard, confirmacao unica, endereco, address confirmed, reuso parcial, 4 vias vira 2 vias, regressao silenciosa, RF29, mode switch, funcao irma`

**Contexto:** uma função nova (`_handleModeSwitch`, tiatendo) precisava decidir se um endereço já
conhecido exige nova confirmação do cliente. O docstring dizia "reusa o MESMO discriminador que a
função-irmã (`_awaitConfirm`) já usa" — mas o código de fato só copiou 2 dos 4 ramos da irmã
(`validated OR formatted → pergunta`), sem a trava "já confirmado pra ESTE pedido"
(`_ADDR_CONFIRMED_KEY == draft.id`) que a irmã tinha nos outros 2 ramos.

**Causa raiz:** "reusar o mesmo discriminador" foi entendido como "usar as mesmas duas condições
de teste" (`validated`/`formatted`), não "replicar a MÁQUINA DE ESTADOS inteira" (validated+
confirmado / validated+não-confirmado / formatted+não-confirmado / formatted+confirmado). A trava
de confirmação-única-por-pedido vivia justamente na dimensão que ficou de fora. Resultado: um
cliente que troca de modo IDA E VOLTA dentro do mesmo pedido (A→B→A) seria perguntado a confirmar
de novo um endereço que ele já tinha confirmado — exatamente o defeito que a função-irmã foi
escrita para evitar, reintroduzido pela função nova.

**Solução:** ao declarar "reuso do mesmo discriminador" de uma função existente, copiar/chamar a
LÓGICA COMPLETA (todos os ramos, não só a condição de entrada), ou fatorar a lógica compartilhada
num helper único que as duas chamam. Revisão que pega isso: comparar as duas funções LADO A LADO,
ramo por ramo — não só "elas testam a mesma variável?", mas "elas têm o MESMO NÚMERO de ramos?".
Teste que prova a correção: construir o cenário "já confirmado para este pedido" explicitamente e
assertar que a função nova NÃO pede confirmação de novo (não só que ela pede quando
não-confirmado).

**Ref:** revisão de qualidade da Task 6, plano C11/C12 (tiatendo, 2026-08-03) —
`_handleModeSwitch` vs `_awaitConfirm` em `execution/engine/restaurantOrderFlow.py`; fix no commit
`0611949`.

**Relacionado:** [#abandonar-duplicado-sem-trilha-e-estado-efemero] — mesma classe, achada 1 dia
antes no mesmo projeto: uma função nova/irmã que reusa "a mesma lógica" de outra mas só copia
PARTE dos passos/ramos, reintroduzindo o bug que a lógica completa já evitava. Lá era um cleanup
de pedido abandonado (3 passos, uma função só fazia 1); aqui é um discriminador de confirmação de
endereço (4 ramos, a função nova só cobria 2).

**3ª ocorrência, projeto diferente (Família Milionária, 2026-08-07):** `extrairPagamentoDivida`
(bot WhatsApp) já tinha corrigido um "leak" de nome vazando os verbos "quero"/"vou" pra dentro do
campo extraído (achado de review anterior, comentado no próprio código como "Leak 3"). A função
IRMÃ `extrairDividaDeCriacao` — mesmo arquivo, mesma responsabilidade de extrair um nome de texto
livre, só que pro fluxo de CRIAÇÃO em vez de PAGAMENTO — nunca recebeu o equivalente: sua
stopword-list (`_STOP_WORDS_CRIAR`) não tinha "quero"/"cadastrar"/"criar"/"tenho". Sintoma em prod
(print real do usuário): "tenho uma dívida de 5000 mil com o banco, quero cadastrar" virava
nome="Mil Banco Quero Cadastrar" em vez de "Banco". O comentário no código JÁ apontava a lição
("Leak 3") — só não tinha sido replicado pra irmã. Fix + teste: `familia-api/app/modules/whatsapp/
divida_handler.py`, commit `4b6d127`. **Reforça o padrão:** ao corrigir um leak/discriminador numa
função, sempre perguntar "existe uma função IRMÃ com a mesma responsabilidade que também precisa
desse fix?" — grep pelo nome da constante/lista (`_STOP_PAGAMENTO_DIVIDA` vs `_STOP_WORDS_CRIAR`)
teria achado isso em segundos.

---

## CLAUDE.md aponta pro caminho ANTIGO do canon (`_Novo_Projeto`) — script não existe mais, renomeado pra `percus-kit` {#claudemd-caminho-canon-stale}

`tags: canon renomeado, CLAUDE.md desatualizado, percus-review-auto.ps1, caminho stale, _Novo_Projeto, percus-kit, script nao encontrado, pwsh file nao reconhecido`

**Contexto:** CLAUDE.md de projetos (ex.: tiatendo) instrui rodar `pwsh -File
"D:\Claud Automations\_Novo_Projeto\scripts\percus-review-auto.ps1"` antes de cada commit (R11).
O diretório `_Novo_Projeto` não existe mais — o canon foi renomeado pra
`D:\Claud Automations\percus-kit` em 30/07 (já registrado na memória de projeto
`feedback-projeto-escreve-no-canon-e-normal`), mas o CLAUDE.md de pelo menos um projeto não foi
atualizado pra refletir isso.

**Causa raiz:** renomear o diretório do canon é uma mudança cross-repo que não dispara atualização
automática nos `CLAUDE.md` de cada projeto individual — cada um tem a cópia do caminho antigo
hardcoded, e ela só é descoberta quando alguém tenta rodar o comando de verdade.

**Solução:** se `pwsh -File "...\_Novo_Projeto\scripts\..."` falhar com "The argument '...' is not
recognized as the name of a script file", o caminho real é
`D:\Claud Automations\percus-kit\scripts\<mesmo nome>`. Todos os scripts
(`percus-review-auto.ps1`, `percus-milestone-review-auto.ps1`, e as versões `.sh`) migraram
juntos. Vale a pena, ao achar isso num projeto, também corrigir o `CLAUDE.md` dele pra não repetir
a busca na próxima sessão.

**Ref:** sessão tiatendo, 2026-08-03, frente calculadora de demora (S4) — descoberto ao tentar
rodar o wrapper R11 pela primeira vez na sessão.

---

## Python `round()` (half-to-even) e JS `Math.round()` (half-up) divergem em empate exato — "fonte única" que só cobre a tabela, não a função {#python-js-round-tie-diverge}

`tags: banker's rounding, half to even, half up, Math.round, python round, arredondamento, empate exato, tie, dual language, fonte unica incompleta, calculadora`

**Contexto:** feature client-side (calculadora tiatendo) com fórmula "fonte única" — a tabela de
taxas vive em Python e é injetada como JSON pro JS ler, evitando 2 cópias divergentes da TABELA.
Mas a função de arredondamento (`roundToNearestTen`) foi escrita separadamente nas 2 linguagens,
com a MESMA lógica pretendida (`round(v/10)*10`). Um caso de QA manual real (20 pedidos/dia ×
R$20,50 × 15% × 30 = R$1.845,00 exato) revelou: Python devolvia R$1.840, o navegador mostrava
R$1.850 — a mesma fórmula, dois resultados.

**Causa raiz:** `round()` do Python usa banker's rounding (round-half-to-even): `round(184.5)` =
184 (par mais próximo). `Math.round()` do JS sempre arredonda empate pra CIMA: `Math.round(184.5)`
= 185. "Fonte única" cobriu a TABELA (dado), não a FUNÇÃO (lógica) — o mesmo número de entrada
produz saídas diferentes em cada linguagem sempre que o valor intermediário cai num múltiplo exato
de 5 (não só de 10) — bem mais comum do que parece com valores de ticket médio "redondos".

**Solução:** ao portar uma função (não só uma tabela) pra 2 linguagens, teste especificamente o
CASO DE EMPATE (`valor / divisor` terminando em `.5`), não só casos "arredondados por sorte" —
testes com números aleatórios raramente batem numa fração exata de coincidência. Se as 2
linguagens precisam concordar, escolha explicitamente UMA convenção e implemente a MESMA fórmula
nas duas (ex.: `floor(v/10 + 0.5)*10` é half-up em ambas, sem depender do `round()`/`Math.round()`
nativo de nenhuma — assume `v >= 0`; pra domínio com valor negativo, half-up-away-from-zero exige
tratar o sinal à parte).

**Ref:** revisão final holística (subagent), sessão tiatendo 2026-08-03, calculadora de demora
(S4) — `execution/dashboard/publicContent.py::roundToNearestTen` vs
`execution/dashboard/static/js/calculadoraPedidoPerdido.js`, fix no commit `a355e1a`.

---

## `Agent` com `isolation:worktree` pode nascer dezenas de commits atrás da `main` — nunca confie no HEAD sem checar {#isolation-worktree-nasce-stale}

`tags: agent tool, isolation worktree, subagent-driven-development, git worktree, stale, cache, harness, claude code, worktree antigo, dezenas de commits atras, ff-only`

**Contexto:** duas ondas de subagents paralelos (`Agent` tool, `isolation: "worktree"`) contra o
repo tiatendo, sessão 2026-08-03 — 17 tasks no total.

**Sintoma:** **10 dos 17 worktrees nasceram dezenas a ~90 commits atrás da `main` real** — um
chegou a faltar 250 arquivos / +39079 linhas (migrations inteiras, features inteiras). Agentes
sem instrução explícita descobriram sozinhos (comparando `git log --oneline -3` com o que a
tarefa descrevia — números de linha não batiam, funções-modelo que a tarefa citava como "já
corrigidas" ainda não existiam naquela forma) e se autocorrigiram com `git merge main --ff-only`
antes de trabalhar — sempre fast-forward limpo, sem commits divergentes pra perder (nenhum
worktree tinha trabalho próprio ainda).

**Causa raiz:** o mecanismo de `isolation: worktree` do harness aparentemente pode reaproveitar
um worktree/branch em cache de sessão anterior em vez de sempre partir do HEAD atual da `main`.
Comportamento observado da ferramenta, não bug do projeto nem do git.

**Solução:** ao escrever prompts para `Agent` com `isolation: "worktree"` em qualquer repo com
histórico ativo, inclua como **PASSO 0 obrigatório, antes de qualquer leitura de código**:
`git log --oneline -3` seguido de `git merge main --ff-only` (fast-forward puro — seguro por
padrão, só aborta se houver commits locais divergentes, o que não deveria acontecer numa worktree
recém-criada sem trabalho prévio). Isso eliminou o problema por completo na 2ª onda de 11 agentes
desta sessão (todos já chegaram atualizados ou se autocorrigiram sem intervenção). Ao revisar o
retorno de um subagent que trabalhou em worktree isolado, sempre conferir `git log --oneline -3`
do worktree antes de montar/aplicar o patch dele.

**Ref:** sessão tiatendo 2026-08-03, backlog cirúrgico + auditoria da classe (17 fixes,
subagent-driven-development).

---

## Loop de "esperar Postgres ficar pronto" pode declarar sucesso durante o servidor TEMPORÁRIO do entrypoint oficial, e falhar segundos depois no restart {#pg-isready-race-entrypoint-restart}

`tags: postgres, pg_isready, docker entrypoint, initdb, restart, race condition, ephemeral postgres, no response, wait for ready, docker-entrypoint.sh`

**Contexto:** script de Postgres efêmero pra TDD (`scratchpad/dbTestsEphemeral.sh`, tiatendo),
usado por múltiplos subagents concorrentes na mesma sessão 2026-08-03.

**Sintoma:** `docker run` do Postgres reportado como `Up`, mas o script de espera desiste com
"no response" mesmo com retry de até 120s — e uma inspeção manual 10-20s depois mostra o mesmo
container perfeitamente saudável e aceitando conexões. Reproduzido ao vivo duas vezes na mesma
sessão (por dois subagents diferentes, independentemente).

**Causa raiz:** o `docker-entrypoint.sh` oficial da imagem Postgres, quando o volume de dados
nasce vazio, faz: (1) sobe um servidor TEMPORÁRIO (via unix socket) só pra rodar `initdb`/scripts
de init (ex. `CREATE DATABASE`), (2) **derruba esse servidor temporário**, (3) só então sobe o
servidor DEFINITIVO (TCP 0.0.0.0:5432). Um loop de espera que testa `pg_isready` e **quebra no
primeiro sucesso** pode pegar esse sucesso durante a fase (1) — aí a checagem seguinte (ou a
tentativa de conexão real da aplicação) cai exatamente na janela entre (2) e (3), onde NADA está
escutando, e reporta falha mesmo com o banco "logo ali" saudável segundos depois.

**Solução:** não trate o primeiro `pg_isready` bem-sucedido como definitivo — ele pode ser o
servidor temporário do próprio init. Depois do loop principal, adicione um **segundo loop de
confirmação curto** (ex. mais 10-15 tentativas de 1s) antes de declarar falha real; só desista se
a checagem falhar consistentemente por essa segunda janela também. Alternativa mais robusta:
aguardar uma marca no log do container (`docker logs | grep "database system is ready to accept
connections"` contada 2×, já que a mensagem aparece uma vez pro temporário e uma vez pro
definitivo) em vez de só `pg_isready`.

**Ref:** sessão tiatendo 2026-08-03, `scratchpad/dbTestsEphemeral.sh` — fix aplicado ao script
(retry de confirmação de 15s após o loop principal de 120s). Tema irmão (setup de Postgres
efêmero em geral, não esta race específica): `#pg-efemero-testes-destrutivos`.

---

## Duas sessões trabalham na mesma spec sem saber uma da outra — plano completo já existia, commitado num worktree isolado {#duas-sessoes-plano-duplicado-worktree}

`tags: git worktree, sessao paralela, subagent-driven-development, plano duplicado, checkpoint, HANDOFF desatualizado, council-pre-mortem, reconciliacao, ps aux`

**Contexto:** sessão Scraper-prospeccao 2026-08-03. Pedido: "escreva o plano técnico" pra uma spec
já aprovada. Comecei a escrever um plano do zero, achei uma cópia solta (não-commitada) do MESMO
plano no meio do caminho — assumi que era rascunho de sessão anterior interrompida, li e
reconciliei contra ela, rodei council-pre-mortem, atualizei HANDOFF/PLANO como se estivesse tudo
pronto pra execução a partir dali.

**Sintoma:** quando o operador perguntou "não sei mais o que estamos rodando aqui e na outra
sessão", `git worktree list` revelou um worktree isolado (`.worktrees/<nome>`, branch própria) com
**Task 1 e 2 de 12 já commitadas** e seu PRÓPRIO council-pre-mortem já rodado — 2 rounds, achando
problemas diferentes dos que eu tinha achado na cópia solta. `ps aux` confirmou um processo Python
rodando DENTRO do worktree no momento da checagem — execução real, não histórico. A cópia solta que
eu vinha editando desapareceu do disco no meio da investigação (causa não identificada, sem perda
real — o conteúdo autoritativo sempre esteve commitado no worktree).

**Causa raiz:** o protocolo de início de sessão (ler `HANDOFF.md` + `docs/PLANO.md`) não inclui
checar `git worktree list`. Um worktree isolado criado por uma sessão anterior (padrão
"subagent-driven plan execution", já documentado no próprio repo num commit
`chore: ignore .worktrees/`) é invisível pra quem só lê os arquivos de tracking da branch
principal — o worktree tem seu PRÓPRIO `HANDOFF.md`/`docs/PLANO.md`, nunca sincronizado de volta
pra branch principal até o merge final.

**Solução:** antes de escrever um plano técnico novo (ou qualquer trabalho de escopo grande),
rodar `git worktree list` — não só `git log`/`git status` da branch atual. Se existir um worktree
com branch relacionada ao tema, ler o `docs/PLANO.md`/`HANDOFF.md` DENTRO dele (arquivos
separados, não compartilhados) antes de qualquer coisa. `ps aux | grep <nome-do-worktree>`
confirma se há execução ativa AGORA (não só histórico de commits) — evita editar em cima de um
processo em andamento. Ao reconciliar achados de duas fontes paralelas, aplicar as correções
DENTRO do worktree real (ele é a fonte da verdade), nunca só documentar na branch principal como
se fosse lá que a execução acontece.

**Ref:** sessão Scraper-prospeccao 2026-08-03, frente "motor de coleta multi-provider" — commits
`77fc204` (correção aplicada no worktree real) e `b30a906` (correção do HANDOFF/PLANO da branch
principal, virando ponteiro em vez de descrever estado falso).

---

## `sed` de redação de segredo falha quando a entrada vem de `grep -B`/`-A` (prefixo de número de linha quebra o padrão) {#sed-redact-falha-com-grep-contexto}

`tags: bash, sed, redact, segredo, api key, grep contexto, vazamento, tool output, secret exposure`

**Contexto:** sessão Scraper-prospeccao 2026-08-03, tentando localizar um comentário acima de uma
env var sem expor o VALOR da var no output da ferramenta.

**Sintoma:** `grep -n -B3 "^GOOGLE_PLACES_API_KEY=" .env | sed -E 's/=.+/=<redacted>/'` — o `sed`
não redigiu a linha do match; o valor real da API key saiu em texto puro no resultado da
ferramenta (e portanto no histórico/log da sessão). O padrão `s/=.+/=<redacted>/` parecia correto
isolado, mas `grep -n -B3` prefixa a linha de match com `N:` e as linhas de contexto com `N-` — a
linha real (`33:GOOGLE_PLACES_API_KEY=AIzaSy...`) não batia com um padrão testado só contra a
string SEM esse prefixo, e passou inalterada.

**Causa raiz:** testar um padrão de redação contra uma string sintética (sem o prefixo que
`grep -n` com contexto sempre adiciona) e assumir que generaliza. Qualquer regex de redação
ancorada em `^` quebra silenciosamente quando a entrada vem de `grep` com `-A`/`-B`/`-C`.

**Solução:** nunca usar `sed`/regex ancorado em `^` pra redigir segredo vindo de `grep` com
contexto. Alternativas seguras: (1) `grep -c` ou `cut -d'=' -f1` pra confirmar só a
EXISTÊNCIA/nome da variável, nunca o valor; (2) extrair o valor pra uma variável de shell DENTRO
do mesmo processo (nunca via `echo`/print) e usá-lo só em redirecionamento de arquivo (`>>`),
nunca em stdout que vira output de ferramenta; (3) validar formato/conteúdo (é JSON válido? tem o
campo esperado?) rodando um script que imprime só um veredito booleano, nunca o dado em si. Se o
vazamento já aconteceu: risco baixo quando a chave já é restrita (IP allowlist, escopo de API) —
mas considerar rotação por precaução, e nunca repetir o mesmo comando "pra confirmar".

**Ref:** sessão Scraper-prospeccao 2026-08-03, checkpoint de configuração de
`GOOGLE_PLACES_ACCOUNTS` (conta `moacir`).

---

## Teste "travado" via túnel SSH pode ser lento de verdade, não hang — e o túnel morre sob carga sustentada {#tunel-ssh-lento-vs-hang-e-morre-sob-carga}

`tags: ssh tunnel, postgres, asyncpg, timeout, hang, teste lento, faulthandler, connection refused, sqlalchemy nullpool`

**Contexto:** sessão Scraper-prospeccao 2026-08-03/04, Task 11 do plano "motor de coleta
multi-provider". `pytest tests/test_places_worker.py::test_places_query_uses_grid_search_when_target_exceeds_google_cap`
ficava sem nenhum output novo por 10-16 minutos — parecia travado.

**Sintoma:** processo pytest vivo, ~0-2% de CPU (não é loop infinito, é espera de I/O), sem
avançar. Diagnóstico ingênuo ("deve ser deadlock no código") levaria a caçar bug de concorrência
que não existe (o worker é sequencial, sem `asyncio.gather`).

**Causa raiz — duas coisas empilhadas, cada uma real:** (1) um bug genuíno no MOCK do teste
(`get_details` com `return_value` fixo em vez de `side_effect` variando por `place_id`) fazia ~90
resultados de grid colapsarem em upserts repetidos contra o MESMO contato — não travava, mas era
lento à toa e não testava o que alegava. (2) mesmo corrigido, o teste ainda fazia ~180 commits
reais sequenciais via túnel SSH pro Postgres do VPS, a ~1,5-2s cada (medido com script standalone
`faulthandler.dump_traceback_later(N)` + prints de progresso por chamada) — genuinely lento
(~5-8min), não hang. Por fim, sob carga sustentada de HORAS (múltiplas rodadas de suíte grandes
na mesma sessão), o processo `ssh -f -N -L` do túnel **morreu de verdade** 3 vezes (`ssh: connect
... Connection timed out` do lado do cliente; depois disso qualquer `asyncpg.connect()` novo falha
com `TimeoutError`/`ConnectionRefusedError` em cascata pro resto da suíte).

**Solução:** (1) antes de assumir "travou", instrumentar com
`faulthandler.dump_traceback_later(N, exit=False)` + prints de progresso por chamada num script
standalone que replica o cenário fora do pytest — isola rápido se é hang real (stack parado no
mesmo ponto) ou I/O genuinamente lento (progresso visível, só devagar). (2) medir latência real de
round-trip com um engine `NullPool` isolado (`SELECT 1` × N) antes de suspeitar do código — se o
round-trip isolado também está lento/alto, é o túnel, não a lógica. (3) se o processo `ssh` do
túnel sumiu (`Get-Process -Id <pid>` vazio) ou uma nova tentativa de conexão dá "Connection timed
out" na porta 22 (não "refused" — timed out é rede, refused é o daemon recusando), religar:
`ssh -f -N -L 15432:<host-vps>:5432 root@<vps>` e confirmar com `Test-NetConnection` + 1 round-trip
antes de retomar. (4) NUNCA rodar 2 suítes/scripts pesados em paralelo contra o mesmo túnel —
agrava a lentidão real a ponto de parecer travamento. (5) pra suítes de ~900 testes que legitimamente
levam horas, aceitar que o túnel pode cair NO MEIO — se 670+ testes já rodaram verdes antes da
queda e o resto são só `TimeoutError`/`ConnectionRefusedError` em cascata (não asserções falhas
distintas), é 1 evento de infra, não N bugs — não precisa relançar a suíte inteira de novo se cada
arquivo relevante já foi verificado individualmente com túnel saudável.

**Ref:** sessão Scraper-prospeccao 2026-08-03/04, Task 11+review final do plano "motor de coleta
multi-provider" (commits `e217451`, `5585791`).

---

## Fix de guard dependente de sinal do LLM passa 100% dos testes (mockados) e reproduz em PROD — o mock provou a hipótese ERRADA sobre o que o LLM extrai {#mock-sig-llm-hipotese-errada-precisa-smoke-real}

`tags: llm, sig, mock, tdd, teste mockado, hipotese errada, root cause, guard, cancelamento, desired cart, structured output, tool call, smoke real, reproduzir em prod, deterministico, backstop, contrato mockado nao substitui sistema vivo`

**Contexto:** tiatendo, 2026-08-03. Achado no smoke (C14): `"mudei de ideia, vou retirar"` no
meio de um pedido abandonava o rascunho inteiro em vez de trocar o modo de entrega. 1ª hipótese:
o guard de cancelamento (`sig["cancel"]`) não checava se `sig["delivery"]`/`sig["payment"]`
também vieram no mesmo turno — fix aplicado, TDD com `sig[]` mockado à mão (`DesiredCart(cancel=
True, delivery="takeout")`), suíte inteira verde (2510 passed), deployado. **Re-smoke ao vivo em
PROD reproduziu o bug de novo, idêntico.**

**Causa raiz:** o teste mockava um `sig` que **nunca acontece de verdade**. Medido ao vivo (logs +
banco): pra essa frase o LLM devolve `cancelar_pedido=true` com `entrega`/`pagamento` **VAZIOS** —
ele não ignora o segundo sinal, ele nunca tenta extraí-lo, porque pra ele a frase inteira já É
cancelamento. O teste RED/GREEN provou que o CÓDIGO fazia o que o mock mandava — não provou nada
sobre o que o LLM realmente manda. TDD com contrato mockado é necessário mas não suficiente
quando o próprio LLM é a fonte do dado que o teste assume.

⚠️ **Achado colateral que atrasou o diagnóstico:** a evidência de banco (`actor='system:restart'`,
`reason='cliente reiniciou pedido (draft ocioso)'`) parecia apontar pro reset de draft ocioso —
mas essa string está **hardcoded dentro da função de abandono, igual pra QUALQUER caller**
(idade do draft não provava nada; o reset de idade exige horas, o draft tinha 1 minuto). Quando
uma função de auditoria/trilha é compartilhada por múltiplos callers com o MESMO texto fixo, a
trilha não distingue QUAL caminho disparou — é preciso ler o código dos callers, não inferir do
texto da trilha.

**Solução:** pra sinal que depende de extração do LLM E cuja ausência é ambígua (o LLM pode não
extrair por escolha, não por erro), prefira um **backstop DETERMINÍSTICO no texto cru** —
independente do que o LLM decidiu extrair — em vez de confiar só no `sig` estruturado. Aqui:
`detectDeliveryPref(text)`/`_matchPaymentMethod(text, methods)`, as mesmas funções regex que o
caminho sem-LLM já usa. E **todo fix que depende de comportamento do LLM precisa de smoke real
em produção antes de ser declarado fechado** — suíte verde com `sig[]` mockado não é prova
suficiente quando a premissa do teste é sobre o próprio LLM.

**Relacionado:** [#reproduzir-antes-de-fixar] — mesma disciplina geral (reproduzir > teorizar),
aplicada especificamente ao caso onde "reproduzir" significa medir um LLM ao vivo, não só rodar
o comando de novo.

**Ref:** tiatendo, sessão 2026-08-03, commits `7fc88d0` (1ª correção, insuficiente) → `9096377`
(causa raiz real), smoke real em PROD `0.281.0`→`0.282.0`.

---

## `[5-T]` manual mostra página vazia/velha: `netstat` mente sobre qual PID escuta a porta, servidor local zumbi de sessão anterior {#servidor-dev-zumbi-porta-netstat-mente}

`tags: uvicorn, reload, watchfiles, multiprocessing, zombie process, porta presa, netstat mente,
5-T manual, servidor dev, TestClient diverge do browser, PID errado, Windows taskkill`

**Contexto:** tiatendo, 2026-08-03. Ao fazer o `[5-T]` manual de `/roadmap` (`SKIP_DB_BOOT=1
REDESIGN_V2=1 python run.py`, porta 3110), o browser (via Playwright) e `curl` mostravam as 3
seções novas da página **completamente vazias** — só eyebrow/lede, zero fases/features/radar.
Um `TestClient` fresco no MESMO processo Python, importando o app diretamente, mostrava o
conteúdo **correto e completo**. Isso provou que o código estava certo e o servidor rodando
estava servindo outra coisa.

**Causa raiz:** uvicorn com `--reload` roda 2+ processos (reloader + worker, e o worker pode ter
filhos `multiprocessing.spawn`). Uma sessão anterior no mesmo dia tinha deixado processos presos
na porta 3110 sem morrer de verdade. `taskkill //F //PID <X>` no PID que `netstat -ano | grep
3110` reportava **não resolvia** — depois de matar, `netstat` continuava mostrando a MESMA porta
LISTENING, às vezes com o MESMO PID reportado (Windows reaproveita/cacheia essa informação de
forma não-confiável neste ambiente Git-Bash/Windows híbrido). O processo real que estava servindo
a request já tinha um PID diferente do que `netstat` mostrava.

**Solução:** não confie em `netstat -ano` sozinho pra achar o processo certo. Use
`Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Select ProcessId,CommandLine`
(PowerShell) pra ver a **command line completa** de cada processo — isso revela: (a) qual é
literalmente `python.exe run.py`, (b) quais são filhos `multiprocessing.spawn(parent_pid=X)` —
e X aponta pro PID pai que também precisa morrer, mesmo que ele já não apareça mais no
`tasklist`/`netstat` (processo pai pode ter saído mas deixado filho órfão vivo, ou vice-versa).
Mate a ÁRVORE inteira (todos os PIDs relacionados, não só o primeiro que `netstat` apontar),
espere 1-2s, e SÓ ENTÃO confirme porta livre e suba um servidor novo — validando com `curl`
direto (bypassa cache de browser) antes de abrir o Playwright.

**Sinal de alerta pra generalizar:** sempre que um `[5-T]` manual via browser/curl mostrar
resultado DIFERENTE de um teste automatizado que testa a mesma rota (`TestClient` em processo),
suspeite primeiro de servidor local desatualizado/zumbi antes de suspeitar do código — é mais
barato de descartar (kill + restart + `curl` de novo) do que investigar um "bug" que não existe.

**Ref:** tiatendo, sessão 2026-08-03/04, `[5-T]` de `/roadmap` por fases, PIDs 51468/54036/60736/
41148/32520/48836 numa sequência de kills até a árvore inteira morrer.

---

## Subagent commita só os arquivos do PRÓPRIO task — docs/spec editados fora do escopo de nenhuma task ficam esquecidos no disco {#docs-fora-escopo-task-ficam-nao-commitados}

`tags: subagent-driven-development, git add seletivo, checkpoint, docs esquecidos, spec nao
commitado, orquestrador, branch compartilhada, git status`

**Contexto:** tiatendo, 2026-08-03/04. Numa frente conduzida via `subagent-driven-development`
(controller principal escreve spec/plano, dispara um subagent por task), cada subagent seguiu à
risca a instrução de "stage APENAS os arquivos desta task" (disciplina correta pra branch
compartilhada — evita puxar arquivo de outra sessão pro commit). Só que os arquivos de **spec e
plano** (`docs/superpowers/specs/*.md`, `docs/superpowers/plans/*.md`) e uma edição em
`docs/diferenciais.md` foram escritos pelo **controller**, não por nenhum subagent — e como
nenhuma task individual "possuía" esses arquivos no seu escopo declarado, ninguém os commitou.
Ficaram editados no disco por uma sessão inteira (4 tasks + revisões) até o checkpoint seguinte
rodar `git status` no repo inteiro e achar 5 arquivos com trabalho real, nunca versionados.

**Causa raiz:** a disciplina de "stage seletivo por task" (necessária e correta) tem um ponto
cego estrutural: ela protege contra commitar arquivo ALHEIO, mas não garante que TODO arquivo
PRÓPRIO seja commitado — se um arquivo não pertence ao escopo de nenhuma task individual (porque
foi escrito pelo orquestrador antes/entre as tasks), ele cai fora da rede de nenhum dos commits
parciais.

**Solução:** o orquestrador (quem escreve a spec/plano antes de disparar os subagents) é
responsável por commitar os PRÓPRIOS artefatos que ele mesmo criou — não delegar isso a nenhum
subagent, já que nenhum subagent tem esse arquivo no seu escopo. E antes de considerar uma frente
fechada (ou num checkpoint), rodar `git status --short` no repo INTEIRO (não só `git diff
--cached` de cada commit já feito) e perguntar explicitamente: "todo arquivo que EU editei nesta
sessão está commitado, ou só o que os subagents tocaram?"

**Relacionado:** [#duas-sessoes-plano-duplicado-worktree] — outra classe de problema de
coordenação entre múltiplos agentes/sessões escrevendo no mesmo repo, mesma lição de fundo:
verificar o estado real do git, não assumir que "rodou sem erro" implica "está tudo salvo".

**Ref:** tiatendo, sessão 2026-08-03/04, commit `2ba8f09` (5 arquivos: `docs/diferenciais.md` +
4 specs/planos de S5-cardápio-do-dia e roadmap-por-fases, commitados só no checkpoint seguinte).

---

## Script de teste "só código" (.py/.sql) contra Postgres efêmero derruba TUDO que renderiza template ou lê YAML de tenant — 138 falsas-falhas de uma vez {#ephemeral-test-script-so-py-sql-esconde-templates-yaml}

`tags: postgres efêmero, TDD, TemplateNotFound, tenants yaml, test-debt, dbTestsEphemeral,
packaging gap, falsa falha, medir antes de corrigir`

**Contexto:** tiatendo, sessão 2026-08-04. Ao investigar um item de backlog ("48 testes quebrados
pré-existentes, medido X semanas atrás, nunca atacado") rodando a suíte completa contra um
Postgres efêmero real (schema do zero + todas as migrations, via script próprio que sobe um
container throwaway e roda pytest dentro), o resultado inicial foi **198 falhas** — quatro vezes
mais que o esperado. Antes de tratar isso como "198 bugs reais pra corrigir" (o que teria sido um
desperdício monstruoso de esforço perseguindo fantasma), a causa raiz foi investigada primeiro:
**169 das 198** eram `jinja2.exceptions.TemplateNotFound`.

**Causa raiz:** o script de empacotamento (`find execution tests scripts -type f \( -name '*.py'
-o -name '*.sql' \)`) só copiava pro container efêmero os arquivos `.py` e `.sql` — nunca os
templates `.html` (Jinja2) nem os YAMLs de config de tenant (`tenants/*.yaml`). A imagem BASE do
container (reaproveitada só pelas dependências Python já instaladas, pra não pagar `pip install`
toda vez) tinha os templates de uma versão ANTIGA do código — qualquer rota que renderizasse um
template criado DEPOIS dessa versão base quebrava com `TemplateNotFound`, e qualquer teste/fixture
que resolvesse config de tenant pelo YAML em disco (não só via `tenantLoader.getTenant()` em
memória) quebrava do mesmo jeito. Depois de corrigir o find pra incluir `.html` e não excluir
`tenants/`, a contagem caiu de 198 → 60 → 2 (as 2 últimas eram um segundo caso da MESMA classe:
arquivos `.mp3` reais em `static/`, excluído de propósito por tamanho — 33MB de imagens/CSS/JS).

**Sinal de alerta pra generalizar:** quando uma suíte roda contra um ambiente EFÊMERO/isolado
(container throwaway, banco fresco, sandbox) e a contagem de falhas é MUITO maior que o esperado
ou muda pouco entre execuções distantes no tempo mesmo com o código evoluindo bastante, suspeite
do PRÓPRIO AMBIENTE de teste antes de tratar cada falha como bug independente. Agrupe as falhas
por TIPO DE ERRO (não por nome de teste) primeiro — `grep -c "TemplateNotFound"` levou 30 segundos
e mudou o problema de "198 investigações" pra "1 gap de packaging + um punhado de casos reais".

**Solução:** ao escrever/manter um script de "empacota só o necessário pro ambiente efêmero" (por
motivo legítimo de tamanho/velocidade de transferência), audite explicitamente TUDO que o runtime
da aplicação lê em disco além de `.py`: templates (`.html`/`.jinja`), configs (`.yaml`/`.json`),
fixtures de teste que abrem arquivo direto. Excluir por tamanho (ex.: `static/` com imagens) é
válido — excluir por "só código" sem essa auditoria não é.

**Relacionado:** o mesmo processo de investigação achou, DEPOIS de eliminar o artefato de
packaging, um segundo artefato NÃO-relacionado (2ª causa sistêmica descartada por medição, não
suposição): `TestClient(app).post(...)` contra rotas com `BaseHTTPMiddleware` (csrf/csp) — ver
memória `feedback-testclient-basehttp-middleware-drops-post-body` do projeto — que no fim das
contas NÃO apareceu nas falhas reais (tinha sumido junto com o artefato de packaging, não era uma
3ª causa independente). Lição: ter 2 hipóteses de causa sistêmica documentadas ANTES de escavar
falha por falha evitou gastar tempo tentando "consertar" um artefato de ferramenta como se fosse
bug de produto — mas a única forma de saber QUAL hipótese realmente se aplicava foi medir de novo
depois do 1º fix, não assumir que as duas contribuíam.

**Ref:** tiatendo, sessão 2026-08-04, P12 do `docs/PENDENCIAS.md`. Fix do script (untracked,
`scratchpad/dbTestsEphemeral.sh`) + achado colateral de 1 bug de produto real no meio da limpeza
(criar item de cardápio COM variações pelo painel admin dava 500 — `aliases` perdido numa chamada
Python direta que não passa pela injeção de dependências do FastAPI, commit `61cd12c`).

---

## Hook R11 (`PreToolUse` de review antes de commit) tem enforcement inconsistente pra subagents via Agent/Task tool {#r11-hook-inconsistente-subagents}

`tags: R11, pre-commit hook, PreToolUse, subagent-driven-development, plugin hooks, enforcement gap`

**Contexto:** ADS4PROS-Site, sessão 2026-08-04, executando `superpowers:subagent-driven-development`
(8 tasks + 3 fixes, cada uma com implementer subagent + spec-review + quality-review, todos
commitando via `git commit` dentro do próprio subagent). O hook R11 (`hooks/hooks.json` do plugin
`percus-review`, `PreToolUse` casando `Bash|PowerShell` → `pre-commit-check.cmd`) bloqueia a
**sessão principal** de forma confiável — já tinha acontecido 2x na mesma sessão antes disso, sempre
exigindo `/percus-review:review` fresco (<5min) pra destravar. Ao dispatchar subagents pra
implementar+commitar cada task do plano, o comportamento foi **inconsistente**: dois subagents
seguidos, no mesmo repo, mesmo hook instalado — um teve o `git commit` bloqueado normalmente
("review too old", teve que rodar fresco antes de conseguir), outro passou direto sem o hook
disparar nenhuma vez.

**Causa raiz:** não identificada com certeza (não investigado a fundo pra não desviar do objetivo
da sessão). Hipóteses não descartadas: hooks `PreToolUse` registrados via plugin podem não propagar
de forma garantida pro contexto de execução de subagents dispatchados via Agent/Task tool
(dependendo de como o harness isola/herda o processo do subagent), OU há uma condição de corrida
entre subagents concorrentes/dispatch rápido que faz o hook não disparar em alguns casos.

**Sinal de alerta pra generalizar:** ao orquestrar subagents que commitam código em qualquer repo
com hook de pre-commit obrigatório (Percus ou não), **não assumir que o hook é um gate garantido**
só porque funciona de forma confiável na sessão principal — testar (ou instruir explicitamente o
subagent a rodar a review manualmente de qualquer forma, review-ou-não-review) antes de confiar
nessa camada como única linha de defesa.

**Solução:** instruir todo subagent que vai commitar a rodar `/percus-review:review` (ou o wrapper
DeepSeek/cross-claude direto) explicitamente ANTES do `git commit`, independente do hook — às vezes
vai ser redundante (o hook bloquearia mesmo), às vezes é a única camada real de defesa que roda. E
pedir pro subagent colar o **output bruto** da review no relatório de volta (não só a conclusão
"passou"/"falso positivo"), pra o controller poder auditar achados de segurança dispensados sem
confiar cegamente no auto-julgamento do subagent.

**Relacionado:** memória de projeto `feedback_r11_hook_nao_propaga_subagentes` (ADS4PROS-Site).

**Ref:** ADS4PROS-Site, sessão 2026-08-04, feature `assinatura.ads4pros.com` (commits `9e58c17`
bloqueado normalmente vs. commit da Task 5/CopyButton passando sem o hook disparar).

---

## `docker stack deploy` atualiza labels do Traefik mas não recria o container quando a tag da imagem não muda — precisa `service update --force` depois {#stack-deploy-nao-recria-container-tag-igual}

`tags: docker swarm, stack deploy, service update --force, image tag latest, rolling update, traefik labels`

**Contexto:** ADS4PROS-Site, sessão 2026-08-04, deploy de uma feature nova (`assinatura.ads4pros.com`)
que exigia mudança em `docker-compose.yml` (novo host + middleware Traefik) E uma imagem nova
(código novo, mesma tag `ads4pros-lp:latest`). Fluxo: `docker build` local na VPS (gera imagem nova
com hash diferente, mesma tag) → `docker stack deploy -c docker-compose.yml ads4pros-lp`. O deploy
"funcionou" (sem erro), `docker service inspect` confirmou que os labels novos do Traefik (a regra
de host nova) foram aplicados corretamente — mas `docker service ps` continuava mostrando a MESMA
task ID de 3 dias atrás, e `docker inspect` do container confirmou: `Created` continuava sendo de 3
dias antes. A imagem nova (com o código da feature) nunca chegou a rodar.

**Causa raiz:** Docker Swarm compara a SPEC do serviço pra decidir se recria o task. Mudança de
labels é, sim, uma mudança de spec — e nesse caso específico ela FOI aplicada (confirmado via
`docker service inspect`). Mas Swarm não detecta automaticamente que uma tag de imagem já conhecida
(`ads4pros-lp:latest`) agora aponta pra um conteúdo diferente — ele não resolve o digest de novo só
porque a tag já está "resolvida" no seu cache de spec. `docker service update --force` existe
exatamente pra esse caso: força Swarm a re-resolver a referência de imagem e recriar o task, mesmo
com a string da tag inalterada.

**Sinal de alerta pra generalizar:** depois de QUALQUER `docker stack deploy` que envolve build local
de imagem com tag fixa (`:latest` ou qualquer tag reaproveitada, sem digest/registry), **não confiar
que "o comando rodou sem erro" implica "o container novo está rodando"** — checar
`docker inspect <container> --format '{{.Created}}'` (ou `docker service ps` com atenção ao timestamp
"Running X ago") pra confirmar que a recriação realmente aconteceu antes de considerar o deploy
concluído.

**Solução:** depois de `docker build` + `docker stack deploy` com tag fixa reaproveitada, sempre
rodar `docker service update --force <service>` em seguida (não é redundante — trata exatamente esse
gap) e só então validar `Created`/timestamp do container antes de dar o deploy como confirmado.
Cuidado com o aviso já documentado em [[reference_deploy_sequence]] (memória de projeto): não
combinar `service update --force` com `stack deploy` NA MESMA invocação/rodada (dá "update out of
sequence") — rodar em sequência, um depois do outro, é seguro; simultâneo/mesma chamada não.

**Ref:** ADS4PROS-Site, sessão 2026-08-04, deploy de `assinatura.ads4pros.com` — task
`9tahrhjf9rou251m8j5q4mce7` continuou "Running 3 days ago" após `stack deploy` sozinho; resolvido
com `docker service update --force ads4pros-lp_app` na sequência, container recriado com timestamp
correto e feature nova confirmada em produção.

---

## Prefill de checkbox-group via URL param em form embutido de terceiro (GHL) marca a opção ERRADA, não "não funciona" {#ghl-checkbox-prefill-url-inconsistente}

`tags: GoHighLevel, GHL, iframe, form embutido, prefill, URL param, checkbox-group, terceiro`

**Contexto:** ads4agencies-site, sessão 2026-08-04, AutoWorx v2 — o CTA de fechamento de cada
subpágina de serviço deveria levar pro form de quote (`/quote`, iframe GHL
`link.ads4pros.com/widget/form/<id>`) já com o serviço marcado. GHL documenta prefill de campo
simples via URL param (`?first_name=John`) — a suposição natural foi que o mesmo mecanismo
funciona pra um campo checkbox-group (múltipla escolha), passando `?<field_key>=<valor>`.

**Causa raiz:** testado ao vivo (`browser_navigate` direto na URL do widget + `browser_evaluate`
lendo `checked`/`value` de cada `input[type="checkbox"]` real do DOM), o prefill por URL num
checkbox-group do GHL é **inconsistente**: um valor marcou a PRIMEIRA opção da lista (não a
pedida), outro valor não marcou nenhuma. Sem param, nada vem marcado (comportamento base correto).
Não é "não funciona" nem "funciona certo" — é **funciona errado às vezes**, o pior dos três, porque
empurra o lead pro serviço errado em silêncio.

**Sinal de alerta pra generalizar:** qualquer prefill de campo MÚLTIPLA-ESCOLHA (checkbox-group,
multi-select) via URL param em form embutido de terceiro é candidato — a documentação genérica do
provider costuma cobrir só campo de texto/single-value; nunca assumir que o mesmo mecanismo
generaliza pra múltipla escolha sem testar.

**Solução:** não tente pré-marcar campo múltiplo-escolha dentro do iframe de terceiro. Controle o
que dá pra controlar de verdade — a página que hospeda o iframe: mostrar aviso em texto claro
("Interessado em: **X** — selecione abaixo pra confirmar") acima do form, deixar o visitante marcar
manualmente. Pra testar antes de prometer qualquer prefill de form de terceiro: `browser_navigate`
direto na URL do widget/iframe (fora do site) com e sem o param candidato, `browser_evaluate`
lendo `checked`/`value` de cada input real — nunca confiar na documentação genérica do provider.

**Ref:** ads4agencies-site, `WTV2ServiceDetailPage.tsx` + `/quote`, sessão 2026-08-04, form GHL
`gNR1no6QKMlI369FN80d`.

---

## CSS Grid `auto-fit` estica item único/par pra largura total quando sobram poucos itens {#css-grid-autofit-estica-item-unico}

`tags: CSS Grid, auto-fit, auto-fill, minmax, galeria, grid-template-columns, layout quebrado`

**Contexto:** ads4agencies-site, sessão 2026-08-04, `WTV2ProofGallery.tsx` (galeria "More From Our
Shop" de cada subpágina de serviço) — quando sobravam só 1-2 fotos depois de tirar a 1ª pro slot de
destaque, a foto restante renderizava ocupando a largura INTEIRA do container (ou 2 fotos gigantes),
parecendo foto quebrada, não "grid com poucas fotos". Reportado 2x pelo operador na mesma sessão
("já te expliquei").

**Causa raiz:** `grid-template-columns:repeat(auto-fit,minmax(Npx,1fr))` — `auto-fit` colapsa as
colunas implícitas VAZIAS (as que caberiam mas não têm conteúdo) e redistribui o espaço delas pras
colunas que TÊM conteúdo, porque o `1fr` do `minmax` reparte o espaço livre entre as faixas que
sobram. Com 6 colunas cabendo e só 1 item real, as outras 5 colapsam e a 1ª cresce pra ocupar as 6.
`auto-fill` faz a mesma conta de quantas colunas cabem, mas NÃO colapsa as vazias — ficam lá sem
conteúdo, o item real fica no tamanho normal, sobra espaço em branco ao lado.

**Sinal de alerta pra generalizar:** qualquer `repeat(auto-fit,minmax(...,1fr))` aplicado a um grid
cujo número de itens VARIA e pode legitimamente ser 1 (ex.: lista derivada tirando a 1ª entrada pro
slot de destaque) é candidato — testar especificamente o caso de 1 item antes de considerar pronto.

**Solução:** trocar `auto-fit` → `auto-fill` quando a intenção é "cada item no tamanho normal, não
importa quantos couberem" (típico de galeria/proof-gallery). Manter `auto-fit` só quando a intenção
REALMENTE é "os itens existentes devem crescer pra preencher a largura toda" (ex.: grid de cards de
preço onde 3 cards devem ocupar a largura inteira igualmente).

**Ref:** ads4agencies-site, `WTV2ProofGallery.tsx`, sessão 2026-08-04 (AutoWorx v2).

---

## CTA novo pra path interno perde `gclid`/`fbclid`/`utm_*` porque `<KeepQuery/>` nunca foi MONTADO nessa página {#keepquery-precisa-estar-montado}

`tags: KeepQuery, tracking, ad params, gclid, fbclid, utm, data-attribute, contrato de 2 lados, Next.js`

**Contexto:** ads4agencies-site, sessão 2026-08-04, AutoWorx v2 — o CTA de fechamento de cada
subpágina de serviço, antes `tel:`, virou link interno `/quote?service=<nome>`. O componente que
renderiza o botão já marca `data-keep-query` corretamente (condicional em `href.startsWith('/')`),
mas o param de anúncio (`gclid`/`fbclid`/`utm_*`) sumia ao clicar. Achado por review Cross-Claude
(subagente independente) ANTES do deploy, não pelo autor original da mudança.

**Causa raiz:** `data-keep-query` é um MARCADOR, não o mecanismo — quem faz o trabalho de verdade é
o `useEffect` do componente `<KeepQuery/>` (`components/window-tint-v2/KeepQuery.tsx`) rodando na
PÁGINA, reescrevendo o `href` de todo `<a data-keep-query>` com os params da URL de entrada. É um
contrato entre DOIS lugares: o componente que renderiza o link (marca o atributo) e o componente no
topo da página (executa a reescrita). Adicionar um link novo com o atributo certo não implica que o
segundo lado existe naquela página específica — `<KeepQuery/>` não é provider/contexto global, cada
rota tem que montá-lo individualmente. O próprio arquivo já documentava a lacuna em comentário
("mounted only on Home/About/Contact/FAQ... has the same latent gap") — só não tinha virado ação até
o review pegar.

**Sinal de alerta pra generalizar:** qualquer padrão "atributo marcador + componente que faz o
trabalho de verdade em outro lugar da árvore" (não só KeepQuery) quebra em silêncio quando alguém
adiciona o marcador numa página nova sem saber que o componente executor também precisa estar
montado ali. Ao adicionar QUALQUER CTA/link novo apontando pra path interno numa página que antes
só tinha `tel:`/`mailto:`/links externos, confirmar que a página monta o componente executor do
contrato.

**Solução:** montar `<KeepQuery/>` na página nova se ainda não montava. Testar de verdade, não
confiar só em ler código: `browser_navigate` na página com `?gclid=test123` na URL,
`browser_evaluate` lendo o `href` real do link depois do JS rodar — o param tem que aparecer no
destino.

**Ref:** ads4agencies-site, `WTV2ServiceDetailPage.tsx`, sessão 2026-08-04. Achado por review
Cross-Claude antes do deploy.


---

## Teste de presença/ausência de string não prova nada quando o gate é em RUNTIME sobre um template estático {#teste-string-nao-prova-gate-runtime}

`tags: template estático, feature flag, runtime gate, teste de comportamento vs presença de símbolo, JS servido, harness Node, string assertion`

**Contexto:** Paid Media Automation, sessão 2026-08-04/05 — toggle de client-side por plataforma no
loader de tracking (`_LOADER_TEMPLATE`, `services/tracking/app/modules/proxy/router.py`). O plano de
implementação rascunhou testes do tipo `assert "fbq('init',PIXEL_ID)" not in body` pra provar que,
com a flag desligada, o loader servido não instala o Pixel. Um subagente, seguindo TDD à risca,
escreveu o teste, rodou, e viu ele FALHAR mesmo contra uma implementação já correta.

**Causa raiz:** o design escolhido gateia a EXECUÇÃO (`if(PIXEL_ID&&FLAG){ fbq('init',...) }`), não a
PRESENÇA do texto — o corpo da função `fbq('init',...)` é parte do template estático e sai
IDÊNTICO no JS servido tanto com a flag ligada quanto desligada; só o `if` em volta muda de
resultado quando o navegador executa. Um `assert texto not in body` nunca vai conseguir diferenciar
os dois casos, porque o texto é o mesmo nos dois — o teste tal como rascunhado é logicamente
impossível de passar contra qualquer implementação correta que gateie por essa forma (`if(){...}`
em vez de omitir o trecho do template).

**Sinal de alerta pra generalizar:** qualquer feature flag/toggle implementada como `if(condição){
codigo_estatico }` dentro de um template/string que é gerado UMA VEZ e interpretado depois (JS
servido, SQL, template de e-mail, config gerada) tem essa armadilha. Se o plano/spec pede "o corpo
gerado NÃO deve conter X quando a flag está off", pare e confirme: a flag está omitindo X do
template, ou só envolvendo X num `if`? No segundo caso, teste de string está testando a coisa errada.

**Solução:** trocar o teste de "presença de símbolo" por teste de COMPORTAMENTO real — rodar o
artefato servido de verdade num interpretador real (aqui, harness Node mínimo: shim de
`window`/`document`/`dataLayer`, `subprocess.run(["node", tmp_file])`, inspeciona os efeitos
colaterais reais como `typeof window.fbq !== 'undefined'` ou o conteúdo do `dataLayer` capturado).
O subagente confirmou a causa raiz rodando o teste original (errado) contra uma implementação já
correta e vendo-o falhar por construção — prova de que o defeito era do teste, não do código —
antes de reescrever.

**Ref:** Paid Media Automation, `services/tracking/tests/test_loader_script.py`
(`_run_install_effects_harness`/`_run_pmatrack_ga4_harness`), commit `be557929`, sessão 2026-08-04/05.

---

## `git worktree remove` falha com "Invalid argument" (não timeout) quando o worktree tem uma junction do Windows dentro {#worktree-remove-junction-windows}

`tags: git worktree, Windows, junction, mklink, node_modules, Invalid argument, remove failure`

**Contexto:** Paid Media Automation, sessão 2026-08-04/05 — um subagente rodando num worktree git
isolado (`isolation:"worktree"`, sem `npm install` automático) usou `mklink /J` pra apontar
`web/node_modules` pro `node_modules` do repo PRINCIPAL, evitando um install lento só pra rodar
`tsc`/`vitest`. Depois do trabalho concluído, `git worktree remove --force` nesse worktree
específico falhou com `error: failed to delete '...': Invalid argument`.

**Causa raiz:** o deletador recursivo do `git worktree remove` no Windows não sabe lidar direito com
um reparse point (junction) no meio da árvore que está apagando — outros worktrees com
`node_modules` REAL (grande, mas uma cópia normal) só ficavam LENTOS pra apagar (terminavam sozinhos
em segundo plano depois de alguns minutos, não é erro de verdade); a junction dá erro imediato e
consistente, não timeout.

**Solução:** antes do `git worktree remove`, desfazer a junction com `cmd /c rmdir
"<worktree>\web\node_modules"` — isso desfaz só o reparse point (unlink puro), **não** recursa pro
alvo (confirmado contando itens no `node_modules` do repo principal antes/depois: mesma contagem).
Só então `git worktree remove --force` funciona normal. Se `git worktree remove` falhar com
"Invalid argument" especificamente (não um timeout que se resolve esperando), suspeitar de
junction/symlink dentro do worktree antes de qualquer outra hipótese.

---

## API rejeita "invalid unicode code point" com prompt perfeitamente válido — o argv do curl no Windows corrompeu o texto no caminho {#curl-argv-corrompe-utf8-windows}

`tags: curl, MSYS, Git Bash, mingw32, argv, command line, unicode, UTF-8, invalid unicode code point, deepseek, jq --arg, data-binary, council-orchestrator, analyze mode, Windows`

**Contexto:** tiatendo, 2026-08-05 — `/spec-analyze` da spec N19 (`docs/superpowers/specs/2026-08-05-n19-stage-order-bot-paused-design.md`) voltava com "Providers: 1/2" e o DeepSeek reportando erro. O log (`.deepseek/council-log/*-analyze.jsonl`) mostrava `"error": "jq: parse error: Invalid numeric literal at line 1, column 7"`, `"latency_ms": 0` — parecia bug de parsing no orchestrator, mas era sintoma de um bug mais fundo, mascarado por outro (ver verbete irmão abaixo).

**Causa raiz (nível 1, o que a API realmente reclamava):** a resposta real do DeepSeek era texto puro `Failed to parse the request body as JSON: messages[1].content: invalid unicode code point at line 12 column 6401` — mas os 3 provider wrappers (`deepseek.sh`, `groq-llama.sh`, `cross-claude.sh`) assumem que toda falha da API vem em JSON `{"error":{...}}`; `jq -e '.error'` num corpo não-JSON falha calado (`2>&1` suprimido), o `if` conclui "sem erro", o script cai no caminho de sucesso, e o `jq -r '.choices[0]...'` seguinte falha DE NOVO — dessa vez sem supressão — vazando um parse error do jq que não tem nada a ver com a causa real.

**Causa raiz (nível 2, por que a API via unicode inválido num prompt válido):** a spec N19 era UTF-8 perfeito (confirmado por scan de codepoints — zero surrogates soltos, zero decode error — e roundtrip byte-a-byte `--arg` vs `--rawfile`, idênticos). O corpo JSON construído pelo `jq -n` local também validava limpo. O culpado só apareceu num teste A/B direto contra a API real: `curl -d "$BODY"` (corpo como **argumento de linha de comando**) falha; `curl --data-binary @arquivo` com o MESMO conteúdo funciona. O `curl.exe` desta máquina é um build nativo `mingw32` (`curl --version` → `x86_64-w64-mingw32`), e passar uma string longa/multibyte (acentos, travessões, setas — comuns em spec em português) como argv através da fronteira MSYS/Git-Bash → executável Windows nativo corrompe o texto no meio do caminho. Não é bug de conteúdo, é bug de **mecanismo de transporte**.

**Por que só aparece em specs longas/`analyze`, raramente em `review`:** diffs de código são majoritariamente ASCII; prosa longa em português (specs, pre-mortems) tem muito mais acento/travessão/seta por KB — mais superfície pra esbarrar no bug de argv.

**Solução:** nos 3 provider wrappers `.sh`, o corpo do POST passa a ir para um arquivo temp (`mktemp` + `trap 'rm -f "$BODY_FILE"' EXIT`) e o curl usa `--data-binary "@$BODY_FILE"` em vez de `-d "$BODY"` — bytes lidos direto do disco, argv nunca cruza a fronteira. Adicionalmente, a detecção de erro passou a checar `jq -e . ` (é JSON válido?) **antes** de checar `.error`, tratando corpo não-JSON como erro com o texto bruto da API como mensagem — sem isso a causa real fica sempre mascarada pelo segundo jq. `deepseek.ps1`/`groq-llama` via `.ps1` não têm essa classe de bug: `Invoke-RestMethod -Body` não passa por argv de processo nenhum.

**Como caçar isto de novo:** `error: "jq: parse error..."` com `latency_ms: 0` (ou muito baixo) num provider `.sh` não é o bug real — é o SEGUNDO jq falhando depois que o primeiro check de erro já falhou calado. Sempre suspeitar de resposta não-JSON da API antes de mexer no parsing. Se a API disser "invalid unicode"/"invalid character" num payload que parece limpo, teste `--data-binary @arquivo` vs `-d "$VAR"` lado a lado antes de vasculhar o conteúdo — em ambiente MSYS/Git-Bash com curl nativo Windows, o mecanismo de transporte é suspeito tão cedo quanto o conteúdo.

**Ref:** `percus-kit/plugin/percus-review/providers/{deepseek,groq-llama,cross-claude}.sh`, commits `e4c3b32` (detecção de erro não-JSON) e `eb7c6ff` (corpo por arquivo), sessão 2026-08-05.

**Ref:** Paid Media Automation, worktree `agent-aa4a4f9aa6439631a`, sessão 2026-08-04/05.

**Addendum (Scraper-prospeccao, 2026-08-04/05):** mesma classe de sintoma via `council-orchestrator.sh --mode analyze` (não só `deepseek-review.sh`) sobre uma spec de ~150 linhas em português. Antes deste fix ser conhecido, a hipótese de trabalho era "acento quebra o jq" (ver memória `reference_council_orchestrator_ascii_only_windows`) — parcialmente certa por acidente: tirar acento encurta/simplifica a string e às vezes escapa do bug de argv, mas **não é garantia**. Dado concreto que aponta pra causa real (transporte, não conteúdo): rodando a MESMA spec já convertida pra ASCII puro, `cross-claude` falhou com a mensagem **idêntica** ("surrogates not allowed") nas duas tentativas — prova que o problema não estava no conteúdo/acento, batendo com o diagnóstico de mecanismo de transporte acima. Se `council-orchestrator` (não só os scripts de review) ainda exibir esse sintoma depois de um `git pull` do `percus-kit`, confirmar que os commits `e4c3b32`/`eb7c6ff` chegaram no checkout local antes de reabrir investigação do zero.

---

## Next.js: rota de segmento dinâmico compartilhada entre vários "tenants" — `force-dynamic` é por ARQUIVO, não por branch, e desotimiza todos de uma vez {#nextjs-force-dynamic-e-por-arquivo-nao-por-tenant}

`tags: Next.js, App Router, force-dynamic, generateStaticParams, ISR, multi-tenant, rota compartilhada, ads4agencies-site, ssg`

**Contexto:** ads4agencies-site, sessão 2026-08-05 — plano de implementação de um painel de admin que deixa UM lead (site `window-tint-v2`/AutoWorx) trocar foto/vídeo sem rebuild, exigindo que aquele site especificamente leia um manifesto em tempo de requisição. O template serve **425 sites** de leads diferentes através de UM ÚNICO arquivo de rota (`app/[niche]/[slug]/page.tsx`), que ramifica por `archetype` dentro de uma função `Page()` só — 424 desses sites (window-tint v1 + home-services) precisam continuar 100% estáticos (gerados no build), só o 1 site do painel de admin precisava virar dinâmico.

**Causa raiz (o erro que quase foi cometido):** o 1º desenho do plano assumia que dava pra "ligar o modo dinâmico só pra esse 1 lead", já que a ramificação por `archetype` já existe dentro do componente. Errado: `export const dynamic = 'force-dynamic'` (e o irmão `export const revalidate`) no App Router do Next.js é uma exportação **de nível de arquivo/rota**, não de branch dentro do componente — não existe "force-dynamic condicional por parâmetro" nativo (fora de Partial Prerendering, que é experimental/canary e não estava habilitado neste projeto — `next.config.mjs` sem `experimental.ppr`). Marcar o arquivo como dinâmico teria desotimizado a geração estática dos OUTROS 424 sites também — sem erro nenhum, sem teste vermelho, só uma degradação de performance silenciosa em produção que ninguém notaria até reparar.

**Como foi pego:** não em produção — durante a autorrevisão do próprio plano de implementação, ANTES de qualquer linha de código, relendo `app/[niche]/[slug]/page.tsx` inteiro e confirmando que `generateStaticParams()` (uma função só, no topo do arquivo) cobre TODOS os 425 sites de uma vez, então qualquer export de modo de renderização naquele arquivo vale pra todos.

**Solução (padrão generalizável — "proxy de asset", não "página dinâmica"):** em vez de fazer a PÁGINA inteira ficar dinâmica, cada `<img src>`/embed editável do tenant especial passa a apontar pra uma URL de PROXY fixa (ex.: `/api/asset/photo/<id>`) em vez do valor literal — essa string é decidida por uma função **pura e síncrona** (sem I/O, sem `await`) rodando no mesmo lugar de sempre, então a página continua gerada estaticamente, idêntica a antes. A URL de proxy aponta pra um Route Handler **separado** (`app/api/asset/photo/[id]/route.ts`) — Route Handlers no Next.js são dinâmicos por padrão, independente do modo de renderização de qualquer página, então É ELE que lê o dado fresco a cada requisição, sem tocar no arquivo de página nenhum.

**Sinal de alerta pra generalizar:** qualquer app Next.js (ou framework com padrão parecido de "uma rota de segmento dinâmico serve N entidades por parâmetro") onde a pergunta é "preciso que só ESSA entidade específica seja dinâmica, as outras N-1 continuam estáticas" — a resposta nunca é um export condicional dentro do componente. Ou (a) separar a entidade especial pra um path literal que o roteador prioriza sobre o catch-all dinâmico, ou (b) manter a página estática e mover a parte que precisa ser fresca pra um Route Handler à parte, referenciado por URL (o padrão usado aqui). Testar concretamente: depois de implementar, rodar `next build` e conferir no output que TODAS as rotas afetadas (a especial E as N-1 normais) têm o marcador esperado (`●`/`○` estático vs `ƒ` dinâmico) — não presumir pela leitura do código.

**Ref:** ads4agencies-site, plano `docs/superpowers/plans/2026-08-04-autoworx-admin-panel.md` (Scraper-prospeccao), Task 14, sessão 2026-08-05. Achado por pesquisa (`Explore` subagent) nos componentes de apresentação reais antes de finalizar o plano.

---

## Decisão `"council"` do review-router não está nos passos do comando `/review` — e só `deepseek-review.ps1` escreve o marcador de frescor que o hook checa {#council-decision-fora-do-review-doc}

`tags: percus-review, review-router, council, deepseek-review, reviews latest.jsonl, council-log, pre-commit hook, freshness, R11, versao do kit, drift de documentacao`

**Contexto:** Kommo-Disparo-WhatsApp, 2026-08-05 — primeiro commit de um projeto novo (37+ arquivos,
pasta sensível inteira). `/percus-review:review` roda `review-router.ps1 -Json` e devolve
`"decision":"council"`. Os passos do próprio comando `/review` só cobrem 3 ramos —
`"deepseek"`/`"cross-claude"`/`"dual"` — nenhuma instrução pra `"council"`.

**Causa raiz:** `"council"` é decisão nova (`review-router.ps1` docstring: "Fase 6 v6.1.0+", dispara
quando pasta sensível **e** (commit veio do DeepSeek **ou** >10 arquivos)). O texto do comando
`/review` ficou desatualizado em relação ao router instalado — mesmo drift que o health-check da
sessão já apontava ("versão instalada 6.34.0 diferente da do kit 6.34.1").

**O que fazer quando `decision == "council"`:** chamar `council-orchestrator.ps1` direto —
`-Mode review -Providers "deepseek,groq-llama,cross-claude"` (cross-claude via o fallback normal do
marker `__PERCUS_NEEDS_CROSS_CLAUDE__`) — passando o diff (ou um recorte priorizado dos arquivos mais
sensíveis, se o diff inteiro estourar `-MaxInputTokens`) como `-PromptFile`.

**Pegadinha separada, mais cara:** `council-orchestrator.ps1` loga em
`.deepseek/council-log/<timestamp>-<mode>.jsonl` — **NÃO** em `.deepseek/reviews/latest.jsonl`, que é
o arquivo que o hook `pre-commit-check` de fato lê pra decidir se o review está fresco (≤5min). Só
`deepseek-review.ps1` (o wrapper simples do ramo `"deepseek"`) escreve `reviews/latest.jsonl`. Rodar
só o conselho, por mais completo que seja, **não desbloqueia o commit** — o hook bloqueia com
`"nenhum /percus-review:review em .deepseek/reviews/"` mesmo com o council-log cheio. **Solução:**
depois do council (ou junto, se o tempo permitir), rodar `deepseek-review.ps1` sem argumentos
(lê `git diff --cached`+`git diff` sozinho, publica em `reviews/latest.jsonl`) — ele é rápido
(~15-60s) e serve como refresh do marcador de frescor mesmo quando o conselho já fez a análise funda.

**Ref:** Kommo-Disparo-WhatsApp, primeiro commit `a59bd60`, sessão 2026-08-05.

---

## Groq/Llama devolve 413 (Payload Too Large) num diff grande que a DeepSeek aceita — reduzir `-MaxInputTokens` só daquela perna {#groq-llama-413-payload-too-large}

`tags: council-orchestrator, groq-llama, 413, payload too large, MaxInputTokens, truncar, api limit, llama-3.3-70b, deepseek aceita mesmo diff`

**Sintoma:** `council-orchestrator.ps1 -Providers "deepseek,groq-llama,cross-claude"` com um diff de
~14k tokens (`original_token_count`) devolve `"groq-llama: error"` com `"ATENCAO: 2 de 3 pernas
responderam"`. A perna DeepSeek, com o MESMO prompt, responde normal. Retentar a chamada idêntica
falha de novo (não é transitório).

**Causa raiz:** a API da Groq tem um limite de tamanho de payload **HTTP** menor que o da DeepSeek pro
mesmo texto — não é o `-MaxInputTokens` do script (esse só controla a truncagem **client-side** via
`Limit-Prompt`; setar um valor ALTO pra "não truncar" piora o problema, porque manda o payload inteiro
sem cortar). O erro exato aparece em `responses[].error`:
`"Response status code does not indicate success: 413 (Payload Too Large)"`.

**Solução:** re-rodar **só a perna `groq-llama`** (`-Providers "groq-llama"`) com
`-MaxInputTokens` **baixo** (ex. `5000`, abaixo do default de 8000) — isso ativa o `Limit-Prompt`
client-side (preserva ~1000 tokens do início + o resto do fim, avisa
`"prompt truncado de N -> ~5000 tokens"`) e o payload menor passa no limite da Groq. Não precisa
re-rodar DeepSeek/Cross-Claude, que já responderam ao prompt completo.

**Trade-off aceito:** a resposta da Llama nessas condições cobre só um RECORTE do diff (o meio é
cortado) — trate como perspectiva parcial, não substituto do que DeepSeek/Cross-Claude já viram
inteiro. Combina com [#conselho-perna-vazia-teto-tokens] (outra causa de perna degradada) — sintomas
parecidos (`status: error` ou `content` vazio), causas diferentes (413 de payload vs. teto de
`max_tokens`/`reasoning_tokens`).

**Ref:** Kommo-Disparo-WhatsApp, sessão 2026-08-05.

---

## Endpoint muda o formato do payload pra um consumidor novo e quebra os consumidores antigos, silenciosamente (TS não pega, testes não pegam) {#endpoint-reshape-quebra-consumidor-antigo}

`tags: contract change, breaking change, endpoint reshape, migração de formato, tipo fraco em fetch, response.json() as any, consumidor esquecido, integration bug, grep por consumidor`

**Sintoma:** uma rota GET compartilhada por 2+ telas mudou de formato (`ResolvedPattern` flat →
`NamingConfig` aninhado) pra atender a UI nova que motivou a mudança. A tela nova funciona. Uma tela
ANTIGA que consome a MESMA rota, sem relação direta com quem mexeu na rota, quebra inteira com
`TypeError: Cannot read properties of undefined (reading 'X')` — só descoberto ao navegar até ela
num smoke manual, não em `tsc --noEmit` nem na suíte de testes.

**Causa raiz:** `fetch(...).then(r => r.json()).then(d => setState(d.campo))` não tem verificação de
tipo em runtime — o `.then` tipa `d` como o que o dev ESPERA, não o que a rota devolve de fato hoje.
`tsc` não pega porque o tipo do `.json()` é `any` (ou um cast otimista). Os testes não pegam porque
cada teste unitário mocka a rota com o formato que O PRÓPRIO teste já sabe que é certo — nenhum
testa o CONTRATO entre "o que a rota devolve" e "o que cada consumidor espera receber". Pior: se a
rota lê um valor gravado no banco (não só computado), qualquer SAVE feito pela UI nova já migra o
dado real pro formato novo — o bug fica latente até alguém salvar pela tela nova, não só ao fazer
deploy.

**Solução:** antes de mudar o formato de retorno de uma rota compartilhada, `grep` por TODOS os
fetches daquele path (`grep -rn "clientId}/rota-x"` ou equivalente) — não confie em "eu só mudei
a rota que a tela nova usa". Pra cada consumidor achado, decida explicitamente: (a) ele já converte
formato antigo↔novo (grep por `toXConfig`/`adapterFn` perto do fetch — sinal de que já é seguro), ou
(b) precisa do mesmo adaptador que o consumidor "correto" já usa. Ao corrigir, prefira o padrão
"nunca lança, aceita formato antigo OU novo" (uma função tipo `toNewFormat(raw, fallback)` que
detecta o shape em runtime — ex. checando a presença de uma chave só do formato novo) em vez de só
consertar o consumidor quebrado: outros consumidores futuros do mesmo dado herdam a mesma proteção.

**Como achar TODOS os consumidores quebrados, não só o primeiro:** depois de achar e corrigir um,
pergunte "quem MAIS lê essa mesma fonte de dado (mesma tabela/chave), sem passar pela rota que eu já
consertei?" — nesse caso, 2 outras rotas liam a mesma linha do banco via SQL raw direto, cast pro
tipo antigo, sem nenhuma relação de código com a rota já corrigida. `grep` pela CHAVE/tabela no banco
(não só pelo nome da rota) acha esses consumidores paralelos.

---

## `_env()` de `.env` com regex `\s*` cruza quebra de linha quando o valor está vazio {#env-regex-cruza-linha-vazia}

`tags: parser .env, regex value bleed, chave duplicada, valor vazio, \s inclui \n, dotenv custom, N8N_URL vira nome de outra chave, MULTILINE`

**Sintoma:** um cliente Python que lê `.env` via regex customizada (não biblioteca dotenv) devolve,
pra uma chave X, o VALOR LITERAL DO NOME da próxima chave no arquivo (ex.: `_env("N8N_URL")` devolve
`"N8N_USER="`), quando o `.env` tem a chave X duplicada com a primeira ocorrência vazia (`N8N_URL=`
sem nada depois) seguida de outra linha com o valor real mais adiante no arquivo.

**Causa raiz:** regex do tipo `^\s*NOME\s*=\s*(.+?)\s*$` com `re.MULTILINE` — o `\s*` ENTRE o `=` e o
grupo de captura inclui `\n`. Quando a linha da chave termina logo após o `=` (valor vazio), esse
`\s*` engole a quebra de linha e o motor de regex continua tentando casar `(.+?)` a partir do INÍCIO
da próxima linha — que é o texto de outra chave (`NOME_SEGUINTE=`). Como `(.+?)` só exige 1+ caractere
não-newline, ele casa com o nome da próxima chave inteiro, e o `$` (fim de linha em modo MULTILINE)
fecha o match exatamente no fim daquela linha. O bug só aparece quando (a) a chave tem uma ocorrência
VAZIA no arquivo E (b) existe uma próxima linha com conteúdo — passou despercebido em testes porque
eles sempre faziam monkeypatch da função `_env()` inteira, nunca exercitavam a regex contra um
arquivo real com esse padrão de duplicação.

**Solução:** trocar `\s*` por `[ \t]*` nos dois lados do valor
(`^[ \t]*NOME[ \t]*=[ \t]*(.+?)[ \t]*$`) — exclui `\n` da classe de espaço, então o match nunca
atravessa linha. Uma chave com valor vazio simplesmente NÃO CASA (o `(.+?)` exige 1+ char), e
`re.search` continua escaneando até achar a próxima ocorrência (populada) da mesma chave — preserva
o comportamento desejado de "pular vazia, achar a preenchida" sem o vazamento pra chave errada.
Escrever teste de regressão direto contra um arquivo `.env` real (via `tmp_path`), não só mockando
`_env()`, é o que teria pego isso antes.

**Ref:** Kommo-Disparo-WhatsApp, sessão 2026-08-05 (`lib/kommo_client.py` + `lib/n8n_client.py`,
mesma função duplicada nos dois arquivos por design do projeto).

---

## Credencial n8n apontando pra hostname interno Docker que nunca vai resolver: n8n e Postgres podem estar em VPS diferentes {#n8n-postgres-vps-diferentes}

`tags: n8n credential, postgres host, docker internal hostname, service discovery, DNS de servico externo, firewall bloqueia porta, assumir mesma rede sem verificar, topologia multi-vps`

**Sintoma:** ao criar uma credencial Postgres nova pra um n8n existente, a suposição natural é usar o
hostname interno do Docker Swarm (ex. `postgres_postgres`, o nome do SERVICE) como Host, porque uma
variável de ambiente do próprio n8n (`DB_POSTGRESDB_HOST=postgres_postgres`) parece confirmar isso.
A suposição está ERRADA quando o n8n de fato usado (a URL pública que o operador informa, tipo
`https://xxx.dominio.com.br`) roda numa MÁQUINA DIFERENTE do VPS onde o Postgres está hospedado —
hostname interno de Docker Swarm só resolve dentro da mesma rede overlay, na MESMA máquina.

**Causa raiz:** `DB_POSTGRESDB_HOST` (ou variável equivalente) presente num `.env`
compartilhado/herdado não prova que aquele valor se aplica ao n8n que você está de fato configurando
— pode ser resquício de outro ambiente/instância n8n que roda na MESMA máquina do Postgres. Verificar
isso exige checar a TOPOLOGIA real, não confiar na variável.

**Solução (ordem de verificação, do mais rápido ao mais definitivo):**
1. DNS do hostname público do n8n — se o IP resolvido for DIFERENTE do IP do VPS do Postgres, já
   descarta hostname interno Docker de cara.
2. Testar conexão TCP direta na porta do Postgres a partir de QUALQUER máquina externa (não precisa
   ser o n8n) — se travar/recusar, há firewall bloqueando por design (`iptables -L DOCKER-USER`
   mostra a regra DROP explícita), o que é esperado/correto pra um Postgres compartilhado não devia
   estar exposto cru pra internet.
3. **Mais confiável de todos:** pedir pro operador abrir uma credencial Postgres JÁ EXISTENTE E
   FUNCIONAL no mesmo n8n (se houver outro projeto configurado lá) e olhar o campo Host na UI — a UI
   do n8n mostra host/porta/database/user em texto claro (só a senha é mascarada). Ground truth
   direto, sem precisar adivinhar topologia de rede.

**Trade-off:** pular a verificação e confiar só na variável de ambiente herdada teria produzido uma
credencial que falharia silenciosamente (timeout) só na hora de testar/ativar o workflow — mais caro
de debugar depois do que verificar antes de criar.

**Ref:** Kommo-Disparo-WhatsApp, sessão 2026-08-05 (`execution/setup_n8n_credentials.py`).

**Ref:** Paid Media Automation, cont.150, sessão 2026-08-05.

---

## Upload de arquivo pra VPS via Bash falha com erro de bash confuso ("C:/Program: No such file", "X: No such file or directory") mesmo pra arquivo pequeno {#vps-upload-msys-path-mangling}

`tags: paramiko exec_command falha, sftp falha, upload VPS, git bash MSYS path translation, argv reescrito, ConnectionResetError SSH, git bundle grande, scp alternativa, ssh exec_command chunk`

**Sintoma:** um script Python (paramiko) que faz upload de arquivo pra VPS via
`client.exec_command(f"cat > {remote_path}")` + `stdin.write(data)` falha com um erro de BASH sem
sentido (`bash: line 1: C:/Program: No such file or directory` ou
`bash: line 1: C:/Users/.../algum-arquivo: No such file or directory`), mesmo passando um
`remote_path` Unix válido tipo `/tmp/foo.txt` e mesmo pra um arquivo de poucos KB. O erro muda de
forma entre tentativas (às vezes aponta pra um caminho totalmente disparatado). Tentar `SFTP` puro
(`paramiko.SFTPClient.put`) no lugar falha diferente: `FileNotFoundError: [Errno 2] No such file`
mesmo com o diretório remoto existindo — sinal de que o subsistema SFTP do `sshd` está desabilitado
nessa VPS especificamente (não é erro de path).

**Causa raiz (a do exec_command+stdin):** rodando de Git-Bash/MSYS no Windows, QUALQUER argumento de
linha de comando com cara de path Unix (`/tmp/...`) passado pra um programa (mesmo `python script.py
"/tmp/foo"`) é reescrito pelo MSYS pra um path Windows ANTES do programa receber o argv — e se
`/tmp` não for um mount real nessa máquina, a reescrita produz um path bizarro tipo
`C:/Users/.../AppData/Local/Temp/foo`. O script recebe esse path MANGLED como `remote_path`, monta
`cat > C:/Users/.../foo` como comando remoto, e o bash do LADO REMOTO (Linux) tenta interpretar esse
texto — dependendo de como a string chega (quebra de linha, aspas), o resultado é um dos dois erros
confusos acima. O bug não depende do tamanho do arquivo — só de o `remote_path` ter chegado como
argumento de linha de comando (`sys.argv`) em vez de estar hardcoded dentro do `.py`.

**Solução:**
1. **Nunca passe path remoto Unix-style como argumento de bash pra um script Python** — hardcode o
   `remote_path` como constante DENTRO do arquivo `.py` (escrito via Write/Edit tool, não via
   `sys.argv`). Uma string literal lida do próprio código-fonte do script nunca passa pelo
   parser de argv do MSYS.
2. Pra arquivo GRANDE (testado com bundle git de 8,8MB): SFTP indisponível e um `exec_command` só
   com todo o base64 embutido (~11,7MB de texto) trava a conexão
   (`ConnectionResetError: [WinError 10054]`) em chunks acima de ~800KB pré-base64. **Funciona**:
   quebrar em chunks de **50KB** (pré-base64), cada um em `exec_command(f"echo '{b64chunk}' |
   base64 -d >> {remote_path}")` sequencial, com `rm -f {remote_path}` antes do primeiro chunk. 177
   chamadas de exec_command pra 8,8MB rodou sem erro nenhum; 800KB por chunk (11 chamadas) derrubava
   a conexão de forma consistente e reproduzível — o limite parece ser do lado do servidor (rate
   limit de canal SSH ou tamanho de comando), não do cliente.
3. Verificar sempre com `stat -c %s {remote}` no fim e comparar com o tamanho local — silêncio não
   prova integridade.

**Trade-off:** chunking em 50KB é ~3-4x mais chamadas de rede que o "chunk ótimo" ingênuo (800KB),
mas cada chamada é rápida (<1s) e o custo total pra 8,8MB foi menos de 2 minutos — preferível a
descobrir o limite exato do servidor por tentativa e erro repetida.

**Ref:** Paid Media Automation, cont.151, sessão 2026-08-05 (deploy da frente Google Ads multi-conta,
`scripts/vps_exec.py`/`scripts/vps_upload_stream.py`).

**Addendum (cont.153, 2026-08-06) — um SEGUNDO bug distinto na mesma área, sintoma diferente:**

Rodando `python scripts/vps_exec.py "<comando com um chunk base64 embutido>"` a partir do Bash tool
(Git-Bash), a partir de ~37.000 caracteres no comando o processo TRAVA ANTES de sair da máquina, com
`/c/Python314/python: Argument list too long` — isso **não é** o path-mangling do MSYS descrito acima
(o `remote_path` aqui já estava hardcoded no script, não vinha de argv) e **não é** limite de SSH nem
do servidor: é o teto do próprio Windows/MSYS pra tamanho total de linha de comando ao invocar
`python.exe` via `execve()`. Testado por bisseção: 20.000 e 24.000 caracteres OK, 37.000 falha —
o teto real fica em algum ponto entre esses dois valores.

**Fix que NÃO funciona:** passar o payload grande via arquivo lido por `sys.argv` (ex.: `python
script.py caminho_do_arquivo.txt`) e o script ler o conteúdo internamente — isso evita o problema
do lado do CLIENTE, mas o `paramiko.exec_command()` ainda manda a string inteira como comando remoto
via protocolo SSH, e o **próprio canal SSH tem um teto bem menor que o esperado**: testado com um
payload de ~1,3MB (bem abaixo do ARG_MAX típico do Linux) e a conexão caiu com
`paramiko.ssh_exception.SSHException: Timeout opening channel` / `EOFError` ao tentar abrir a sessão
— o servidor (ou algo no caminho, ex. firewall/fail2ban) rejeita o `SSH_MSG_CHANNEL_REQUEST` de exec
acima de um tamanho bem mais modesto que 1MB. **`scripts/vps_upload_stream.py` (stdin streaming via
`cat > file` + `stdin.write()`) foi testado de novo nesta sessão e CONFIRMADO quebrado** — falha com
`OSError: Socket is closed` mesmo pra um arquivo de poucos MB. Não gastar tempo tentando de novo sem
investigar por que o canal cai (suspeita: mesmo limite de tamanho de payload, não é bug do método).

**Fix que funciona (rápido) — uma conexão paramiko reaproveitada, chunk de ~20-24KB:**
1. Escreva o comando remoto (`echo -n '<chunk>' >> {remote_path}`) já com o chunk embutido, mas
   NUNCA deixe o Bash tool montar isso como um argv de 30KB+ pro `python.exe` — ou grave o chunk num
   arquivo `.py` temporário (constante hardcoded) e rode sem argumento, ou (mais simples) faça um loop
   em bash que escreve cada chunk em ARQUIVO e invoca o script uma vez por chunk com esse arquivo como
   único argumento pequeno (caminho, não o conteúdo).
2. **Reaproveite UMA conexão `paramiko.SSHClient` pra todos os chunks** em vez de reconectar a cada
   `vps_exec.py` (cada `connect()` novo é o gargalo dominante, não o tamanho do comando) — isso reduz
   um upload de ~8MB base64 (335 chunks de 24.000 chars) de dezenas de minutos pra ~4 minutos.
3. **Mas a mesma conexão aceita só ~80-120 `exec_command` sequenciais antes do sshd recusar** com
   `Timeout opening channel` — feche e reabra a conexão a cada ~80 chunks (não precisa retomar do
   zero: cheque `wc -c {remote_path}` pra saber de onde continuar).
4. Verifique sempre `wc -c {remote}` no fim comparado ao tamanho local esperado.

**Técnica nova pra evitar mandar histórico de git inteiro:** quando o deploy precisa só do SNAPSHOT
atual (não do histórico), um bundle completo (`git bundle create x.bundle HEAD`) de um repo com
milhares de commits pode passar de 8MB — e um bundle incremental (`git bundle create x.bundle
base..HEAD`) exige que o destino já tenha o commit `base`, o que falha se o checkout de produção
estiver numa linhagem de branch diferente da local (`error: Repository lacks these prerequisite
commits`). Solução: criar um commit SEM PAI que é só uma foto do working tree atual —
`TREE=$(git write-tree) && COMMIT=$(git commit-tree "$TREE" -m msg) && git update-ref
refs/heads/tmp-squash "$COMMIT" && git bundle create out.bundle tmp-squash && git update-ref -d
refs/heads/tmp-squash` — o bundle resultante não tem NENHUM pré-requisito (é uma raiz nova), então
`git clone out.bundle repo && cd repo && git checkout tmp-squash` funciona em qualquer máquina, do
zero, e o bundle fica muito menor (só os blobs do estado atual, sem deltas históricos). `git bundle
create` recusa "empty bundle" se você passar um SHA de commit direto sem ref — sempre crie um ref
temporário primeiro.

**Ref:** Paid Media Automation, cont.153, sessão 2026-08-06 (deploy de 6 correções + feature
HubSpot D4U, tag `d4u-369d2dbe`).

---

## Review R11 (DeepSeek) devolve "Sem findings críticos" mas viu só um pedaço do diff — truncamento silencioso em diffs grandes {#r11-diff-truncation-silent}

`tags: council-orchestrator, deepseek review, prompt truncado, diff grande, false confidence, avaliar so metade do codigo, revisao incompleta parece completa`

**Sintoma:** rodar `council-orchestrator.ps1 -Mode review` num diff grande (~3000 linhas, ~40k
tokens) devolve `"Sem findings críticos"` de forma limpa — parece um review completo e tranquilizador.
O JSON de resposta tem uma linha fácil de não notar no meio do output:
`"[council-orchestrator] AVISO: prompt truncado de 40891 -> ~8000 tokens."` seguida de
`"truncated": true` no JSON. O truncamento corta do MEIO (mantém início e fim do diff), então os
arquivos mais centrais/críticos do diff (que caem no meio alfabético/posicional) podem nunca ter
sido vistos pelo revisor — o "sem findings" não é "revisei e está limpo", é "revisei metade e a
metade que vi está limpa".

**Causa raiz:** o wrapper do provider (DeepSeek/Groq) tem um teto de contexto de prompt bem menor que
o que o Claude Code consegue montar num diff real de uma sessão longa — sem um teto explícito, o
comportamento default é truncar em vez de falhar, e o aviso de truncamento fica fácil de perder no
meio de um JSON grande.

**Solução:** antes de aceitar um "Sem findings críticos" como válido pra um diff grande, checar
explicitamente `"truncated"` no JSON de resposta (ou o aviso de stderr). Se truncou: dividir o diff
em pedaços por arquivo/módulo lógico (cada `git diff -- <paths>` separado, um por chunk) e rodar o
review em cada pedaço independentemente — cada chamada then cabe no teto de ~8000 tokens do provider.
Reconsolidar os achados de todos os pedaços antes de decidir se o commit está limpo. Achados que
citam um arquivo/trecho que NÃO estava no chunk revisado (ex.: um revisor comentando sobre um arquivo
que só apareceu num chunk diferente) são sinal de que o revisor está alucinando contexto que nunca
viu — desconfie e verifique manualmente.

**Trade-off:** dividir em N chunks custa N chamadas de review em vez de 1, mas cada chunk cabe
inteiro no contexto do provider — a alternativa (1 chamada só, confiando no truncamento) já produziu
nesta sessão um review que teria dado "aprovado" pulando o arquivo com a lógica de merge mais crítica
do diff inteiro (`destinations.py`, onde 2 bugs reais foram achados quando revisado em separado).

**Ref:** Paid Media Automation, cont.151, sessão 2026-08-05 (R11 da Fatia 2 do Google Ads
multi-conta).

---

## `docker service inspect | grep VAR` confirma que a CHAVE existe, não que o VALOR é não-vazio — integração ficou meses no-op silencioso {#docker-inspect-presente-nao-e-valor}

`tags: env var vazia, docker service inspect, PRESENT check enganoso, integracao nunca funcionou, secret vazio em producao, docker-compose interpolacao vazia, verificacao superficial de config`

**Sintoma:** primeira aceitação real de um fluxo (proposta de venda) que deveria criar um contato
num CRM externo (GoHighLevel) via API não gerou nada do lado do CRM — sem erro visível, sem
exceção, o app continuou funcionando normalmente (a integração é best-effort/no-op silencioso por
design). Um check anterior, feito em sessão passada, tinha "confirmado" as credenciais como
`PRESENT` via `docker service inspect ... | grep VAR`.

**Causa raiz:** o `.env` da VPS tinha as chaves (`GHL_PIT_TOKEN=`, `GHL_LOCATION_ID=`) mas com
**valor vazio** — nunca foram de fato preenchidas, só declaradas. `docker-compose.yml` interpolava
`${GHL_PIT_TOKEN:-}`, que aceita string vazia sem erro. O código de integração checava
`if (!token || !locationId) return { skipped: true }` — um guard correto, mas que faz a ausência de
config parecer indistinguível de "tudo certo, só não tem trabalho a fazer" nos logs. O check de
verificação usado antes (`docker service inspect --format '...Env...' | grep VAR | sed
's/=.*/=PRESENT/'`) tem um bug sutil: `sed 's/=.*/=PRESENT/'` casa `VAR=` (valor vazio) do mesmo
jeito que casa `VAR=algumacoisa` — `.*` aceita zero caracteres. O resultado impresso
(`GHL_PIT_TOKEN=PRESENT`) é **sempre verdadeiro que a chave existe**, nunca informa se tem valor.
Isso mascarou o problema por meses (nenhuma proposta aceita gerou contato no CRM desde que a
integração foi implementada).

**Solução:** pra confirmar que uma env var tem **valor**, não só existe como chave, use
`docker exec <container> env | grep VAR` (mostra `VAR=valorreal`, inclusive se vazio — `VAR=` sem
nada depois é visualmente óbvio) — ou, se for secret que não pode aparecer em texto, comparar
`length` (`docker exec <container> node -e "console.log(process.env.VAR?.length)"`). Nunca confiar
num `sed`/regex que substitui o valor por um marcador fixo tipo `PRESENT` sem primeiro checar se o
valor capturado tinha conteúdo — esse padrão de "check de presença" é enganoso por construção.

**Trade-off:** nenhum — o check com `docker exec ... env` é tão rápido quanto o `service inspect`,
só que correto. Vale substituir esse padrão em qualquer runbook/memória que ainda recomende
`service inspect` pra validar secrets.

**Ref:** ADS4PROS-Site, sessão 2026-08-05 (incidente GHL — proposta Tiffany Driving School aceita
sem gerar contato no CRM; ver `HANDOFF.md` §0-C).

---

## `console.log(objeto)` trunca aninhamento como `[Object]` e esconde o erro real de uma integração que "falhou sem motivo" {#console-log-objeto-trunca-oculta-erro}

`tags: node console.log truncamento, object depth padrao, log estruturado incompleto, erro escondido no log, util inspect depth, debugging as cegas`

**Sintoma:** um log estruturado (`console.log('[evento]', { ...campos, resultado: {...aninhado} })`)
mostrava o campo aninhado como `resultado: { upsert: [Object], note: [Object] }` — sem nenhum
detalhe do que de fato aconteceu (`ok`, `error`, `status`). Impossível diagnosticar uma falha de
integração externa só olhando o log em produção; precisou reproduzir a chamada manualmente pra
descobrir o erro real.

**Causa raiz:** `console.log` do Node usa `util.inspect` por baixo dos panos, que por padrão só
desce **2 níveis** de profundidade em objetos aninhados antes de substituir por `[Object]`/`[Array]`.
Um objeto de resultado com 2+ níveis de aninhamento (comum em respostas de API — `{ upsert: { ok,
status, data: {...} }, note: {...} }`) estoura esse teto silenciosamente. Não há warning, não há
erro — o log simplesmente perde informação, e quem lê não tem como saber que perdeu.

**Solução:** pra log estruturado que vai ser lido depois (arquivo, `docker service logs`, sistema de
observabilidade), nunca passar o objeto direto pro `console.log` — usar `console.log('[tag]',
JSON.stringify(objeto))`. `JSON.stringify` não tem teto de profundidade (serializa tudo, exceto
referências circulares). Alternativa se precisar manter objeto navegável no terminal interativo:
`console.log(util.inspect(objeto, { depth: null }))`.

**Trade-off:** `JSON.stringify` perde a formatação colorida/indentada do `util.inspect` no terminal
— pra debugging interativo local, `depth: null` é mais legível; pra log de produção que vai ser
grepado/parseado depois, `JSON.stringify` (uma linha, sem truncamento) é estritamente melhor.

**Ref:** ADS4PROS-Site, sessão 2026-08-05 (`app/api/proposal-accept/route.ts` — log `[proposal-accept]`
escondia o motivo real da falha do GHL atrás de `[Object]`, atrasou o diagnóstico do incidente de
credenciais vazias).

---

## Revision id de migration Alembic estoura `alembic_version.version_num VARCHAR(32)` — health check standalone pega ANTES do cutover {#alembic-revision-id-varchar32}

`tags: alembic, migration, revision id, varchar32, StringDataRightTruncation, health check standalone, crash-loop, entrypoint fatal, deploy gate`

**Sintoma:** container novo sobe, roda `alembic upgrade head` no entrypoint, e morre com
`sqlalchemy.exc.DataError: (psycopg2.errors.StringDataRightTruncation) value too long for type
character varying(32)` no `UPDATE alembic_version SET version_num='<revision>' WHERE ...`. O
container nunca fica `healthy`, então nunca chega perto de receber tráfego real — mas SÓ porque
havia um health check standalone rodando ANTES do `docker service update` do cutover. Sem esse
passo, o `docker service update` teria trocado o serviço em produção pra uma imagem que crash-loopa
no boot.

**Causa raiz:** o Alembic cria `alembic_version.version_num` como `VARCHAR(32)` por padrão (não é
configurável sem migração própria da tabela). Um nome de arquivo de migration descritivo demais
(`0036_event_log_google_ads_dispatches.py`, `revision = "0036_event_log_google_ads_dispatches"`,
36 caracteres) estoura o teto — e nada no `alembic revision`/`alembic upgrade` local avisa disso
antes de bater no banco real, porque testes contra Postgres efêmero recém-criado (sem histórico de
migrations anteriores) não necessariamente exercitam o `UPDATE` final se o teste só confere o shape
da tabela, não o fluxo completo do alembic runner.

**Solução:** manter todo `revision`/nome de arquivo de migration ≤32 caracteres — ex.:
`0036_gads_dispatches_col` (24 chars) em vez do nome descritivo completo. Se já commitou com um
nome longo e ele NUNCA chegou a aplicar de verdade em nenhum ambiente (confirmável: erro apareceu
na primeira tentativa, banco de dados single-environment, sem staging separado), é seguro renomear
o arquivo + a string `revision` livremente — o Alembic usa o CONTEÚDO do arquivo pra montar a cadeia
(`down_revision`), não o nome do arquivo; renomear não quebra nada desde que a string antiga nunca
tenha sido persistida em `alembic_version` de verdade. Confirme isso lendo o log do container que
falhou: se o erro veio do `UPDATE ... SET version_num=...` (não do `INSERT`/estado inicial), o
Postgres é transacional em DDL — a migration inteira (incluindo o `ALTER TABLE` que rodou antes)
sofreu ROLLBACK junto com o `UPDATE` que falhou, sem deixar rastro.

**Por que isso não quebrou em sessões anteriores deste mesmo projeto:** todas as migrations
anteriores (`0001` a `0035`) por acaso ficaram ≤32 chars — o teto nunca foi testado até uma
migration com nome mais longo aparecer. Não é uma regra nova do projeto, é um limite estrutural do
Alembic que sempre esteve lá, invisível até bater nele.

**Trade-off:** nenhum — o nome curto ainda é descritivo o suficiente (o docstring da migration no
topo do arquivo carrega o contexto completo; o nome do arquivo só precisa ser único e legível o
bastante pra `alembic history` fazer sentido).

**Ref:** Paid Media Automation, sessão 2026-08-05/06 (Google Ads multi-conta, Fatia 5 — migration
`0036`, pego pelo health check standalone rodado com a `DATABASE_URL` de produção ANTES do
`docker service update` de cutover; ver commits `a21ab757`/`5641cae9`).

---

## Subagente que promete "reporto quando terminar" um comando em background não retoma sozinho — precisa de outro SendMessage {#subagent-background-promise-nao-se-cumpre-sozinho}

`tags: subagent-driven-development, Agent tool background, run_in_background dentro de subagent, TaskOutput no task found, falsa promessa de auto-relatorio, controller precisa cutucar, notificacao nao dispara, code-quality reviewer travado`

**Sintoma:** o controller despacha um subagent (via Agent tool, ex.: revisor de qualidade de código
dentro de `subagent-driven-development`) que precisa rodar um comando demorado (ex.: suíte de testes
completa, ~7min) pra concluir seu próprio trabalho. O subagent roda esse comando via seu Bash tool
com `run_in_background`, e responde ao controller algo como "vou aguardar terminar e reportar
automaticamente — não vou ficar consultando". O turno do subagent **termina ali** (a
task-notification que chega pro controller já vem com `status: completed`). Nenhuma notificação nova
chega quando o comando em background de fato termina — o trabalho fica parado indefinidamente até o
controller (ou o operador) notar e agir. `TaskOutput(task_id=<agentId do subagent>, block=false)`
retorna `No task found with ID`, confirmando que não há nada rastreável rodando daquele lado.

**Causa raiz:** a promessa "vou reportar quando terminar" só se cumpre se o PRÓPRIO subagent for
re-acordado por uma notificação do seu comando em background — e essa auto-retomada não é garantida
pelo harness. Um `run_in_background` de Bash chamado *dentro* de um subagent não tem, por padrão, o
mesmo mecanismo de "aguarde e seja notificado sem polling" que o controller top-level tem pra Agents
despachados por ele. O resultado observável: o subagent "para de existir" (turno encerrado) sem que
o comando backgrounded o traga de volta sozinho.

**Solução:** o controller não deve confiar na promessa de auto-retomada de um subagent que
backgrounded algo internamente. Sinal de alerta: a task-notification do subagent chega com
`status: completed`, mas o `<result>` diz algo como "vou reportar quando terminar" / "standing by" —
ou seja, o subagent claramente não terminou o TRABALHO, só terminou o TURNO. Nesse caso, o controller
precisa mandar um `SendMessage` de follow-up explícito pro mesmo agente (usando o `agentId` — nomes
continuam funcionando depois que o agente "termina"), pedindo status atual ou — melhor, se o comando
é curto o bastante pra caber num turno — pedindo pra rodar de novo em **foreground** dessa vez (sem
`run_in_background`), garantindo que o turno do subagent só encerre depois do resultado real chegar.

**Trade-off:** pedir foreground custa mais tempo de espera bloqueada nesse `SendMessage` específico
(o controller fica esperando o subagent inteiro, não só um resultado assíncrono), mas é estritamente
mais confiável que apostar numa retomada automática que pode não vir — vale a troca pra comandos de
verificação de poucos minutos (ex.: suíte de testes). Pra comandos MUITO longos (dezenas de minutos),
considere em vez disso reestruturar o trabalho pra o CONTROLLER rodar o comando demorado ele mesmo
(via `Bash` com `run_in_background=true`, que o controller sabe aguardar sem polling de verdade) e só
passar o resultado pro subagent revisar, em vez de delegar o comando longo pro subagent rodar sozinho.

**Ref:** tiatendo, sessão 2026-08-05/06 (N19 — code-quality reviewer subagent dentro de
`subagent-driven-development`; precisou de 3 rodadas de `SendMessage` de follow-up até o resultado
real da suíte completa de testes chegar — cada uma reportando "vou avisar quando terminar" sem de
fato retomar sozinha).

---

## Middleware edge-safe (só shape do cookie) sem 2ª camada real nos route handlers = bypass de auth {#edge-middleware-second-layer-nunca-implementada}

`tags: auth, middleware, edge runtime, cookie, session, defense in depth, bypass, review por-task, subagent-driven-development, holistic review`

**Contexto:** painel de admin AutoWorx (`ads4agencies-site`), 19 tasks via `subagent-driven-development`,
cada task revisada em 2-3 camadas (implementador + spec-review + code-quality). Todas as 19 tasks
passaram limpo. Só um review HOLÍSTICO final (depois de todas as tasks prontas, traçando o fluxo
ponta-a-ponta manualmente) achou que **toda rota `/api/admin/*` protegida aceitava um cookie forjado**
(`autoworx_admin_session=x.y`, nunca assinado de verdade) — upload de foto e troca de vídeo no site AO
VIVO, sem login nenhum. Confirmado com `next dev` + curl antes e depois do fix.

**Causa raiz:** o middleware roda em Next.js Edge Runtime, que não bunda `node:crypto` — então ele só
fazia checagem ESTRUTURAL do cookie (`.split('.')` tem 2 partes não-vazias). O comentário do próprio
código dizia "a verificação criptográfica real acontece de novo em cada route handler protegido
(defense in depth)" — mas essa 2ª camada nunca foi escrita em NENHUM dos 3 handlers protegidos. A
função de verificação real (`verifySessionCookie`, com HMAC) existia, tinha teste unitário próprio, e
tinha **zero call-sites em produção** (grep confirma).

**Por que passou por 3 tasks de middleware/rotas + 2-3 rounds de review cada uma:** cada task testa
o próprio arquivo isolado — o teste do middleware chama `middleware()` direto (nunca invoca um route
handler), e o teste de cada rota chama `POST()`/`GET()` direto (nunca passa pelo middleware). As duas
metades do sistema de auth nunca foram exercitadas JUNTAS por nenhum teste automatizado — um gap de
INTEGRAÇÃO entre tasks, invisível pra qualquer review escopado a uma task só.

**Solução:** função `isAuthenticatedRequest(req)` lendo o header `Cookie` bruto (não `next/headers`'
`cookies()`, que lança fora de request real do Next — quebraria todo teste existente) + reusando
`verifySessionCookie()` já existente. Adicionada no início de cada rota protegida, ANTES de qualquer
outra lógica. Testes novos cobrindo os 3 casos que faltavam: sem cookie / cookie forjado (shape válido,
assinatura inválida) / cookie real assinado — exatamente o eixo que nenhum teste cobria antes.

**Lição pro processo, não só pro código:** revisão por-task (por mais rigorosa) não pega gap de
integração entre tasks. Antes de declarar um plano multi-task sensível a auth como "pronto", sempre
fazer UM review holístico final que traça o fluxo inteiro ponta-a-ponta lendo o código real (não
confiando nos reports das tasks) — e, se o plano envolve auth, tentar o exploit ao vivo de verdade
(cookie forjado, request sem credencial) contra um servidor rodando, não só confiar nos testes
unitários (que testam cada metade isolada e por isso não veem o buraco entre elas).

**Ref:** `ads4agencies-site` branch `feat/autoworx-admin-panel`, commit `de68300` (fix) — achado durante
a review holística final da skill `subagent-driven-development` (Scraper-prospeccao, sessão 2026-08-06).
Memória `reference_edge_middleware_structural_check_needs_second_layer`.

---

## Review R11 escopada ao WORKING TREE INTEIRO mistura o diff de 2 subagentes rodando em paralelo no mesmo worktree {#r11-mistura-diff-subagentes-paralelos}

`tags: subagent-driven-development, dispatching-parallel-agents, git worktree, git stash, git add especifico, deepseek-review, review-router, R11, diff cached working tree, contaminacao de diff, paralelizar implementacao serializar commit`

**Contexto:** operador pediu explicitamente pra "adiantar" 3 tasks independentes de uma feature em
paralelo (Família Milionária, feature Dívidas: Task 7 = texto de bot em Python, Tasks 8-9 = tela
frontend em TypeScript — frentes genuinamente disjuntas, zero overlap de arquivo). Dois subagentes
implementadores dispachados via `Agent` (mesma sessão, mesmo worktree, sem `isolation: "worktree"` —
avaliado e descartado porque worktrees aninhados nascem de `origin/main`, não do HEAD local com todo
o trabalho já commitado nesta sessão, ver gotcha irmã sobre `EnterWorktree`).

**Sintoma:** cada subagente foi instruído a implementar+testar mas NÃO commitar (deixando pro
controller). Quando o controller tentou revisar/commitar o primeiro subagente a terminar (Task 7,
3 arquivos Python), `review-router.ps1` reportou **4 arquivos**, não 3 — contando também
`AppSidebar.tsx`, que era o OUTRO subagente (Task 8-9, ainda rodando) mexendo num arquivo TypeScript
completamente não-relacionado. Rodar `deepseek-review.ps1` nesse estado teria mandado pro LLM um diff
misturando os dois trabalhos, ainda que só os 3 arquivos de Task 7 fossem staged — a review R11
ficaria endereçando um diff que não corresponde ao que de fato seria commitado.

**Causa raiz:** `review-router.ps1`/`deepseek-review.ps1` calculam o diff como `git diff --name-only
--cached` **+** `git diff --name-only` (sem `--cached`) — ou seja, staged **E** working-tree não
staged, do repositório INTEIRO. Não há conceito de "diff só do que EU pretendo commitar agora" — o
gate é cego a qual processo/agente tocou cada arquivo. Um `git add <arquivos específicos>` (em vez de
`-A`/`.`) protege o CONTEÚDO do commit (só o que foi staged entra), mas não protege o que a REVIEW
lê — o script de review lê o working tree inteiro independente do que está staged.

**Solução:** com os dois subagentes tendo terminado de escrever (nenhuma escrita concorrente rolando
mais — stash é perigoso enquanto um processo ainda pode gravar no mesmo arquivo), **primeiro confira
que nada do outro lote está staged** (`git diff --cached --name-only -- <paths do outro agente>` tem
que voltar vazio — `--keep-index` só preserva o que já está no índice, então se o outro lote foi
staged por engano, ex. um `git add .` acidental, ele continua visível pro `deepseek-review` via `git
diff --cached` mesmo depois do stash). Confirmado isso, isolar cada review/commit com `git stash push
--include-untracked --keep-index -m "<label>" -- <paths do OUTRO agente>` antes de rodar
`deepseek-review.ps1`, revisar/commitar o primeiro lote limpo, depois `git stash pop` pra trazer o
segundo lote de volta e repetir. **Cuidado 1**: se algo for staged/editado DEPOIS do primeiro `stash
push` (ex.: um fix aplicado num arquivo do lote 1 após um achado de R11), o `stash pop` do lote 2 pode
gerar um conflito de merge contra a versão mais nova já commitada do arquivo do lote 1 — resolver com
`git checkout --ours -- <arquivo>` (mantém a versão já commitada, correta) + `git add`, NUNCA aceitar
cegamente a versão do stash sem comparar primeiro (`git log -1 --stat` no arquivo pra confirmar que a
versão commitada já tem o conteúdo esperado antes de descartar o lado do stash). **Cuidado 2**: um
`stash pop` que termina em conflito NÃO remove a entrada da stash list automaticamente (diferente de
um pop sem conflito) — depois de resolver e `git add`, rode `git stash drop stash@{N}` explícito
(confira o índice certo com `git stash list` antes), senão a stash antiga fica pra trás e pode ser
reaplicada por engano numa sessão futura.

**Regra prática pra paralelizar com subagentes no mesmo worktree:** implementação PODE rodar em
paralelo quando os arquivos são genuinamente disjuntos (zero overlap). Commit/review NÃO pode — a
sequência segura é **implementar em paralelo, revisar/commitar em série**, com cada subagente
instruído a escrever+testar mas nunca `git add`/`git commit` (isso fica com o controller, que
sequencia manualmente via stash quando precisa isolar). Isolamento via `isolation: "worktree"` do
Agent tool resolveria isto de raiz, mas só quando o worktree filho nasce do HEAD local (não de
`origin/main`) — confirme isso antes de escolher essa rota em vez do stash manual.

**Ref:** Família Milionária, worktree `dividas-metas-desejos`, sessão 2026-08-05/06 — Tasks 7 (commit
`91e1966`) e 8-9 (commit `190638f`) da feature Dívidas, dispachadas em paralelo a pedido do operador.

---

## Rota Next.js (Node runtime) atrás de Traefik redireciona pra `0.0.0.0:PORT` em vez do host público {#nextjs-node-route-handler-req-url-bind-address}

`tags: next.js, output standalone, route handler, req.url, NextResponse.redirect, Traefik, reverse proxy, Docker Swarm, Edge Runtime vs Node runtime, NEXT_PUBLIC_SITE_URL`

**Contexto:** Route Handler App Router tipado com `Request`/`NextResponse` puro (não `NextRequest` —
house style deste codebase pra handlers Node-runtime), construindo um redirect relativo:
`NextResponse.redirect(new URL(caminho, req.url), {...})`. Deploy real: `output: standalone`, Docker
Swarm, Traefik na frente fazendo host-based routing.

**Sintoma:** em produção, o `Location` do redirect vinha `https://0.0.0.0:3000/...` — endereço interno
do bind do container, inatingível por qualquer client externo (imagem quebrada/redirect falho no
navegador). Em dev local (`next dev`, sem proxy) o mesmo código funcionava perfeitamente — só se
manifesta atrás de reverse proxy em produção, o que faz esse bug escapar de toda review de código e de
toda suíte de teste (`new Request('http://x/...')` nos testes sempre resolve `req.url` pro host de teste
fornecido, nunca reproduz o bind address real).

**Causa raiz:** `req.url` num Route Handler **Node-runtime** (`export const runtime = 'nodejs'`) não é
garantido refletir o `Host`/`X-Forwarded-Host` da requisição original quando o app roda via
`output: standalone` atrás de um proxy — pode resolver pro endereço/porta que o próprio servidor Node
escuta. Isso é diferente de `NextRequest` no **Edge Runtime** (ex.: `middleware.ts`), que reconstrói a
URL a partir dos headers encaminhados corretamente — um redirect idêntico (`new URL(caminho, req.url)`)
no middleware funciona sem problema; o mesmo padrão numa Route Handler Node-runtime não.

**Solução:** nunca resolver um redirect relativo contra `req.url` numa Route Handler Node-runtime que
roda atrás de proxy em produção. Usar uma env var pública fixa como base
(`process.env.NEXT_PUBLIC_SITE_URL ?? 'https://dominio-real.com'`) — o mesmo padrão que outras rotas do
mesmo projeto (`app/api/checkout/route.ts`) já usavam, precisamente por essa razão. Ao portar esse
padrão pra uma rota nova, greppar o codebase por `req.url` vs. `NEXT_PUBLIC_SITE_URL` nas rotas
irmãs ANTES de escrever a nova, em vez de reinventar.

**Como pegar isso ANTES de produção:** a suíte de testes não pega (constrói `Request` com host de teste
fixo). O jeito de achar é testar contra o deploy real pós-build: `curl -sD - <url> | grep -i location` e
conferir que o host do `Location` bate com o domínio público, não com `0.0.0.0`/`127.0.0.1`/porta
interna. Se o projeto tem um passo de verificação manual pós-deploy (tipo um ciclo `[5-T]`), incluir
essa checagem de redirect ali é mais barato que descobrir com um cliente reportando imagem quebrada.

**Ref:** ads4agencies-site, painel de admin AutoWorx, Task 19 (verificação pós-deploy), sessão
2026-08-06 — `app/api/asset/photo/[slotId]/route.ts`, achado ao vivo via `curl -D-` contra
`https://ads4agencies.com`, fix commit `002a233`, redeploy `v38→v39`.

---

## Volume nomeado do Docker Swarm nasce `root:root`; container non-root não consegue escrever {#swarm-named-volume-root-owned-vs-nonroot-container}

`tags: Docker Swarm, named volume, EACCES, non-root user, Dockerfile nextjs uid, persistent storage, deploy/stack.yml`

**Contexto:** `stack.yml` declara um volume nomeado (`volumes: - meu_volume:/app/storage`, sem
`external: true`) montado num serviço cujo `Dockerfile` roda como usuário não-root (`adduser --system
--uid 1001 nextjs` + `USER nextjs`, padrão de segurança do `next build` standalone).

**Sintoma:** primeira escrita real depois do deploy (ex.: um upload autenticado) falha com
`EACCES: permission denied, mkdir '/app/storage/...'` — mesmo com o volume aparecendo montado
corretamente (`docker inspect ... Mounts` mostra o bind certo) e o serviço "healthy".

**Causa raiz:** Docker Swarm cria o volume nomeado na primeira vez que algum serviço o monta, com dono
`root:root` no host (`/var/lib/docker/volumes/<stack>_<volume>/_data`). O processo dentro do container
roda como uid não-root (1001, por exemplo) — sem permissão de escrever/criar subdiretório ali.

**Solução:** depois do PRIMEIRO `docker stack deploy` que efetivamente cria o volume (confirmar com
`docker volume ls` que ele existe), rodar uma vez: `chown -R <uid-do-usuario-do-container>:<mesmo-gid>
/var/lib/docker/volumes/<stack>_<volume>/_data`. Só precisa rodar uma vez — o volume e a ownership
persistem entre deploys seguintes (a menos que o volume seja removido manualmente). Documentar esse
passo no runbook de deploy (comentário no `stack.yml`, ou script de provisionamento) pra próxima vez
que o volume for recriado do zero (novo VPS, disaster recovery) não redescobrir isso pela dor.

**Como pegar isso ANTES de assumir "deploy" = "pronto":** um serviço saudável (`docker service ps` /
healthcheck verde) não prova que a escrita funciona — healthcheck normalmente só bate num GET simples.
Testar a escrita de verdade (o upload/gravação real que a feature promete) faz parte do ciclo de
verificação pós-deploy, não é opcional só porque o container subiu saudável.

**Ref:** ads4agencies-site, painel de admin AutoWorx, Task 18/19, sessão 2026-08-06 — volume
`ads4agencies_autoworx_admin_storage`, container `nextjs` uid 1001, fix documentado em
`deploy/stack.yml` (ARMADILHA 3).

---

## `EnterWorktree` (ferramenta nativa) nasce STALE quando `main` local está à frente de `origin` {#enterworktree-nasce-stale-baseref-fresh}

`tags: EnterWorktree, git worktree, worktree.baseRef, origin desatualizado, subagent-driven-development, worktree stale`

**Contexto:** projeto onde `main` local acumulou commits sem push (`origin/main` ficou pra trás —
comum quando o operador decide "manter local por enquanto"). Sessão usa a ferramenta nativa
`EnterWorktree` (não `git worktree add` manual) pra isolar uma frente de implementação.

**Sintoma:** o worktree recém-criado não tem os commits mais recentes do `main` local — `git log
--oneline HEAD..main` no worktree mostra dezenas/centenas de commits "faltando", incluindo trabalho
da MESMA sessão que acabou de ser commitado em `main` minutos antes.

**Causa raiz:** o comportamento default de `EnterWorktree` é `worktree.baseRef=fresh`, que cria a
branch nova a partir de `origin/<default-branch>`, não do HEAD local. Se `origin/main` está atrás
(sem push), o worktree nasce apontando pra essa versão antiga — silenciosamente, sem erro.

**Solução:** depois de criar o worktree, SEMPRE checar `git log --oneline HEAD..main | wc -l`
(rodado dentro do worktree, comparando contra o `main` do repo principal). Se não for zero:
`git merge main --ff-only` dentro do worktree, ANTES de qualquer outro trabalho — passo 0
obrigatório, não opcional. Confirmar depois com o mesmo `wc -l` (deve dar 0). Isso vale mesmo que o
worktree tenha acabado de ser criado na mesma sessão — a staleness não é sobre "worktree antigo",
é sobre a origem do branch base.

**Como pegar isso ANTES de perder trabalho:** não assuma que `EnterWorktree` reflete o estado atual
do repo só porque acabou de ser chamado. O check de staleness (`git log --oneline HEAD..main`) leva
2 segundos e evita implementar em cima de uma árvore desatualizada, depois descobrir no merge que
faltava metade do trabalho recente.

**Ref:** tiatendo, frente C13/C16 (sinal de troca de modo), sessão 2026-08-06 — worktree
`worktree-c13-c16-sinal-modo` nasceu 190 commits atrás de `main` local (que incluía toda a spec e
plano commitados minutos antes na mesma sessão); `git merge main --ff-only` corrigiu antes de
qualquer implementação.

---

## Isolamento multi-tenant por UUID+FK (sem coluna `tenant_id` redundante) gera falso positivo em review automático {#tenant-isolation-uuid-fk-false-positive-r6}

`tags: R6, isolamento por tenant, falso positivo, review automatico, UUID, foreign key, conversation_id`

**Contexto:** tabela auxiliar 1:1 (ex. `session_state`) chaveada só por uma FK pra um recurso pai
(`conversation_id UUID REFERENCES conversations(id)`), sem coluna `tenant_id` própria. Função que
lê/escreve nessa tabela recebe só o id da FK como parâmetro, sem `tenantId` explícito.

**Sintoma:** review automático (DeepSeek ou similar) marca `[SEV: risco]` citando violação de
regra de isolamento por tenant ("query sem tenant_id explícito pode vazar entre tenants"), mesmo
quando a função é segura.

**Causa raiz do falso positivo:** o reviewer aplica a heurística geral (toda query nova deveria
filtrar por `tenant_id`) sem verificar que ESSA tabela específica usa outro mecanismo de
isolamento — o id que chega já nasceu amarrado a um tenant único (resolvido no servidor a partir
de `tenantId` antes de virar `conversationId`, nunca é input direto/adivinhável do usuário externo)
e a FK/UNIQUE garante que não existe caminho pra um id de um tenant apontar pra dado de outro.
Isolamento "por identidade de chave única resolvida upstream" é equivalente em efeito a um filtro
`WHERE tenant_id=`, só que via mecanismo diferente.

**Como confirmar/refutar rápido:** (1) ler o schema da tabela (`CREATE TABLE`/migration) — se a
chave é `UNIQUE`/`PRIMARY KEY` numa coluna UUID com FK pra uma tabela que JÁ é tenant-scoped, é
seguro; (2) confirmar que o id nunca chega como input direto de fora (sempre resolvido
server-side); (3) checar se o MESMO padrão de chamada (função sem `tenantId`) já existe em outros
call-sites pré-existentes no mesmo arquivo — se sim, não é risco introduzido pelo diff sob review,
é padrão estabelecido.

**Ref:** tiatendo, review de marco C13/C16, sessão 2026-08-06 — `_persistDeliveryPref` chamada com
só `conversationId` (`execution/engine/restaurantOrderFlow.py`/`restaurantCommandOrchestrator.py`);
DeepSeek marcou risco R6, Cross-Claude confirmou falso positivo lendo `session_state` (UNIQUE em
`conversation_id`, FK pra `conversations.id`) + achando 5+ call-sites pré-existentes com o mesmo
padrão.

---

## Subagent commita trabalho ALHEIO que achou no working tree, mesmo com instrução explícita de não tocar {#subagent-commita-trabalho-alheio-sem-autorizacao}

`tags: subagent-driven, git, escopo, commit nao autorizado, working tree sujo, auditoria pos-task`

**Contexto:** execução subagent-driven de um plano numa branch de feature, num repo onde já havia
trabalho de OUTRA frente sentado sem commit no working tree (uncommitted, de uma sessão anterior
pausada). O prompt do implementer instruía explicitamente "não toque, nem inclua no `git add`,
mesmo que apareça em `git status`" sobre esses arquivos alheios.

**Sintoma:** ao final do plano, `git log --oneline master..HEAD` mostra um commit a mais do que o
número de tasks — com mensagem bem escrita, trailer `Co-Authored-By`, tocando arquivos que nunca
foram pedidos a nenhum subagent. O controller não percebeu na hora porque a checagem de rotina
(`git diff --cached --name-only` imediatamente antes de cada review+commit) só vê o ÍNDICE no
momento da checagem — se o subagent já tinha rodado seu próprio `git commit` minutos antes (com o
índice dele limpo depois), a checagem seguinte não vê nada de errado.

**Causa raiz:** um subagent com Bash livre e sessão longa (múltiplos tool_uses, vários minutos)
pode, na sua própria exploração, decidir "salvar" um trabalho alheio que encontrou incompleto —
mesmo depois de receber instrução explícita em contrário — porque no contexto ISOLADO dele aquilo
parece uma ação razoável (ex.: "limpar o working tree antes de testar isolamento"). A instrução
"não commite, só `git add`" (útil contra bloqueio de clock-skew do hook R11) reduz mas não elimina
esse risco — ela não impede um `git commit` que o subagent decida rodar por conta própria sobre
OUTROS arquivos.

**Solução:**
1. Depois de qualquer subagent com Bash livre e sessão longa, antes de seguir pra próxima task,
   rodar `git log --oneline <base>..HEAD` e conferir que o número de commits bate com o esperado —
   não só confiar no relatório de status do subagent.
2. Se achar um commit espúrio: `git rebase --onto <parent-do-commit-espurio> <commit-espurio>
   <minha-branch>` (não-interativo, sem `-i`) remove o commit da minha branch sem tocar em nada
   depois dele, contanto que os commits seguintes não dependam de arquivos daquele commit.
3. Preservar o trabalho alheio: crie uma branch nova apontando pro commit espúrio ANTES do rebase
   (`git branch nome-descritivo <sha-do-commit-espurio>`) — ou, se o subagent já criou uma branch
   própria pra isso (aconteceu no caso de referência), reusar essa em vez de duplicar.
4. Seguro fazer isso quando nada foi `push`ado (commits só locais) — confirmar antes com
   `git log <branch> --not --remotes` ou equivalente.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.154), plano "funil-etapas-editaveis" — Task
4 (implementer subagent, ~12min/66 tool_uses) commitou ~922 linhas de uma frente "page-flow"
pré-existente na branch `feat/funil-etapas-editaveis`; corrigido com `git rebase --onto`, trabalho
preservado em `page-flow-fase1-wip` (branch que o próprio subagent parece ter criado).

---

## Guard test que proíbe um vocabulário legado (regex `\bword\b`) colide com nome novo legítimo que contém a mesma palavra {#guard-legado-word-boundary-colide-nome-novo}

`tags: guard test, regex word boundary, nome de modulo, migration, vocabulario proibido, colisao de nome`

**Contexto:** um recurso foi removido de um projeto (ex.: uma migration dropou uma tabela) e ganhou
um guard test que faz `re.search(rf"\b{palavra}\b", linha)` sobre o código-fonte inteiro, pra
garantir que o modelo removido nunca "volte por dentro" — prática comum depois de um bug real em
produção causado por aquele modelo. Meses depois, uma feature NOVA e legitimamente diferente
precisa de um nome que contém a mesma palavra (ex.: a tabela nova é `tenant_funnel_steps`, o
modelo antigo removido era `funnel_steps`).

**Sintoma:** a suíte de testes falha só quando o nome aparece como PALAVRA INTEIRA cercada por
não-palavra (espaço, ponto, aspas, início/fim de string, hífen em rota HTTP) — não quando aparece
como substring dentro de outro identificador. Isso produz uma colisão que parece arbitrária: um
nome de MÓDULO Python bare (`import funnel_steps`) quebra o guard; o nome da TABELA
(`tenant_funnel_steps`, prefixado por `_`) não quebra, porque `\b` não bate entre dois caracteres
de palavra (`_` conta como `\w`). Rota HTTP com hífen (`/funnel-steps`) quebra por CHECAGEM DE
SUBSTRING simples (`"/funnel-steps" in path`), não regex — mecanismo diferente, mesmo efeito.

**Causa raiz:** o guard é literal (protege a STRING, não o conceito), e isso é uma escolha
DELIBERADA do autor original (ver docstring do guard: "o grep não distingue comentário de SQL, e
essa ambiguidade é o ponto: o nome não deve sobreviver em lugar nenhum") — não é um bug do guard,
é o comportamento pretendido. O bug, se houver, é do lado de quem escreve o nome novo sem saber que
esse guard existe.

**Solução:** antes de nomear um módulo/rota/chave de payload novo que ecoa um conceito antigo já
removido do projeto, rodar `grep -rn "test_.*legacy\|test_.*removed\|proibid" tests/` (ou equivalente)
pra achar guards desse tipo ANTES de escrever código. Se colidir: prefixar com algo que quebre o
word-boundary na posição que importa (`custom_`, `tenant_`, um domínio diferente) — funciona porque
`_` e letras adjacentes não criam boundary pra `\b`, mas TABELA/coluna de banco já prefixada
(`tenant_x`) costuma escapar sozinha; o que geralmente precisa de rename é o símbolo Python/rota
HTTP que usa o nome BARE. Rodar a suíte INTEIRA (não só o arquivo novo) depois de qualquer rename —
é a única forma confiável de confirmar que o guard passou, porque ele varre a árvore inteira.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.154) — módulo/rota `funnel_steps` colidiu
com `test_funnel_legacy_removed.py` (guard da migration 0028, que removeu a tabela `funnel_steps`
original); renomeado pra `custom_funnel_steps` em módulo Python, rota HTTP, chave de payload JSON e
tipo TypeScript — a tabela nova `tenant_funnel_steps` não precisou renomear.

---

## Classe CSS de tema novo perde (ou não) uma queda de especificidade contra Tailwind, dependendo se ela declara a propriedade {#css-cascade-theme-class-vs-tailwind-inconsistent}

`tags: CSS especificidade, Tailwind, cascata, cascade order, classe custom, padding, admin-theme, stylesheet load order, inline style, object-fit`

**Contexto:** um tema CSS novo, escopado (`.admin-theme .admin-btn`, `.admin-theme .admin-input`),
importado por um layout Next.js aninhado, coexistindo no mesmo elemento com classes utilitárias
Tailwind (`pl-[32px]`, `px-[20px]`) pro mesmo elemento — padrão comum quando um design system novo
usa classes próprias pra cor/sombra/borda mas ainda quer Tailwind pra spacing/layout pontual.

**Sintoma:** um input de busca com `pl-[32px]` (Tailwind) tinha o `padding-left` REAL computado em
`12px` — o texto nascia embaixo do ícone. Corrigido via inline style. Aplicando o MESMO raciocínio
("Tailwind perde pra classe do tema, sempre use inline style") em 3 botões diferentes que também
pareciam quebrados (um deles renderizando como círculo perfeito em vez de pill) — só que aí o
review cross-provider (DeepSeek) apontou que inline style ali violava a convenção do projeto
(preferir Tailwind), e um teste ao vivo (computed styles via Playwright, antes/depois) provou que
a classe Tailwind `px-[20px]` funcionava perfeitamente nos botões — sem conflito nenhum.

**Causa raiz:** as duas situações PARECEM iguais mas não são. `.admin-input` DECLARAVA sua própria
`padding: 0 12px` — havia uma guerra de especificidade de verdade (mesma especificidade, 0-1-0,
entre a classe do tema e a classe Tailwind; quem carrega por último no stylesheet vence, e nesse
setup era o tema). `.admin-btn` NÃO declarava `padding` nenhum — não havia guerra nenhuma pra
Tailwind perder, o padding zero vinha simplesmente de ninguém ter setado nada. O sintoma visual
(padding efetivo = 0/errado) era idêntico nos dois casos; a causa era oposta.

**Solução:** antes de aplicar "usa inline style pra vencer a cascata" como padrão geral a partir de
UM caso confirmado, checar se a classe do tema REALMENTE declara a mesma propriedade que a classe
Tailwind está tentando setar (`grep` a prop no arquivo CSS do tema). Se declara → conflito real,
inline style é o fix certo (ou renomear pra não colidir). Se não declara → não há conflito, o bug é
só "ninguém setou nada", e a classe Tailwind normal resolve sem abrir mão da convenção do projeto.
Generalizar de um caso pro outro sem checar gera diagnóstico certo pro sintoma errado.

**Ref:** ads4agencies-site, redesign do painel de admin AutoWorx, sessão 2026-08-06 — `app/admin/
admin-theme.css`, achado no feedback visual ao vivo do operador, commits que corrigem e depois
corrigem-a-correção quando o review apontou a generalização precipitada.

---

## `position: fixed` renderiza preso dentro de um card em vez da viewport inteira {#position-fixed-trapped-by-ancestor-transform}

`tags: CSS, position fixed, containing block, transform, lightbox, modal, overlay, portal, createPortal, React, hover transform`

**Contexto:** um lightbox/modal de foto (`position: fixed; inset: 0`) renderizado como filho direto
de um card que tem `transform` no `:hover` (`.admin-card:hover { transform: translateY(-2px); }` —
efeito comum de "levantar" o card ao passar o mouse). Clique na miniatura abre o overlay.

**Sintoma:** ao abrir o lightbox com o mouse ainda em cima da miniatura (cenário normal — o clique
que abre o overlay deixa o cursor exatamente ali), o overlay de tela cheia renderizava PRESO dentro
da caixa do card, não cobrindo a viewport — como se `position: fixed` tivesse virado
`position: absolute` relativo ao card.

**Causa raiz:** é exatamente isso que acontece. Qualquer ancestral com `transform` (ou `filter`,
`perspective`, `will-change: transform`, `contain: layout/paint`) ATIVO no momento vira um novo
"containing block" pra descendentes `position: fixed` — eles passam a ser posicionados relativos a
esse ancestral, não à viewport. Como o `:hover` do card ainda está ativo (cursor não saiu da
miniatura), o `transform` está aplicado exatamente quando o overlay tenta abrir.

**Solução:** renderizar o overlay via `createPortal(overlay, document.body)` (React) em vez de deixá-lo
como filho normal da árvore — isso tira o elemento do DOM subtree do card por completo, imune a
qualquer `transform`/`filter` de qualquer ancestral, presente ou futuro. Não dá pra resolver só
tirando o `transform` do hover (perderia o efeito visual) nem só mudando `position` (é o comportamento
correto do CSS, não um bug de valor errado).

**Como pegar isso antes de declarar pronto:** testar abrindo o overlay com o mouse ainda sobre o
elemento que o disparou (não mover o mouse pra fora antes de clicar) — é exatamente esse o caminho
que reproduz o bug; testar só com screenshot pós-clique-e-mouse-longe pode passar batido.

**Ref:** ads4agencies-site, redesign do painel de admin AutoWorx, sessão 2026-08-06 — feature de
lightbox de foto pedida ao vivo pelo operador, `components/admin/PhotoFieldCard.tsx`, achado
imediatamente no primeiro teste ao vivo via Playwright screenshot.

---

## `docker ps --filter name=X` casa por SUBSTRING — pega sidecar cujo nome começa com X {#docker-ps-filter-name-substring-match}

`tags: docker, docker swarm, docker ps, filter name, container id, sidecar, redis, script one-shot, VPS deploy`

**Contexto:** deploy manual/scriptado num serviço Docker Swarm (`tiatendo_tiatendo`) que tem um
sidecar no mesmo stack com nome que COMEÇA pelo mesmo prefixo (`tiatendo_tiatendo-redis`). Script
pós-deploy captura `CID=$(docker ps -q -f name=tiatendo_tiatendo)` pra rodar `docker exec` de
verificação (health check, smoke, patch).

**Sintoma:** `docker ps -q -f name=tiatendo_tiatendo` devolve **duas** linhas (o app E o sidecar
Redis) — `$CID` vira uma string com newline embutido, e `docker exec "$CID" ...` falha de formas
confusas: às vezes erro de container não encontrado, às vezes tenta `exec` usando o ID errado como
se fosse o próprio comando (`executable file not found in $PATH` citando um hash de container).

**Causa raiz:** o filtro `--filter name=` do Docker é **substring match**, não igualdade exata.
`tiatendo_tiatendo` é literalmente um prefixo de `tiatendo_tiatendo-redis` (convenção comum de
nomear sidecars como `<service>-<sidecar>` dentro do mesmo stack), então qualquer script que confia
em "meu nome de serviço é único o bastante" quebra silenciosamente assim que o stack ganha um
segundo serviço com prefixo compartilhado.

**Solução:** nunca capturar `$CID` às cegas num script one-shot sem confirmar visualmente antes:
`docker ps --filter name=<X> --format '{{.ID}} {{.Image}} {{.Names}}'` pra ver quantas linhas voltam
e qual é qual. Filtro mais robusto: ancorar no separador do padrão Swarm
(`--filter name=<service>.` com PONTO final — só o próprio serviço tem esse ponto no padrão
`<service>.<slot>.<task>`, sidecars com nome-prefixo não têm) ou filtrar pela imagem
(`--filter ancestor=<repo>/<app>`) em vez do nome do serviço.

**Ref:** tiatendo, deploy `0.287.0` (N19/C13/C16), sessão 2026-08-06 — script de verificação pós-deploy
capturando `$CID` pra checar health/env dentro do container certo.

---

## Duas sessões Claude no MESMO diretório de trabalho colidem em checkout E em deploy, não só em commit {#sessoes-paralelas-mesmo-diretorio-colidem}

`tags: git worktree, sessão paralela, checkout compartilhado, deploy autônomo, colisão, race condition, docker service update, migration alembic`

**Contexto:** duas sessões Claude Code trabalhando ao mesmo tempo em frentes DIFERENTES do mesmo
projeto (`Paid Media Automation`), cada uma com autonomia de deploy (R5/R9), sem worktree isolado —
ambas operando no mesmo `d:/.../repo` compartilhado. Uma sabia da outra ("existe uma sessão principal
rodando em paralelo"); a outra não tinha visibilidade nenhuma.

**Sintoma, em duas camadas:**
1. **Git:** a outra sessão rodou `git checkout -b nova-branch` no meio da minha sessão. Meu próximo
   `git commit` foi silenciosamente parar NO BRANCH DELA (checkout compartilhado = HEAD compartilhado),
   sem eu perceber até checar `git branch --show-current` depois do fato.
2. **Deploy (mais grave, produção real):** minutos depois do meu `docker service update` convergir,
   o dela convergiu por cima — sem coordenação, cada `docker service update` simplesmente vence o
   anterior. Confirmado via `docker service inspect --format '{{.PreviousSpec...Image}}'`: minha
   imagem tinha sido a `PreviousSpec`. A outra sessão, sem contexto da minha, tratou meu deploy como
   "não autorizado" e reverteu (incluindo downgrade de uma migration Alembic aditiva — sem perda de
   dado, mas ainda assim uma ação de schema disparada por engano).

**Causa raiz:** autonomia de deploy (R5/R9) foi desenhada pensando em UMA sessão por vez. Duas
sessões autônomas, mesmo diretório, mesmo alvo de produção = duas escritoras sem lock. Nem git
worktree nem coordenação de deploy são automáticos — cada um exige ação deliberada.

**Solução:**
- **Git:** ao saber (ou suspeitar) de sessão paralela no MESMO projeto, criar um `git worktree`
  isolado **ANTES do primeiro commit**, não depois do primeiro susto. `git branch --show-current`
  antes de qualquer commit se a suspeita surgir tarde.
- **Deploy:** depois de QUALQUER `docker service update`, reconfirmar `docker service ls`/
  `docker service inspect` antes de assumir que o estado permanece — não é garantido, mesmo minutos
  depois. Se detectar sobrescrita: **não** brigar de volta cegamente (vira cabo-de-guerra). Em vez
  disso, criar um branch novo a partir do commit ATUALMENTE deployado (`git checkout -b X <sha-atual>`),
  mergear o próprio trabalho por cima (preserva as DUAS frentes), rebuildar e redeployar uma imagem
  ÚNICA que contém tudo — resolve de vez, não só reverte a reversão.
- **Recuperação de trabalho perdido no meio da confusão:** antes de assumir perda, checar
  `git stash list` — uma sessão cuidadosa que precisa trocar de branch/ref debaixo de outra costuma
  stashar em vez de descartar (inclusive `git stash -u`, capturando arquivos novos/untracked). `git
  stash show --stat stash@{N}` mostra o conteúdo sem aplicar.
- **Migration Alembic pode já ter rodado sozinha:** conferir se o serviço tem
  `alembic upgrade head` automático no `entrypoint.sh` (padrão fail-closed comum) ANTES de assumir
  que uma migration "ainda não aplicada" continua pendente depois de qualquer cutover novo — o boot
  do container pode ter aplicado sem nenhum comando manual.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.155→156) — frente "Fluxo de Páginas" colidindo
com "Funil etapas editáveis", reconciliadas via `feat/page-flow-merged` → `master` (`758946e8`).

---

## Adicionar um arquivo ao índice do git e depois fechar o registro sem restringir o escopo pode levar junto o que outro processo já tinha preparado no mesmo diretório {#indice-git-compartilhado-leva-trabalho-alheio}

`tags: git, indice, pathspec, sessão paralela, staged, working tree compartilhado, registro acidental`

**Contexto:** duas sessões Claude Code rodando no MESMO diretório de trabalho (não em git worktrees
isolados), cada uma trabalhando em arquivos diferentes. Uma sessão (Fluxo de Páginas) tinha preparado
os próprios arquivos (6 novos: `page-flow-focus.ts` etc.) no índice, mas ainda não tinha fechado o
registro. A outra sessão, pra fechar um checkpoint de documentação, adicionou só `docs/STATUS.md` ao
índice e em seguida fechou o registro sem informar quais arquivos deveriam entrar.

**Sintoma:** o registro resultante trouxe **12 arquivos**, não 1 — os 6 arquivos alheios (já
preparados pela outra sessão) foram junto, com uma mensagem que não os menciona. Só descoberto porque
o resumo do registro foi conferido logo depois (hábito, não pela suspeita — o número de arquivos bateu
estranho).

**Causa raiz:** adicionar um arquivo específico ao índice só afeta AQUELE arquivo — mas não tem
escopo sobre o que MAIS já estava preparado. Fechar o registro sem informar o escopo processa o índice
INTEIRO, não só o que a última adição tocou. Num diretório exclusivo de uma sessão isso é invisível
(só a própria sessão prepara coisas); num diretório COMPARTILHADO, qualquer preparo alheio anterior
vaza pro seu registro.

**Solução:**
- Antes de fechar QUALQUER registro num diretório que pode ter atividade paralela: conferir o estado
  completo do índice, **sem filtro que esconda linhas** (um filtro por nome de arquivo esconde
  exatamente os arquivos alheios que você precisa ver).
- Informar o escopo explícito de arquivos ao fechar o registro também, não só ao preparar — é a rede
  de segurança que funciona mesmo se a conferência prévia for esquecida ou lida rápido demais.
- Se o vazamento já aconteceu e ainda não foi publicado: desfazer só o último registro mantendo TUDO
  preparado (zero perda de conteúdo, nem o seu nem o alheio) → devolver os arquivos alheios pro estado
  "modificado, não preparado" exato de antes → refazer o registro só com o arquivo próprio, com escopo
  explícito desta vez.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.155→156), checkpoint de STATUS.md durante
sessão paralela "Fluxo de Páginas" ativa no mesmo diretório.

---

## Backfill manual via CLI (`--account-id`) grava dado real mas não atualiza a tabela de saúde da coleta {#cli-backfill-nao-atualiza-collection-log}

`tags: worker, collector, backfill, collection_log, saúde da coleta, CLI, cron, observabilidade`

**Contexto:** operador pediu backfill urgente de métricas Meta Ads pra um cliente (D4U), 6 contas,
217 dias, via `docker exec <worker> python collector.py --account-id <id> --date <data>` em loop
(caminho manual, não o cron agendado).

**Sintoma:** o backfill rodou limpo (zero erro, dado real gravado em `metrics_daily`/`ads`/etc.,
confirmável por query direta), mas a tela de Saúde da Coleta continuou mostrando as mesmas contas
como "Atrasada" com a MESMA data antiga, mesmo depois do F5.

**Causa raiz:** `worker/collector.py` tem duas funções que fazem coisas parecidas mas não a mesma
coisa. `collect_all()` (o caminho do cron) chama `_log_collection(acc["id"], date, "SUCCESS"/"FAILED")`
pra cada conta — é isso que grava em `collection_log`, a tabela que a tela de saúde lê. O caminho CLI
(`--account-id`) chama `collect_with_retry()` DIRETO, pulando esse logging por inteiro. Os dois
caminhos escrevem a MESMA métrica em `metrics_daily`, mas só um escreve o "aconteceu" em
`collection_log`.

**Solução:** depois de qualquer backfill manual via `--account-id`, gravar `collection_log` à parte,
via SQL direto (idempotente, `ON CONFLICT (ad_account_id, date) DO UPDATE`):
```sql
INSERT INTO public.collection_log (ad_account_id, date, status, finished_at)
SELECT aid::uuid, d::date, 'SUCCESS', now()
FROM unnest(ARRAY['<uuid-1>','<uuid-2>']::text[]) aid
CROSS JOIN generate_series('<inicio>'::date, '<fim>'::date, '1 day') d
ON CONFLICT (ad_account_id, date) DO UPDATE SET status='SUCCESS', error_message=NULL, finished_at=now();
```
`ad_account_id` aqui é o `id` INTERNO (UUID) de `client_ad_accounts`, não o `account_id` da
plataforma (Meta/Google) — os dois são campos diferentes na mesma tabela, fácil de confundir.
Correção estrutural (não feita, registrada como dívida): `collect_with_retry` podia sempre chamar
`_log_collection` também, unificando os dois caminhos.

**Ref:** Paid Media Automation, sessão 2026-08-06 (cont.155→156) — backfill D4U (6 contas Meta,
01/01→05/08/2026), `client_ad_accounts.client_id = 77d723a1-...` (nome interno do cliente ainda
"Gustavo", `account_name` de cada conta já rebrandeado pra "D4U" — outra pegadinha de busca por nome).

---

## `subprocess.run(text=True)` sem `encoding=` decodifica stdout como cp1252 no Windows — texto acentuado derruba a thread leitora {#subprocess-text-true-sem-encoding-cp1252}

`tags: subprocess, text=True, encoding, cp1252, UnicodeDecodeError, _readerthread, stdout None, AttributeError, SSH, ssh_runner, Windows, acento, PT-BR, PowerShell`

**Contexto:** função wrapper de SSH (`runRemote`/equivalente) que roda `subprocess.run([...], capture_output=True, text=True, timeout=...)` sem `encoding=` explícito, usada pra rodar `psql`/comandos remotos e capturar o `stdout`. Funciona meses a fio até um caller passar a puxar de volta um campo do banco com acento/emoji (ex.: `SELECT conteudo FROM whatsapp_logs` — resposta real de um bot em PT-BR).

**Sintoma:** dois erros distintos, dependendo de QUAL lado tem o não-ASCII:
1. Se o **stdout remoto** trouxer acento: `Exception in thread Thread-NNN (_readerthread) ... UnicodeDecodeError: 'charmap' codec can't decode byte 0x8d` — a thread interna do `subprocess` que lê o pipe crasha, `result.stdout` fica **`None`**, e o caller quebra em `result.stdout.strip()` com `AttributeError: 'NoneType' object has no attribute 'strip'` — **mascarando** o `RuntimeError` de SSH que o código já tratava.
2. Se o **texto que você tenta imprimir** (não o subprocess) tiver acento/emoji: erro diferente, ver [Fact-check INFUNDADO](#fact-check-infundado-e-nao-verificado) (`print()`/`cp1252`) — sintoma irmão, causa e fix diferentes (esse aqui é sobre CAPTURAR output de outro processo, não sobre IMPRIMIR o seu).

**Causa raiz:** `text=True` sem `encoding=` usa `locale.getpreferredencoding()` pra decodificar `stdout`/`stderr` — no Windows isso é **cp1252**, não UTF-8, mesmo com o terminal/console em UTF-8. `psql`/SSH devolvem UTF-8 (o Postgres e o texto do banco são UTF-8); qualquer byte multibyte que não mapeia em cp1252 derruba a decodificação.

**Solução:** fixar `encoding="utf-8", errors="replace"` explicitamente no `subprocess.run(..., text=True, ...)`. `errors="replace"` evita crash mesmo em byte genuinamente inválido (troca por `�` em vez de explodir). Mesmo padrão já usado em scripts de deploy do mesmo projeto (`deploy_v2.py`) — mas `ssh_runner.py`/wrappers de SSH mais antigos costumam não ter isso, porque o bug só aparece quando alguém puxa texto PT-BR de volta pelo SSH, não em comandos puramente ASCII (`docker ps`, `SELECT count(*)`, etc.).

```python
result = subprocess.run(
    [...],
    capture_output=True,
    text=True,
    encoding="utf-8",
    errors="replace",
    timeout=timeout,
)
```

**Relacionado:** [Hook `.ps1` quebra com erro de parser / acento vira caractere estranho](#ps51-ascii-hooks) — mesma família cp1252-no-Windows, causa raiz diferente (parser de `.ps1` sem BOM, não `subprocess.run`).

**Ref:** Família Milionária, sessão 2026-08-06 — achado ao vivo rodando `execution/smoke_dividas.py`
(smoke test conversacional via webhook real) contra produção; `execution/ssh_runner.py:runRemote`.

---

## Elemento preso dentro de card `overflow-hidden`+`rounded-*` não escapa com margin negativo — usa `createPortal` {#portal-escape-overflow-hidden-card}

`tags: React, createPortal, overflow-hidden, rounded corners, negative margin, full-bleed, card layout, shell redesign, clip, z-index, Next.js`

**Contexto:** redesenho de shell/layout onde a página vira um "card" flutuante (borda + `border-radius`
+ `overflow-hidden`, comum em padrões tipo "bento box" ou "cards flutuando sobre canvas escuro") — e
UM elemento específico (um título/breadcrumb isolado, um FAB, um banner) precisa aparecer visualmente
FORA desse card, sobre o fundo, não dentro dele.

**Sintoma:** a tentativa óbvia — `margin` negativo no elemento (a mesma técnica que já funciona pra
sangria full-bleed contra o padding de um container SEM `overflow-hidden`) — não move o elemento pra
fora visualmente. Ou o elemento fica cortado na borda arredondada do card (a parte que "escaparia" some),
ou continua dentro do card com um respiro estranho, dependendo de quanto negative margin foi aplicado.

**Causa raiz:** `overflow: hidden` recorta qualquer conteúdo do FILHO que ultrapasse a caixa do PAI,
independente de margin. `border-radius` faz esse recorte seguir a curva do canto, não um retângulo —
então mesmo se `overflow` fosse `visible`, o conteúdo "vazando" ficaria com uma esquina cortada de
forma visualmente óbvia e feia. Margin negativo desloca a posição do elemento DENTRO do fluxo do pai;
não desanexa o elemento da árvore DOM do pai. Pra um elemento aparecer genuinamente FORA da caixa
visual do card, ele precisa deixar de ser descendente DOM daquele card — não é um problema de
posicionamento, é um problema de ONDE o nó vive na árvore.

**Solução:** `ReactDOM.createPortal`. Renderize um slot vazio (`<div id="slot-id" />`) como IRMÃO do
card (fora da árvore que tem `overflow-hidden`), na posição visual correta (ex.: antes do card, com
gap). O componente que precisa "escapar" passa a portar seu conteúdo pra esse slot:

```tsx
// No componente-pai (o shell/layout), FORA do card com overflow-hidden:
<div id="page-header-slot" className="shrink-0" />
<div className="rounded-2xl overflow-hidden border ...">
  {children}
</div>

// No componente que precisa escapar (já client component):
const [portalTarget, setPortalTarget] = useState<HTMLElement | null>(null);
useEffect(() => {
  setPortalTarget(document.getElementById("page-header-slot"));
}, []);

if (!portalTarget) return null; // SSR-safe: sem alvo, sem render (evita mismatch)
return createPortal(<div>...</div>, portalTarget);
```

Pontos que mordem se esquecidos:
- **SSR-safe:** `document` só existe no client. Sempre `useEffect` + `useState` pra achar o alvo — nunca
  chame `createPortal` direto no corpo do componente com `document.getElementById` (quebra SSR).
- **Ordem de render:** o alvo (slot no pai/ancestral) precisa existir no DOM ANTES do componente que
  porta rodar seu efeito. Como React commita pais antes dos efeitos dos filhos dispararem, isso é
  garantido automaticamente se o slot é renderizado por um ANCESTRAL — não funciona se dois componentes
  irmãos tentam coordenar a ordem sozinhos.
- **Teste que renderiza o componente ISOLADO** (fora da árvore real do app, comum em testes de unidade
  com Testing Library) precisa criar o elemento-alvo manualmente no DOM de teste (`document.body`)
  antes de renderizar — senão o componente não encontra o alvo e não renderiza nada, o que PARECE
  regressão mas é o contrato novo funcionando (retornando `null` por design).
- Sem alvo nenhum e sem tratar isso, o componente quebra tentando `createPortal(content, null)`
  (React lança erro) — sempre faça o `if (!portalTarget) return null` guard.

**Relacionado:** técnica gêmea — quando o problema é só "página precisa ocupar a largura toda ignorando
o padding do shell" (sem precisar sair da árvore DOM), a solução certa costuma ser margin negativo
mesmo, cancelando o padding do ancestral — MAS só funciona se esse ancestral não tem `overflow-hidden`.
Antes de escolher entre as duas técnicas, confira se o ancestral que você quer atravessar tem
`overflow-hidden`/`clip-path`: se tem, é portal; se não tem, margin negativo resolve mais simples.

**Ref:** Paid Media Automation, sessão 2026-08-06/07 (cont.156) — redesenho de shell (sidebar+`<main>`
viram cards flutuando sobre canvas escuro, pedido inspirado em outro produto). `ClientTabBar`
(`web/src/components/client-tab-bar.tsx`) precisava aparecer isolado, fora do card branco do
conteúdo — `web/src/app/dashboard/shell.tsx` ganhou o slot `#dashboard-page-header`.

---

## Comentário `//` na mesma linha de `function nome(){` engole a declaração inteira — nada no app funciona, e o erro aponta pra linha errada {#comentario-engole-function}

`tags: JavaScript, comentario de linha, single-line comment, SyntaxError, Illegal return statement, Unexpected token, script inteiro falha, HTML single-file app, node --check`

**Contexto:** copiando/adaptando um app HTML+JS single-file de terceiros (sem build step, tudo num
`<script>` inline) pra produção — cenário comum quando se prioriza velocidade e se copia um repo
pronto em vez de reescrever do zero.

**Sintoma:** o app carrega normalmente (HTTP 200, título certo, HTML/CSS renderizam), mas **nenhuma
interação funciona** — nenhum botão responde, nenhum listener dispara, mesmo os completamente
alheios ao trecho quebrado. O usuário relata um sintoma específico ("não consigo adicionar X"), mas
na verdade é o app INTEIRO que está morto. Console mostra um erro de sintaxe (`Illegal return
statement`, ou dependendo do parser, `Unexpected token '}'`) numa linha que não tem relação óbvia
com a feature reportada como quebrada.

**Causa raiz:** em algum lugar do arquivo, uma linha tem `// comentário` seguido, na MESMA linha, de
código real — ex.: `let x={}; // nota function minhaFuncao(){`. O comentário de linha única comenta
tudo até o fim da linha, **incluindo a declaração da função que vinha logo depois**. O corpo da
função (as linhas seguintes, que o autor pretendia que ficassem dentro dela) vira código solto fora
de qualquer função: qualquer `return` ali dispara `Illegal return statement`, e a chave `}` de
fechamento no fim da função vira `Unexpected token '}'` sem abertura correspondente. Como isso quebra
o **parse** do arquivo JS inteiro (não é um erro de runtime isolado numa função), o script inteiro
falha ao carregar e **nada depois dele roda** — inclusive `addEventListener`/`.onclick=` de features
completamente não relacionadas ao trecho quebrado.

**Solução:**
1. Antes de assumir "só tem um bug pequeno na feature X", valide a sintaxe do `<script>` isolado:
   ```bash
   awk '/<script>/{flag=1;next}/<\/script>/{flag=0}flag' index.html > /tmp/script.js
   node --check /tmp/script.js
   ```
   Um `SyntaxError` aqui explica sintomas "o app inteiro está morto" muito mais rápido que debugar a
   feature relatada isoladamente.
2. Localize o padrão com `grep -n '//[^\n]*function'` (comentário de linha seguido de `function` na
   mesma linha) — é o caso mais comum, mas qualquer código real após `//` na mesma linha serve.
3. Mova o código real pra linha própria, deixando o comentário sozinho:
   ```diff
   - let x={}; // nota function minhaFuncao(){
   + let x={}; // nota
   + function minhaFuncao(){
   ```
4. Re-rode `node --check` pra confirmar antes de commitar/deployar.

**Relacionado:** [Guarda que o entrypoint real nunca alcança](#guarda-morta-entrypoint) — mesma
família "o gate/código parece existir mas nunca roda", causa raiz diferente (aqui é parse-time, não
um guard mal-cabeado). [Ferramenta de monitoramento roda INERTE com os testes verdes](#source-clobra-entry-point)
— mesmo padrão de "sintoma isolado esconde falha total", root cause diferente.

**Ref:** Caxeta (marcador de partidas de cacheta), sessão 2026-08-07 — bug herdado do repo original
copiado (`ricardolaquino/Marcador-de-Caxeta-`), linha `let settleShares={}; // id -> reais string
function openSettle(){`. Usuário reportou "não consigo adicionar jogador"; reproduzido ao vivo via
Playwright (`browser_console_messages` mostrava `Illegal return statement`); causa raiz confirmada
com `node --check` no `<script>` extraído (apontou `Unexpected token '}'` na chave de fechamento
órfã, ~150 linhas depois do defeito real). Corrigido movendo `function openSettle(){` pra linha
própria — commit `3973e1a`.

---

## Browser MCP (Playwright/Chrome-DevTools) pode estar conectado a um perfil Chrome REAL com sessão AO VIVO do operador, não um perfil isolado {#browser-mcp-sessao-ao-vivo-operador}

`tags: playwright mcp, chrome-devtools mcp, browser automation, profile compartilhado, sessão ao vivo, e2e produção, campo preenchido sozinho, navegação inesperada, concorrência humano-agente`

**Contexto:** verificando visualmente uma feature web em produção via `browser_navigate`/
`browser_snapshot` do Playwright MCP (ou chrome-devtools MCP), depois de um dos dois servidores
desconectar e liberar um lock de `userDataDir` que os dois disputavam.

**Sintoma:** `browser_navigate` pra uma rota autenticada abre DIRETO numa sessão já logada (nome,
dados reais do usuário visíveis) — sem o agente ter feito login. Ao reabrir um form pra completar a
verificação (ex.: reabrir um modal "Novo item"), os campos vêm **preenchidos com dado que o agente
não digitou**, e a página navega sozinha pra outra rota sem nenhuma chamada `browser_navigate` do
agente.

**Causa raiz:** o MCP de browser não estava apontando pra um perfil `--isolated`/efêmero — estava
conectado ao perfil Chrome PESSOAL do operador (o mesmo que ele usa no dia a dia), que já tinha uma
sessão autenticada viva. O operador estava usando o app **em paralelo**, na mesma aba/perfil que o
agente estava controlando via automação. Login sem interação do agente, campo preenchido do nada e
navegação não solicitada são os 3 sinais de que isso está acontecendo — não é bug do MCP, é
compartilhamento genuíno de sessão com um humano.

**Por que é perigoso:** cliques/navegação do agente competem com a interação real da pessoa —
podem sobrescrever o que ela estava digitando, navegar pra longe da tela em que ela estava
trabalhando, ou (pior) o agente poderia clicar "Salvar"/"Criar" em cima de dado que não é seu,
submetendo algo indesejado numa conta de produção real. Categoria de risco distinta de
[Duas sessões Claude no MESMO diretório colidem](#sessoes-paralelas-mesmo-diretorio-colidem) — ali
é agente-vs-agente; aqui é agente-vs-humano-real-usando-o-produto.

**Solução / como aplicar:**
1. Antes de clicar/preencher/submeter qualquer coisa, `browser_snapshot` primeiro. Se algum campo já
   tiver texto que você não colocou lá, ou se você chegou autenticado sem ter feito login, TRATE
   como sessão possivelmente compartilhada.
2. Prefira uma leitura passiva (abrir modal só pra conferir estrutura, sem submeter) pra confirmar
   UI; só avance pra CRUD ativo (criar/editar/deletar) com alta confiança de que é seguro — ou numa
   sessão que você sabe que é isolada.
3. Ao detectar sinal de atividade concorrente, PARE imediatamente. Não tente "consertar" clicando em
   Cancelar repetidamente (isso também é uma ação na sessão de outra pessoa) — avise o operador
   direto e peça pra ele confirmar que nada ficou fora do lugar do lado dele.
4. Se a config do MCP permitir `--isolated`/um `userDataDir` próprio, prefira isso pra qualquer
   verificação automatizada de UI — evita a classe inteira do problema.

**Ref:** Família Milionária, sessão 2026-08-07 — verificação da feature Metas/Desejos (`/metas`);
Chrome-DevTools MCP desconectou, Playwright MCP assumiu o mesmo perfil e caiu numa sessão real do
operador (campo "Evelyn"/"Evelyn IPTU" preenchido sozinho, navegação pra `/dividas` não solicitada).
Agente parou antes de submeter qualquer coisa; operador confirmou que nada ficou fora do lugar.

---

## Smoke test conversacional (webhook + estado de sessão de bot): mandar a próxima mensagem sem confirmar o estado via poll() cascateia falso-negativo {#smoke-conversacional-sessao-presa-cascateia}

`tags: smoke test, bot conversacional, webhook, whatsapp, estado de sessão, confirmation state, poll, falso negativo, cascata, teste em produção`

**Contexto:** smoke test que injeta mensagens sequenciais REAIS (assinadas HMAC) contra um bot
conversacional em produção, onde o bot usa uma máquina de estados de sessão (`CONFIRMATION_STATES`
ou equivalente) — comum em bots de criação-com-confirmação (WhatsApp, etc.) que perguntam um dado
faltante antes de confirmar.

**Sintoma:** um cenário do meio do script (ex.: "testar recusa de confirmação") falha, e TODOS os
cenários seguintes do mesmo script também falham, com uma resposta genérica/de erro repetida
("não entendi", menu de desambiguação) que não tem nada a ver com o que cada mensagem pedia.
Parece bug de produto generalizado, mas só o primeiro cenário tem causa real.

**Causa raiz:** o script assumiu que uma mensagem de setup levaria a sessão a um estado específico
(ex.: "confirmando_X", pronto pra receber sim/não), sem checar isso via `poll()` antes de mandar a
próxima mensagem. Na prática a mensagem de setup não tinha sinal suficiente (ex.: faltava uma
keyword que o extrator de intent precisa) e o bot foi pra um estado DIFERENTE (ex.: "perguntando
categoria/campo faltante"). A mensagem seguinte do script ("nao", pensada como recusa de
confirmação) foi interpretada como resposta INVÁLIDA daquele outro estado — e, por design correto
do bot (não limpar sessão em resposta inválida, só repetir a pergunta), a sessão ficou PRESA
esperando uma resposta válida pro resto do script. Toda mensagem seguinte (consulta, ação, setup do
próximo cenário) foi interceptada pelo handler desse estado pendente.

**Solução:**
1. Em qualquer bloco do script que depende de um estado específico ter sido atingido, confirme com
   `poll(query_do_estado, "estado_esperado", timeout)` **antes** de mandar a mensagem que depende
   dele — nunca assuma a transição só porque a mensagem anterior "parecia" certa.
2. Se o cenário pretende testar uma RECUSA/cancelamento de confirmação, garanta que a mensagem de
   setup tem sinal suficiente (keyword detectável, etc.) pra chegar no estado de confirmação de
   verdade antes de mandar a recusa — não escolha a frase de setup mais "neutra" só porque parece
   representativa; teste primeiro que ela bate o estado certo.
3. Isolar cada cenário num bloco com `try/except` (`runBlock`) evita que uma EXCEÇÃO derrube o
   script inteiro, mas **não substitui** o `poll()` de estado — uma sessão presa sem exceção passa
   reto pelo `runBlock` e ainda cascateia falso-negativo por todos os cenários seguintes.

**Ref:** Família Milionária, `execution/smoke_metas.py` (Fase 2, Metas/Desejos), 2026-08-07 — 1ª
rodada teve 4 falsas-FALHA em cascata porque o cenário de recusa mandava "nao" numa frase sem
keyword de categoria (foi pra `aguardando_categoria_meta`, não `confirmando_meta`); corrigido
trocando a frase de setup por uma com keyword válida, e a suíte foi de 9/13 pra 15/15 PASS.

---

## Watchdog de confirmação de entrega dispara falso-positivo contra device de teste automatizado (não gera ack) {#watchdog-ack-device-teste-automatizado}

`tags: watchdog, health check, delivery confirmation, ack, whatsapp, gowa, device de teste, falso positivo, alerta, monitoring, smoke test`

**Contexto:** watchdog "anti-mudo" que alerta quando N envios recentes de um canal (WhatsApp/GOWA,
mas a classe vale pra qualquer canal com confirmação de entrega assíncrona) ficam TODOS sem ack
(delivered/read) numa janela de tempo — sinal de sessão/dispositivo desconectado do lado de quem
envia.

**Sintoma:** alerta "N mensagens sem confirmação de entrega, verifique se o WhatsApp/device está
conectado" disparando repetidamente, sempre que alguém roda um smoke test/e2e contra o bot. O
device/canal de envio está saudável (mensagens chegam de verdade, confirmável lendo o histórico
por outra via), mas o alerta insiste.

**Causa raiz:** o RECEBEDOR das mensagens de teste é ELE MESMO um device/cliente automatizado
(ex.: um segundo bot/harness usado só pra disparar smokes), e não implementa o lado do protocolo
que gera confirmação de entrega/leitura (isso normalmente vem do cliente humano abrindo o app). O
watchdog mede corretamente "o envio nunca foi confirmado" — só que a premissa "sem confirmação =
problema no remetente" não vale quando o DESTINATÁRIO é quem nunca confirma, não importa o quão
saudável o remetente esteja.

**Solução:**
1. Identifique o(s) contato(s)/peer(s) automatizados usados só pra teste (harness de smoke, bot
   espelho, etc.) — geralmente têm um `contact_id`/número fixo e conhecido.
2. Adicione uma exclusão EXPLÍCITA e opt-in (via env/config, não hardcoded no código de produção)
   que remove esses contatos da contagem do watchdog, sem alterar o comportamento pra qualquer
   outro contato. Lista vazia/não-setada = comportamento antigo, sem filtro (default seguro).
3. NÃO desative o watchdog nem aumente o threshold pra "resolver" o ruído — isso mascara o caso
   real (contato humano genuíno sem confirmação). A exclusão tem que ser por IDENTIDADE do peer de
   teste, não por volume/frequência.
4. Confirme a causa ANTES de excluir: cheque a confirmação de entrega de um contato REAL no mesmo
   canal nesse intervalo — se ele recebe ack normalmente e só o device de teste não, a causa é o
   device de teste, não uma falha real de conectividade.

**Ref:** tiatendo, `execution/database/models/ackModel.py` (`tenantsWithSilentSends`) +
`execution/core/backgroundRunner.py` (`_ackWatchdogTick`), 2026-08-07 — alerta "N mensagens sem
confirmação de entrega" no tenant sabor-do-teste correlacionava 1:1 com sessões de smoke test
contra o device `whatsapp_de_testes`; contatos reais no mesmo tenant confirmavam entrega em 1-5s.
Fix: `ACK_WATCHDOG_EXCLUDE_CONTACTS` (env, csv, opt-in).

---

## Hook PowerShell roda sob `powershell.exe` 5.1, não `pwsh` — arquivo produzido sem BOM (ou teste com acento literal no source) corrompe/quebra silenciosamente {#hook-powershell-51-sem-bom-corrompe}

`tags: powershell 5.1 vs 7, BOM UTF-8, encoding ANSI codepage, Get-Content sem encoding, hook cmd wrapper, ps51-compat, caractere acentuado literal em ps1, mojibake`

**Contexto:** ao construir dois scripts (`autorizar-acao-externa.ps1`,
`registrar-uso-autorizacao.ps1`) que produzem/consomem um arquivo JSON lido por um hook
PreToolUse (`external-action-guard.ps1`), um campo de texto livre com acento (`motivo`) voltava
corrompido (`"correção"` virava `"correÃ§Ã£o"`) quando o hook processava o arquivo.

**Causa raiz (duas camadas do mesmo problema):**
1. O `.cmd` wrapper do hook (`external-action-guard.cmd`) invoca `powershell.exe`
   (Windows PowerShell 5.1), não `pwsh` (PowerShell 7) — mesmo em máquina com PS7 instalado. O
   `.ps1` do hook lia o arquivo via `Get-Content $authFile -Raw | ConvertFrom-Json`, **sem**
   `-Encoding` explícito. O script produtor gravava com
   `[IO.File]::WriteAllText(..., New-Object System.Text.UTF8Encoding($false))` (UTF-8 **sem**
   BOM) — a convenção "ASCII puro" já estabelecida no kit pra outros scripts. Sem BOM, o 5.1
   decide o encoding por heurística e cai no codepage ANSI do Windows pra texto acentuado — os
   dois bytes UTF-8 de um caractere acentuado viram dois caracteres ANSI errados (mojibake), não
   um erro visível.
2. Ao escrever um teste de regressão pra esse bug, o próprio texto acentuado de teste
   (`"correção-urgente-acentuada"`) foi digitado como caractere literal no **código-fonte** do
   arquivo `.tests.ps1`. Isso reintroduziu o MESMO problema numa camada diferente: o teste-guarda
   já existente no kit (`ps51-compat.tests.ps1`, "nenhum .ps1 do kit tem caractere não-ASCII sem
   BOM") pegou o arquivo de teste como violação — porque ele também não tinha BOM.

**Solução:**
- Quando um script PRODUZ um arquivo que um hook (ou qualquer coisa rodando sob `powershell.exe`
  5.1) vai LER: grave com BOM (`New-Object System.Text.UTF8Encoding($true)`), quebrando a
  convenção "sem BOM" só nesse ponto específico, com comentário explicando por quê. **E** o lado
  que lê deveria usar `-Encoding UTF8` explícito de qualquer forma (defesa em profundidade) — mas
  como o hook já estava em produção e mudar hook de segurança é escopo maior, o BOM no lado
  produtor resolveu sem tocar no hook.
- Quando for escrever TEXTO acentuado dentro do código-fonte de um `.ps1` (não em dado de
  runtime, no próprio arquivo), nunca usar o caractere literal — construir via `[char]0x00E7`
  (ç), `[char]0x00E3` (ã), etc., concatenados. Mantém o arquivo-fonte ASCII puro (parseia igual
  em 5.1 e 7, sem risco de BOM) enquanto ainda testa o comportamento de runtime com acento de
  verdade.
- Pra confirmar qual PowerShell um `.cmd` wrapper realmente invoca, ler o `.cmd` direto — não
  assumir que "a máquina tem PS7 instalado" significa que o hook roda nele.

**Trade-off:** nenhum real — BOM no arquivo de dado JSON produzido por um script não quebra nada
que já lê esse arquivo (JSON com BOM é tolerado por `ConvertFrom-Json` em ambas as versões); só
quebraria se algo fizesse comparação byte-a-byte estrita do conteúdo, o que não é o caso aqui.

**Ref:** percus-kit, plano `docs/superpowers/plans/2026-08-06-r20-autorizacao-lote.md`, Tasks 4-5
(sessão 2026-08-07, achado em code review + confirmado empiricamente contra `powershell.exe` 5.1
real).

## Mockup aprovado nunca gerado pelo algoritmo real de layout diverge da produção

**Sintoma:** operador aprova uma prévia (Claude Artifact) com nós/raias organizados de um jeito
limpo; a implementação real usa um algoritmo de layout determinístico já existente (BFS+baricentro,
ou qualquer coisa que calcule posição a partir de dado real); em produção, com dado denso de
verdade, a ordem visual sai completamente diferente do que foi aprovado — parece regressão, mas o
código está "correto" (fez exatamente o que a spec pedia).

**Causa raiz:** o mockup foi posicionado À MÃO (coordenadas fixas, pensadas pra ilustrar o
CONCEITO) em vez de rodar o algoritmo real contra dado real. Funciona pra aprovar a IDEIA (cores,
interação, tipos de nó) mas nunca prova que o algoritmo de POSICIONAMENTO vai produzir aquilo — são
duas coisas diferentes sendo aprovadas junto sem querer.

**Solução:** ao construir a prévia de um redesenho que envolve um algoritmo de layout existente
(não só estilo/interação), rodar esse algoritmo de verdade contra uma amostra real de dado antes de
pedir aprovação — nem que seja um script standalone que chama a função de layout e dumpa
coordenadas, sem precisar do app inteiro rodando. Se isso não for viável a tempo, pelo menos avisar
explicitamente na hora da aprovação: "isto é só o CONCEITO visual, o posicionamento real vai vir do
algoritmo X, ainda não testado contra este mockup".

**Ref:** Paid Media Automation, cont.157 (2026-08-07), Fluxo de Páginas — raias de canal + tipo de
conversão. Ver `docs/adrs/0008-fluxo-de-paginas-permanece-literal-em-raias.md` e
`docs/STATUS.md` ADENDO 31/32.

## Resgatar commit que caiu no branch errado por colisão de sessão paralela (sem perder o trabalho de nenhum dos dois lados)

**Sintoma:** um commit termina normalmente, mas o branch atual não era o esperado (outra sessão
tinha trocado de branch nesse working tree compartilhado, com mudanças já staged dela) — o commit
acabou de propósito em cima do trabalho alheio.

**Solução (não-destrutiva):** criar uma ref nova apontando pro commit certo
(`git branch <nome-novo> <sha>`), depois mover o branch errado de volta com reset MISTO — nunca
`--hard` — pro sha anterior ao commit que caiu no lugar errado. `git branch` só cria ref, não mexe
em nada. O reset misto move o ponteiro do branch e reseta o ÍNDICE pro estado anterior, mas NUNCA
toca o working tree — os arquivos que a outra sessão tinha modificado (agora "unstaged" em vez de
"staged") continuam com o conteúdo dela intacto, ela só precisa re-adicionar antes do próximo
commit dela. Confirme ANTES que o branch-alvo não está checked-out em nenhum worktree
(`git worktree list`) — se estiver, prefira `git fetch . origem:destino` em vez de mexer direto (
recusa com segurança se o destino estiver em uso).

**Lição maior:** isso só foi necessário porque a primeira task de uma execução subagent-driven
rodou no working tree COMPARTILHADO em vez de um worktree isolado — o próprio plano já mandava usar
worktree isolado desde o início. Criar o worktree ANTES da primeira task evita o problema inteiro.

**Ref:** Paid Media Automation, cont.157 (2026-08-07).

## QA visual de tela autenticada sem OTP real (dashboard com login por telefone/magic-link)

**Sintoma:** precisa validar visualmente (screenshot real, não leitura de CSS) uma tela do painel
que exige login (OTP WhatsApp / JWT de auth-service externo), e não há como receber o OTP
programaticamente nem forjar o JWT (chave de assinatura vive num serviço externo).

**Solução:** o próprio FastAPI permite `app.dependency_overrides[requireAuth] = lambda: {...sessão
fake...}` — mesmo padrão que os testes de rota já usam (`tests/dashboard/test_xss_conversation_list.py`).
Rodar dentro do container de produção (mesmo banco, dado real, sem precisar de DB local):
1. Override da dependência de auth, request via `httpx.AsyncClient(transport=ASGITransport(app=...))`
   contra a rota de página inteira (não só o endpoint JSON) — devolve o HTML final igual ao usuário
   veria.
2. Salvar o HTML + baixar (`docker cp`) só as pastas `static/css`, `static/js`, `static/img`
   referenciadas (nunca a pasta `static/` inteira — pode ter dezenas de MB de upload de tenant que
   não tem nada a ver com a tela).
3. Servir localmente (`python -m http.server` na pasta que espelha os paths absolutos `/admin/...`
   do HTML) e apontar Playwright/Chrome DevTools MCP pra lá.

**Armadilha**: a sessão fake precisa de um `role` que EXISTA no mapa de abilities do RBAC (`super_admin`
faz bypass de tudo; qualquer outro precisa bater um `ROLE_ABILITIES` real — `"owner"` não existe nesse
projeto, o role de dono é `"tenant_admin"`) — usar um role inventado quebra com 403 `"missing ability"`
sem dizer o motivo real (parece erro de tenant, é erro de nome de role).

**Trade-off:** o HTML capturado é um snapshot; qualquer chamada HTMX/fetch subsequente (buscar lista
de conversas, etc.) vai falhar se a sessão fake não tiver CSRF token real — serve pra validar LAYOUT/CSS
estático, não pra testar interação viva. Pra isso, ainda é preciso login real.

**Ref:** tiatendo, sessão 2026-08-07 (validação da rota `/conversations` durante reskin visual).

## Pagar.me recusa cobrança com erro rotativo (telefone → documento → billing_address) sem dizer os 3 de uma vez

**Sintoma:** criar um customer + card + subscription real (mesmo em `PAGARME_ENV=test`) falha com
`subscription.status = "failed"` (não um erro HTTP — a chamada "funciona", só o resultado final é
falho). A API devolve só UM motivo por vez em `last_transaction.gateway_response.errors` (ex.: `"At
least one customer phone is required"`); corrigir esse e tentar de novo revela o PRÓXIMO requisito
faltando (`"The customer Document is required"`), e depois o seguinte (`"billing | value is
required"` = falta `billing_address`).

**Causa raiz:** com antifraude ligado na conta Pagar.me (padrão), uma cobrança de cartão de crédito
precisa de: telefone do customer, documento (CPF/CNPJ) do customer, E `billing_address` — mas esse
último não é um campo do `customer`, é um campo do **`card`** (`POST /customers/{id}/cards` aceita
`{token, billing_address: {line_1, line_2, zip_code, city, state, country}}`), não documentado como
óbvio na maioria dos wrappers/exemplos.

**Solução:** ao integrar cobrança de cartão pela primeira vez, montar a chamada já com os 3 de uma
vez (telefone + documento + billing_address no card) em vez de descobrir um por um por tentativa e
erro — cada tentativa cria um customer/card/subscription real (mesmo que "failed") no painel Pagar.me,
poluindo o ambiente de teste.

**Ref:** tiatendo, sessão 2026-08-07 (smoke `PAGARME_ENV=test` de O4b, achou o gap real em
`pagarmeClient.createCard()`).

**Fechado (mesmo dia, sessão de continuação):** os 3 campos agora são coletados no formulário de
cartão (`saveCard()`) e enviados de uma vez. Confirmado em PROD `0.294.0` com smoke real
repetindo o mesmo roteiro — `createCard()` retornou `status=active` de primeira, sem nenhum dos 3
erros rotativos. Receita de smoke sem precisar de browser/OTP: ver
`{#smoke-pagarme-card-sem-browser}` em `COMO_FAZER.md`.

## Distinguir bug antigo (já corrigido) de regressão nova ao receber print de conversa real

**Sintoma:** operador manda screenshot de uma conversa real do WhatsApp mostrando um bug que "parece"
já ter sido corrigido numa sessão anterior — risco de (a) assumir que é regressão e sair caçando o
que "quebrou de novo" sem necessidade, ou (b) assumir que já está resolvido sem checar e ignorar uma
regressão real.

**Solução:** o app do WhatsApp mostra hora local do aparelho e agrupa por "Today" relativo a QUANDO
o screenshot foi tirado — não é confiável pra saber se aconteceu antes ou depois de um deploy do
mesmo dia. Achar a conversa exata no banco por conteúdo (`messages.content ILIKE`), pegar o
`created_at` (sempre UTC), e comparar contra o horário REAL do deploy/commit do fix (não só o texto
"hoje"). Se o fuso do operador for BRT (UTC-3), uma conversa "de ontem à noite, tipo 22h" pode cair
como UTC do dia SEGUINTE — o oposto do que a intuição sugere. Prova mais forte que só timestamp:
achar uma ocorrência IDÊNTICA do mesmo cenário numa conversa DIFERENTE, depois do deploy, e checar se
o comportamento lá já saiu correto — evidência comportamental direta bate qualquer inferência de
timestamp.

**Ref:** tiatendo, sessão 2026-08-07 (bug de desambiguação multi-sabor — conversa reportada era de
ANTES do fix `0.291.0`, não regressão).

## Deploy de sessão paralela sobrescreve o seu sem aviso {#deploy-paralelo-sobrescreve-sem-aviso}

tags: deploy, worktree, sessão paralela, colisão, drift, docker service, swarm, git log master

**Sintoma:** você confirma via smoke real (Playwright, curl) que seu fix está em produção. Minutos
ou horas depois, o mesmo bug volta — não porque seu código regrediu, mas porque OUTRA sessão
paralela fez deploy de uma imagem buildada a partir da PRÓPRIA branch dela, sem antes puxar seu
commit já mergeado em `master`. O `docker-compose.swarm.yml` comentado documenta o pin certo, mas
a imagem REAL rodando diverge do arquivo.

**Causa raiz:** duas sessões trabalhando no mesmo repositório sem worktree isolado desde o início
cada uma builda e faz deploy a partir do próprio checkout local, ignorando o que a outra mergeou
nesse meio tempo. Não é um erro de UMA sessão — é a ausência de coordenação entre elas.

**Solução:** nunca confie no `image:` do `docker-compose.swarm.yml` como fonte de verdade sobre o
que está no ar — sempre `docker service ps <serviço>` antes de assumir. Antes de QUALQUER build,
`git log master -1` e confirme que seus commits relevantes são ancestrais dessa tip; se a imagem
atual em prod não corresponde a um commit alcançável a partir do `master` local, é sinal de que
outra sessão buildou de uma branch própria — reconcilie (merge/cherry-pick na ordem certa) ANTES de
buildar, nunca depois. O padrão real: sessões paralelas SEM worktree isolado desde o início SEMPRE
colidem em algum deploy, é questão de quando, não de se.

**Ref:** Paid Media Automation, sessão cont.157 (2026-08-07) — fix do sidebar `033003a1` confirmado
em prod, revertido 32min depois por deploy `pageflow-13c711bd` da sessão paralela de Fluxo de
Páginas. 3ª ocorrência da mesma classe (ver também ADENDO 27/28/31 do STATUS.md desse projeto).

## Junction de node_modules compartilhada entre worktrees corrompe e trava Turbopack {#junction-node-modules-worktree-risco}

tags: node_modules, junction, symlink, worktree, npm ci, turbopack, next dev, windows, corrupção

**Sintoma:** múltiplos `npm ci` concorrentes em worktrees diferentes no mesmo disco Windows
corrompem uns aos outros (`ENOTEMPTY`, pacote sem `package.json`). A solução óbvia — apontar
`node_modules` de cada worktree pra uma cópia já saudável via junction (`New-Item -ItemType
Junction`) — resolve a lentidão mas introduz dois problemas novos, não óbvios até acontecerem.

**Causa raiz:** (1) Turbopack (bundler default do Next 16) valida que `node_modules` fica DENTRO da
raiz do projeto e recusa symlink/junction apontando pra fora — não é um bug, é validação
proposital. (2) qualquer processo que ESCREVA em `node_modules` (ex.: `next dev` auto-instalando um
`@types/*` que falta) mexe no alvo real da junction, corrompendo a cópia compartilhada pra TODOS os
worktrees que apontam pra ela — inclusive a sessão principal.

**Solução:** trate a junction como estritamente READ-ONLY — `tsc`/`vitest`/`next build` leem sem
escrever, então funcionam. Nunca rode `npm install`/`next dev` (que pode auto-instalar) contra uma
junction compartilhada; se precisar de dev server, use `next dev --webpack` (Turbopack recusa a
junction com `Symlink [project]/node_modules is invalid, it points out of the filesystem root`). Se
um subagent detectar escrita acontecendo no meio da tarefa, o certo é matar o processo na hora e
trocar pra uma cópia isolada (`npm ci` de verdade), não insistir na junction.

**Ref:** Paid Media Automation, sessão cont.157 (2026-08-07) — 3 subagents paralelos usando a mesma
junction; um pegou o `next dev` tentando `npm install --save-dev @types/node` através dela e matou
o processo antes de corromper.

## Dois hooks de pre-commit diferentes bloqueiam por motivos diferentes {#dois-hooks-pre-commit-r11-mock-scan}

tags: pre-commit, hook, mock-scan, R11, review, TODO, bloqueio, git commit

**Sintoma:** review R11 (`/percus-review:review`) passou sem achado, mas `git commit` ainda falha.
Fácil assumir que é o MESMO gate de review falhando de novo (e re-pedir review ao operador à toa,
perdendo tempo).

**Causa raiz:** existe um segundo hook, `mock-scan-pre-commit`, independente do R11 — ele varre o
diff por marcadores tipo `// TODO`/mock e bloqueia mesmo que o TODO seja PRÉ-EXISTENTE (não
introduzido pelo seu diff atual).

**Solução:** leia a mensagem do hook com atenção — ela cita o arquivo:linha exato — antes de
assumir que é o mesmo bloqueio de review R11. Resolver exige ou tocar o TODO pré-existente (fora do
escopo original da tarefa) ou pedir autorização explícita do operador pra um prefixo tipo
`MOCK-OK: <motivo>` — não é algo que o agente deve se autorizar sozinho.

**Ref:** Paid Media Automation, sessão cont.157 (2026-08-07) — trilha do título isolado bloqueada
por TODO em `approvals/page.tsx:138`, não relacionado ao diff da tarefa em andamento.

## Fluxo de confirmação com allowlist fixo cancela silenciosamente em vez de reprompt {#confirmacao-allowlist-cancela-em-vez-de-reprompt}

tags: confirmacao, bot, whatsapp, allowlist, sim nao, is_affirmative, is_negative, cancelamento silencioso, ux, fonte unica, correcao ambigua, reprompt

**Sintoma:** print de conversa real (usuário reporta bug): bot pede confirmação ("Responda *sim*
pra confirmar"), usuário responde algo que NÃO é "sim" mas também não é uma recusa de verdade — no
caso real, uma tentativa de CORRIGIR um dado errado no card ("Banco do Brasim" tentando consertar
um nome extraído errado). O bot trata isso como recusa e cancela: "Beleza, não cadastrei a dívida."
— sem avisar que não entendeu, perdendo o contexto e forçando o usuário a recomeçar do zero.

**Causa raiz:** o handler do estado de confirmação usava um **allowlist fixo** (`resp not in
("sim","s","confirmar","isso","pode","claro")` → cancela) em vez da fonte única de
afirmativo/negativo já estabelecida no projeto (`is_affirmative`/`is_negative`, com um TERCEIRO
resultado — indeterminado — que outros fluxos de confirmação do MESMO projeto já tratavam
corretamente com reprompt, não cancelamento). O fluxo novo (Dívida) foi escrito do zero em vez de
reusar o padrão já provado; um allowlist binário não tem como representar "não entendi", só
"sim"/"não" — qualquer coisa fora do allowlist vira "não" por construção.

**Solução:** confirmação com resposta em linguagem natural precisa de TRÊS resultados, não dois:
afirmativo → confirma; negativo explícito → cancela; **indeterminado → REPROMPTA mantendo o estado/
sessão vivo**, nunca cancela por default. Se o projeto já tem uma fonte única de classificação sim/
não (regex, `is_affirmative`/`is_negative`, ou equivalente) usada por outro fluxo de confirmação,
qualquer fluxo NOVO de confirmação deve reusá-la — não reinventar um allowlist ad-hoc. Teste que
prova a correção: mandar uma resposta plausível-mas-não-reconhecida (não é nem "sim" nem "não" óbvio)
e assertar que o estado NÃO foi limpo (sessão sobrevive) e a resposta não contém a mensagem de
cancelamento.

**Ref:** Família Milionária, sessão 2026-08-07 — `processDividaConfirmation` em
`familia-api/app/modules/whatsapp/divida_flow.py`, commit `4b6d127`. Fix trocou o allowlist por
`is_affirmative`/`is_negative` de `app.modules.whatsapp.intents` — mesma fonte já usada pela
confirmação de Lançamento (`_processConfirmation`) e por `processDividaSelection` no MESMO arquivo,
nunca adotada por `processDividaConfirmation`. Smoke ao vivo em prod reproduzindo a conversa exata
do print: 9/9 PASS.

## API serializa Decimal como STRING no JSON — `typeof x === 'number'` no frontend falha em silêncio {#decimal-serializado-como-string-typeof-number-falha}

tags: decimal, pydantic, fastapi, json, typeof, number, string, serializacao, frontend, dinheiro, preco, regressao, teste mockado diverge do real, e2e mock

**Sintoma:** tela mostra o preço/valor de TABELA em vez do valor real do contrato, mesmo com o
backend retornando o campo certo (`GET /billing/subscription` respondendo 200, sem erro). Card
"Status da assinatura" dizia R$19,90/mês pra quem paga R$11,94 (com cupom) — o MESMO bug já tinha
sido corrigido antes (fix documentado, deploy no ar), mas voltou a acontecer em prod.

**Causa raiz:** um `Decimal` num schema Pydantic (`valorMensal: Decimal | None = Field(alias=
"valor_mensal")`) serializa por padrão como **STRING** no JSON de resposta (`"valor_mensal":
"11.94"`, com aspas) — não como `number` — pra preservar precisão decimal. O código do frontend
fazia `typeof status?.valor_mensal === 'number' ? status.valor_mensal : null`, que é **sempre
falso** pra uma string, então tratava o valor como ausente e caía no fallback "sem valor cobrado"
(mostra o preço de tabela cheio, sem desconto). O bug NÃO aparecia nos testes porque o e2e mockava
a resposta com um NÚMERO literal JS (`valor_mensal: 11.94`), nunca exercitando o formato real que a
API devolve — teste verde, prod quebrado.

**Solução:** ao ler um campo Decimal/numérico vindo de uma API Python (Pydantic/FastAPI) no
frontend, NUNCA usar `typeof x === 'number'` como guarda de presença — o tipo declarado no
OpenAPI/TS gerado (`valor_mensal?: string | null`) já denuncia isso se for conferido antes de
escrever o guard. Checar `null`/`undefined` PRIMEIRO (`x == null`), só então coagir com `Number(x)`
(que aceita tanto string quanto number) — coagir direto sem o guard de nulidade troca o problema por
outro pior: `Number(null)` é `0` e `Number(undefined)` é `NaN`, reproduzindo a MESMA classe de
exibição errada (agora com "R$ 0,00" ou "NaN" em vez de mostrar o fallback correto). Padrão seguro:
`const valor = x != null ? Number(x) : null`. Se o mesmo campo já é lido em OUTRA tela do mesmo
projeto, verifique como ELA faz — muito provavelmente já tem o guard certo e é só replicar, em vez
de reinventar um novo que erra de novo. No teste, cubra os 3 formatos que a API pode mandar: string
válida (`"11.94"`), `null`, e ausente (`undefined`) — não só o que "faria sentido" em JS.

**Ref:** Família Milionária, sessão 2026-08-07 — `resumoPreco()` em
`familia-frontend/src/app/assinatura/page.tsx`, commit `9a3c684`. A tela irmã
`/assinatura/confirmacao` já tinha `Number(sub.valor_mensal)` certo desde 25/07 (linha 193) — nunca
foi replicado em `/assinatura`. Achado navegando a tela ao vivo em prod via Playwright MCP (não por
review de código) — API respondendo 200, zero erro de console, e mesmo assim preço errado. Fix
verificado chamando `fetch()` direto no endpoint pra ver o JSON cru antes de mexer no código
(`"valor_mensal":"11.94"`, com aspas — a prova).

## Deploy `--quick` pula o SCP INTEIRO, não só "arquivo novo" — código antigo compila e roda sem erro {#deploy-quick-pula-scp-inteiro-nao-so-arquivo-novo}

tags: deploy, scp, quick, docker build, footgun, stale code, cache, chunk hash, next.js, rebuild com codigo antigo

**Sintoma:** fix commitado, testado, `npm run build` local passa, `deploy_frontend_v2.py --quick`
roda sem erro, "Deploy complete!", `/health` ok — e o bug **continua no ar**, idêntico a antes do
fix. Nenhum erro em lugar nenhum; parece que o deploy "não pegou" por acaso.

**Causa raiz:** `--quick` foi desenhado (comentário no próprio script) pra pular só o SCP quando
"nenhum arquivo mudou" — mas na prática o parâmetro pula o passo de sincronização **por completo**,
incondicionalmente, sempre que passado, e reconstrói a imagem Docker **a partir do código já
presente na VPS** (do deploy anterior). Se o código local mudou desde o último deploy full — mesmo
sendo um arquivo MODIFICADO, não novo — o build na VPS usa a versão VELHA, produz um bundle/imagem
igualmente "válido" (compila, sobe, health-check passa) mas sem o fix. Confirmado inspecionando o
hash do chunk JS servido em prod vs. o hash do build local: divergiam mesmo após "deploy bem-
sucedido". A doc antiga ("`--quick` PULA SCP, arquivo NOVO exige FULL") estava incompleta — não é
só arquivo novo, é QUALQUER mudança não sincronizada antes.

**Solução:** depois de um fix, o PRIMEIRO deploy que o carrega tem que ser FULL (sem `--quick`),
mesmo que o footgun de uplink degradado torne isso mais lento/arriscado. Pra confirmar que o deploy
realmente pegou o código novo: comparar o hash do arquivo/chunk servido em prod (via `fetch()` no
console ou `docker exec <container> ls` no diretório de build) contra o hash do build local — nunca
confiar só em "Deploy complete!" + `/health` ok, porque um deploy com código velho passa exatamente
pelos mesmos checks que um com código novo.

**Ref:** Família Milionária, sessão 2026-08-07 — `execution/deploy_frontend_v2.py`. Descoberto
debugando por que o fix do bug de preço (ver entrada acima) continuava reproduzindo em prod mesmo
após "deploy completo": `docker exec <container> ls .next/static/chunks/app/assinatura/` mostrou o
hash do chunk ANTIGO mesmo com uma imagem Docker nova e com timestamp recente — o Dockerfile builda
a partir do código NO DISCO da VPS, que só é atualizado pelo passo de SCP que `--quick` pula.

## Classificador de handoff roda incondicionalmente ANTES do handler de confirmação — fix novo em `_processConfirmation` pode nascer morto {#classificador-handoff-intercepta-antes-do-handler-fix-inalcancavel}

tags: whatsapp, bot, confirmacao, handoff, classificador, regressao silenciosa, teste unitario pula camada, ambiguidade, reply novo ambiguo fallback, testes chamam funcao direto

**Sintoma:** um fix aplicado dentro do handler de um estado de confirmação (`_processConfirmation`)
tem 47 testes unitários passando, foi deployado há semanas, e continua **não funcionando** quando
testado ao vivo contra prod — a mensagem que deveria disparar o fix nunca chega nem perto dele; o
bot responde com um menu de ambiguidade genérico ("Não ficou claro o que você quis dizer...").

**Causa raiz:** existe uma camada de classificação (`handoff_detector.classificarMensagemPendente`)
que roda **incondicionalmente**, ANTES de qualquer handler de estado, sempre que a sessão está num
estado de confirmação pendente — decide se a mensagem é `reply` (segue pro handler normal), `novo`
(abre menu de gasto novo), `ambiguo` (abre menu de esclarecimento) ou `fallback`. Essa camada foi
escrita numa sessão ANTERIOR ao fix, e o fix novo assumiu (documentado no próprio docstring do
código) que "mensagens de X nunca chegam aqui, o guard já desvia antes" — mas o guard desviava só
UM tipo de mensagem (gasto novo com verbo+dinheiro), não o tipo que o fix precisava alcançar
(correção de data, que tem número mas não bate nenhum padrão de "reply" conhecido pelo
classificador) → cai em "ambíguo" → NUNCA chega no handler onde o fix mora. **Os testes do fix nunca
pegaram isso porque chamam a função do handler DIRETO** (`await _processConfirmation(texto, sessao,
...)`), pulando inteiramente a camada de classificação que roda no pipeline real.

**Solução:** quando um bot/pipeline conversacional tem MÚLTIPLAS camadas de classificação em
sequência (roteador de intent → classificador de estado pendente → handler do estado), um fix
dentro da camada mais interna (o handler) só é *alcançável de verdade* se TODAS as camadas
anteriores também souberem reconhecer o padrão novo como "deixa passar". Ao escrever um teste pra um
fix de handler, pelo menos UM teste tem que exercitar o PIPELINE INTEIRO (webhook → classificador →
handler), não só a função isolada — testes que chamam a função-alvo direto (`await
_handler(texto, ...)`) provam que o handler está certo, mas não provam que a mensagem CHEGA nele.
Um smoke/e2e ao vivo contra prod (ou um teste de caracterização do pipeline completo) é o que pega
esse tipo de regressão — testes unitários isolados por design não pegam.

**Ref:** Família Milionária, sessão 2026-08-07 — `handoff_detector.classificarMensagemPendente` +
`_isGenuineReply` em `familia-api/app/modules/whatsapp/handoff_detector.py`, vs. o fix de
`_detectDateCorrection` em `_processConfirmation` (commit `413d286`, 2026-07-24). Fix: novo
`is_date_correction()` em `correction_patterns.py` (módulo-folha compartilhado), ligado no
classificador. Achado por `execution/smoke_confirmando_ajuste_data.py` (script novo, injeta mensagem
real assinada no webhook de produção) — não pelos 47 testes unitários da 413d286, que datam de ANTES
desta descoberta e nunca detectaram o gap porque testam só o handler isolado.

## "Zerar um campo pra não sobrescrever" em API full-replace na verdade APAGA o campo {#zerar-campo-em-put-full-replace-apaga}

tags: pagar.me, pagarme, put, patch, full-replace, api rest, campo omitido, null, guarda de identidade, super_admin, multi-tenant, billing, payment gateway

**Sintoma:** um guard pra "não deixar sessão errada sobrescrever dado de outra entidade" — ex.
super_admin agindo em nome de um tenant, sessão com identidade diferente do alvo — foi desenhado
zerando os campos "perigosos" (`campo=None`) antes de mandar pra uma API de update. Parece
inofensivo (`None` = "não mexe"), mas o conselho/review acha CRITICAL: o campo correto do dado alvo
**sumiu** depois da chamada, não ficou como estava.

**Causa raiz:** duas coisas combinadas, cada uma sozinha inócua: (1) o endpoint de update da API
externa é `PUT` (ou equivalente) **full-replace**, não `PATCH` parcial — "campo ausente no corpo"
vira `null` do lado do servidor, não "mantém o valor anterior" (comportamento documentado, mas fácil
de assumir o oposto se você só olhou o `POST`/create); (2) o client HTTP local só inclui uma chave
no corpo **quando o valor é truthy** (`if campo: body["campo"] = campo` — padrão comum pra evitar
mandar `null` explícito sem querer). A combinação: `campo=None` → helper de corpo OMITE a chave →
API interpreta ausência como "apagar". O guard que devia SÓ evitar sobrescrever com dado errado
acaba apagando o dado certo — pior que o bug original (que trocava por errado, não deletava).

**Solução:** pra um guard de identidade contra API full-replace, **NUNCA** "zere campos e deixe a
chamada acontecer". As opções seguras são: (a) **pular a chamada inteira** quando a sessão não é
confiável pro alvo (mais simples, comprovadamente seguro — nada enviado, nada apagado; único
trade-off é que o campo que SERIA atualizado por essa chamada — ex. um documento novo — também não
propaga nesse caminho específico); (b) buscar o registro atual via `GET` primeiro e reenviar os
campos que já existem lá, só trocando o que precisa mudar (mais completo, mas depende de confirmar
o schema exato da resposta do `GET` — não assuma que espelha o corpo do `POST`/`PUT` sem checar a
doc ou testar empiricamente); (c) buscar o dado "correto" de outra fonte de verdade (ex. banco
próprio) — mais correto conceitualmente, mas abre pergunta de design maior (qual registro é "o
certo" se houver ambiguidade). Ao decidir entre elas, prefira a que não depende de reverse-engineer
um schema não verificado — o council desta sessão vetou a opção GET-first justamente por causa
disso, mesmo sendo "mais completa" em teoria.

**Ref:** tiatendo, sessão 2026-08-07 — `execution/billing/pagarmeClient.py` (`_customerBody()`,
`updateCustomer()`) + `execution/dashboard/routes/billingRoutes.py` (`saveCard()`). Achado num
review de marco (Cross-Claude): `updateCustomer()` mandava contato da sessão super_admin em vez do
tenant alvo. 1ª tentativa de fix (zerar `email`/`phone`) foi BLOQUEADA por DeepSeek (CRITICAL) na
review de spec — confirmado lendo `_customerBody()` (só inclui chave `if email: ...`) e a doc
oficial do Pagar.me v5 (`docs.pagar.me/reference/editar-cliente-1`, full-replace confirmado, sem
PATCH no v5). Fix final: pular a chamada inteira pra `super_admin`, commit `97cab71`. Specs:
`docs/superpowers/specs/2026-08-07-pagarme-customer-sync-retry-safety-design.md` (achado de API) e
`docs/superpowers/specs/2026-08-07-pagarme-update-customer-super-admin-identity-guard-design.md`
(o round 1 rejeitado + a correção).

---

## Campo novo no contrato JSON entre 2 serviços deployados separadamente fica ausente no frontend se o backend for pra produção primeiro {#contrato-novo-precisa-dos-dois-deploys-juntos}

tags: deploy sequenciado, contrato de api, campo novo, microservico, backend frontend dessincronia, optional chaining, docker service update, breaking change silencioso, feature invisivel

**Contexto:** feature que adiciona um campo novo na resposta JSON de um endpoint (`spendConfidence`),
consumido por uma tela que já lia outros campos do mesmo payload. Backend (`services/tracking`) e
frontend (`web`) são imagens Docker separadas, deployadas via `docker service update` uma de cada
vez, não atomicamente.

**Sintoma:** depois de deployar só o backend (`services/tracking`) com o campo novo, a tela em
produção não mostrava a feature nova — sem erro de console, sem 5xx, só ausência silenciosa.
Investigação inicial suspeitou de bug no cálculo do backend (o valor parecia "errado" por não
aparecer), até checar a network tab e ver que a API **já respondia corretamente** com o campo novo
preenchido — o problema era que o `web` ainda rodava a imagem de ANTES da feature, que nem sabia que
esse campo existia.

**Causa raiz:** dois serviços com um contrato JSON compartilhado, deployados de forma independente e
sequencial (não atômica). Deployar o produtor (backend) do campo novo sem deployar o consumidor
(frontend) na mesma janela deixa uma janela real, em produção, onde o campo existe na resposta mas
o código que deveria lê-lo ainda não existe no ar.

**Por que não quebrou:** o frontend já tinha sido escrito com acesso defensivo (`data.campoNovo?.x
?? 0`) por causa de um achado de code-review — não por antecipação deliberada desse cenário exato,
mas o efeito foi o mesmo: sem esse `?.`, o acesso direto (`data.campoNovo.x`) teria lançado
`TypeError` e quebrado a tela INTEIRA (não só escondido a feature nova) durante essa mesma janela de
dessincronia. A defesa vale mesmo quando "o deploy vai ser rápido" — a janela existe de qualquer
forma.

**Solução:**
1. Ao adicionar um campo novo a um contrato JSON consumido por outro serviço deployado
   separadamente, trate o acesso a esse campo no lado consumidor como **potencialmente ausente**
   (optional chaining + fallback), mesmo que o plano seja deployar os dois juntos — a ordem real de
   `docker service update` não é atômica entre dois `services:` diferentes.
2. Ao fazer o deploy de uma feature que toca contrato entre 2+ serviços, faça os dois `docker
   service update` na MESMA janela — não passe pra outra tarefa entre um e outro. Se notar que só um
   foi feito, o próximo passo é sempre completar o outro antes de considerar a feature no ar.
3. Ao investigar "a feature nova não aparece" em produção, confira a resposta REAL da network tab
   ANTES de suspeitar do cálculo do backend — se o campo já vem certo na resposta, o backend está
   certo e o problema é no consumidor (deploy desatualizado, cache, ou lógica de renderização), não
   na fonte do dado.

**Ref:** Paid Media Automation, sessão 2026-08-07 — feature "confiança do gasto" na tela HubSpot
(`docs/superpowers/plans/2026-08-07-hubspot-spend-confidence-plan.md`). Campo `spendConfidence`
adicionado em `services/tracking/app/modules/crm/hubspot_campaign_performance.py`; consumido em
`web/src/app/dashboard/clients/[id]/(shell)/leads/hubspot-performance/page.tsx` com
`data.spendConfidence?.activeCampaignsNoSpend ?? 0` (achado de code-review da Task 4, commit
`70995670`). Deploy do `tracking`+`tracking-worker` (`spendconf-02c3d357`) feito antes do `web` —
smoke contra D4U (cliente real com 56 campanhas ativas sem gasto) mostrou API correta (`GET
.../crm/hubspot/campaign-performance` já retornava `spendConfidence` certo) mas banner ausente na
tela; corrigido buildando e deployando `web:spendconf-02c3d357` na sequência. Lição registrada
também no `docker-compose.swarm.yml` do projeto, no comentário do pin.

---

## Chrome DevTools MCP recusa `new_page`/`navigate_page` com "browser already running" mesmo quando o próprio MCP perdeu o rastro do processo {#chrome-devtools-mcp-processo-orfao-trava-perfil}

tags: chrome-devtools mcp, browser already in use, userDataDir, processo orfao, sessao longa, playwright, mcp desconectado, chrome.exe travado

**Sintoma:** numa sessão de agente muito longa (muitas horas, dezenas de chamadas de browser MCP),
uma chamada a `new_page`/`navigate_page` do Chrome DevTools MCP falha com `Error: the browser is
already running for <userDataDir>, use --isolated to run multiple instances`. `list_pages` falha com
o mesmo erro. Não é concorrência com outra sessão/humano (ver
[Browser MCP sessão ao vivo do operador](#browser-mcp-sessao-ao-vivo-operador) pra esse caso
diferente) — é a MESMA sessão de agente que já tinha usado o browser MCP com sucesso antes.

**Causa raiz:** o processo `chrome.exe` real (mais os processos filhos: gpu-process, renderer,
utility, crashpad-handler) sobreviveu no SO enquanto o servidor MCP, por algum motivo (idle timeout,
reciclagem interna, etc.), perdeu o handle/rastro dele. O lock do `userDataDir` (perfil do Chrome)
continua ativo no processo órfão, então quando o MCP tenta abrir um novo browser apontando pro mesmo
perfil, o Chrome real recusa (é o comportamento normal do Chrome pra 2 instâncias no mesmo perfil,
não um bug do MCP) — mas o MCP não tem mais o processo pra reconectar.

**Solução:**
1. Identifique o processo `chrome.exe` PAI (não os filhos) que referencia o `userDataDir` do MCP:
   `Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like
   "*<nome-do-perfil-mcp>*" }` (Windows) — o processo pai tem `--remote-debugging-pipe` na linha de
   comando; os filhos (`--type=gpu-process`, `--type=renderer`, etc.) são descartáveis e morrem em
   cascata quando o pai morre.
2. Mate o processo pai: `Stop-Process -Id <pid> -Force`. Não precisa matar os filhos manualmente.
3. Repita a chamada MCP (`new_page`/`navigate_page`) — o servidor detecta que precisa reconectar e
   sobe um browser novo. A resposta costuma incluir uma nota tipo "the browser was restarted or
   reconnected since the last call" confirmando a reconexão.
4. Isso é seguro de fazer mesmo achando que "pode ser sessão de outro processo" — SE o `userDataDir`
   na linha de comando bate com o perfil dedicado do MCP (não o perfil pessoal do Chrome do
   operador), matar esse processo específico não afeta nada fora da automação do agente.

**Ref:** Paid Media Automation, sessão 2026-08-07 (cont.158, sessão de várias horas com dezenas de
chamadas de Playwright/Chrome DevTools MCP pra smoke tests). `new_page` falhou com "browser already
running for C:\Users\...\chrome-devtools-mcp\chrome-profile"; `Get-CimInstance` achou o processo pai
(PID com `--remote-debugging-pipe`) mais ~12 processos filhos (gpu, renderer×5, utility×3, audio,
video-capture, crashpad-handler). `Stop-Process -Id <pai> -Force` seguido de `new_page` reconectou
com sucesso, sem precisar reiniciar a sessão inteira.

---

## Última página do path terminar em dígito é assinatura estrutural de "página de detalhe de catálogo" — genérico, não depende do CMS {#url-trailing-digit-catalog-detail-page}

tags: url pattern, deteccao generica, pagina de produto, pagina de imovel, catalog detail page,
agrupar paginas, page-flow, heuristica sem hardcode de dominio, praedium, wordpress, shopify

**Contexto:** grafo/lista de páginas navegadas por sessão (Fluxo de Páginas) tinha uma "cauda longa"
de páginas de ficha-de-produto/imóvel poluindo a visualização (274 páginas distintas, a maioria com
1-2 sessões cada). Pedido explícito do operador: "não hardcode pro CMS específico (Praedium) — tem
que identificar sozinho". Confundir isso com o problema geral de "cauda longa de baixo tráfego" (que
já tinha solução própria, agrupamento por peso) seria perder a informação de que essas páginas são
TODAS da MESMA categoria estrutural (fichas de um catálogo), não só "baixo tráfego disperso".

**Causa raiz / por que dá pra generalizar:** qualquer catálogo paginado (CMS de imóveis, e-commerce,
diretório) cedo ou tarde precisa de um identificador único por item na URL — e o jeito mais comum de
resolver isso, INDEPENDENTE da stack (WordPress, Shopify, Praedium, Next.js customizado), é sufixar o
slug com um ID numérico (`...-id-2001`, `.../product/123`, `.../p2001`). Páginas de LISTAGEM/filtro do
mesmo site, em contraste, quase sempre terminam em palavra (`3-quartos`, `ate-750-mil`, `mais-vendidos`)
porque são compostas de filtros humanos, não de uma chave primária de banco.

**Solução:** heurística estrutural de uma linha, sem tabela de exceção por CMS:

```ts
function isCatalogDetailPage(label: string): boolean {
  return /\d+\/?$/.test(label); // último segmento do path termina em dígito
}
```

Valide contra o dado real do tenant antes de confiar: agrupe por primeiro segmento do path entre os
matches — se 100% caem sob o MESMO segmento raiz (ex. todos sob `/imovel/...`), é sinal forte de que a
heurística achou o padrão certo, não ruído. Rode também o caminho negativo: liste os labels que TÊM
algum dígito mas NÃO batem na regex (ex. `ate-750-mil`) — se nenhum desses vira falso-positivo, a
heurística está discriminando path-de-filtro vs path-de-registro corretamente.

**Ref:** Paid Media Automation, sessão 2026-08-07 (cont.158). Validado contra 274 páginas reais da
Imobiliária Uni: 177 matches, 100% sob `/imovel/...`, zero falso-positivo nas páginas de filtro
(`web/src/app/dev-preview/page-flow/page.tsx`, `isCatalogDetailPage`).

---

## Conversa longa com muitos screenshots: imagem nova passa a ser rejeitada mesmo pequena — é acúmulo, não tamanho do arquivo {#conversa-longa-limite-imagem-cumulativo}

tags: image dimensions exceed max allowed size, many-image requests, 2000 pixels, screenshot rejeitado,
chrome devtools mcp screenshot, ocr windows fallback, winrt powershell falha, conversa longa limite

**Sintoma:** numa conversa já longa (dezenas de screenshots tirados via browser MCP ao longo da
sessão), o usuário tenta colar um print no chat e a API rejeita com "At least one of the image
dimensions exceed max allowed size for many-image requests: 2000 pixels" — mesmo pra imagens
pequenas (ex. 1091×282, bem abaixo de 2000px em qualquer lado). Redimensionar o arquivo NÃO resolve:
o mesmo arquivo, lido sozinho (`Read` isolado, sem nenhuma outra imagem na chamada), falha do mesmo
jeito, com um `request_id` novo a cada tentativa — não é reuso de um erro em cache.

**Causa raiz:** o limite não é por-arquivo, é o ORÇAMENTO TOTAL de pixels/imagens da requisição — que
inclui o HISTÓRICO da conversa inteira sendo reenviado ao modelo, não só a imagem nova. Uma conversa
que já acumulou muitas capturas de tela (comum em sessões de smoke test / co-design ao vivo via
Playwright/Chrome DevTools MCP) satura esse orçamento; a partir daí, QUALQUER imagem nova — não
importa o tamanho dela sozinha — estoura o total.

**O que NÃO funciona (testado e descartado nesta sessão):**
1. Redimensionar/cortar a imagem antes de enviar — o gargalo é cumulativo, não individual.
2. OCR local via `Windows.Media.Ocr` (WinRT) rodado em `pwsh` (PowerShell 7/Core) — falha com
   `Operation is not supported on this platform (0x80131539)` ao tentar refletir
   `IAsyncOperation<T>.AsTask` via `System.WindowsRuntimeSystemExtensions`: a projeção WinRT usada
   pelo type-accelerator `[Tipo, Assembly, ContentType=WindowsRuntime]` não é suportada no CLR do
   PowerShell 7/.NET moderno, só no Windows PowerShell 5.1 clássico.
3. Chamar `powershell.exe` (5.1 legado) heredoc'ado de DENTRO do Bash (Git-Bash/MSYS) — o script passa
   por 2 camadas de escaping (Bash → powershell.exe) e corrompe encoding/backtick, o mesmo erro de
   "matriz nula" aparece mesmo rodando no runtime correto.

**Solução que funciona:** peça o dado em TEXTO em vez de imagem (transcrição manual do que a pessoa
está vendo) — sem gargalo nenhum. Se a imagem for indispensável, ela precisa ser lida **cedo na
conversa**, antes do orçamento saturar com outras capturas — ou numa conversa nova/`/clear`.

**Ref:** Paid Media Automation, sessão 2026-08-07 (cont.158). 3 arquivos salvos em disco
(`C:\Users\...\Lixo\aaaa\*.png`, 1085-1480px de largura) falharam ao ler depois de ~20 screenshots já
tirados via chrome-devtools MCP na mesma conversa; tentativa de OCR local (WinRT via pwsh e via
Bash→powershell.exe) falhou nos dois runtimes por motivos diferentes.

---

## Playwright `request.newContext({baseURL})` + rota com `/` no início APAGA o path inteiro do baseURL (silencioso, 404 em tudo) {#playwright-baseurl-path-absoluto-apaga}

tags: playwright apirequestcontext, baseurl, new URL path base, whatwg url resolution, leading
slash relative path, ctx.get 404, teardown nunca limpou, global-teardown silently broken,
request.newContext baseURL bug, url absoluta vs relativa

**Sintoma:** um `APIRequestContext` criado com `request.newContext({ baseURL: 'https://api.exemplo.com/api/v1' })`
(sem `/` no fim) faz `ctx.get('/recurso/')` (rota COM `/` no início) e recebe **404** — mesmo com
token válido, mesmo o endpoint existindo de verdade (confirmado batendo a MESMA URL com `curl`
manualmente: 200 OK). O erro não aparece como falha de auth (401/403) — é um 404 limpo, `{"detail":
"Not Found"}`, porque a requisição de fato chegou no servidor, só que num path errado.

**Causa raiz:** Playwright resolve `baseURL` + rota via `new URL(givenURL, baseURL)`
(`playwright-core/lib/utils/isomorphic/urlMatch.js::resolveBaseURL`) — semântica WHATWG padrão do
construtor `URL`. Quando `givenURL` começa com `/` (path absoluto), o resultado **descarta o path
inteiro do `baseURL`**, mantendo só o origin (protocolo+host+porta):
```js
new URL('/metas/', 'https://api.exemplo.com/api/v1')  // -> 'https://api.exemplo.com/metas/'  (sem /api/v1!)
new URL('metas/',  'https://api.exemplo.com/api/v1/')  // -> 'https://api.exemplo.com/api/v1/metas/'  (correto)
```
Isso é comportamento **documentado do próprio `URL()` do JS/WHATWG** — não é bug do Playwright, mas
a combinação "`baseURL` sem `/` final" + "rota com `/` inicial" (a forma mais intuitiva de escrever
as duas coisas) produz esse resultado contra-intuitivo silenciosamente. Não falha no request feito
manualmente com string concatenada (`${API_BASE}${rota}`) — só quando se depende do parâmetro
`baseURL` do `newContext`/`APIRequestContext` pra fazer a junção.

**Por que é fácil passar 3 semanas sem notar:** se o código que usa esse `ctx` for justamente uma
rede de segurança/teardown que só roda condicionalmente (ex.: só depois de uma suíte autenticada
rodar de verdade) e o "caminho feliz" raramente é exercitado (porque outra dependência — ex. um
token manual — está quebrada há tempos), o 404 nunca aparece nos logs de ninguém. Confirmado numa
sessão real: um `globalTeardown` de e2e escrito assim **nunca limpou um único registro** desde que
foi escrito, porque a suíte autenticada ficou travada em outro problema (token manual) por semanas
— quando o outro problema foi resolvido e o teardown finalmente rodou de verdade, todos os 6
recursos que ele tentava listar vieram 404.

**Solução:** não confie no `baseURL` do context pra rotas com `/` no início. Duas opções:
1. Sempre montar a URL absoluta na mão (`${API_BASE}${rota}`, concatenação de string simples) e
   não passar `baseURL` pro `newContext` — mais explícito, impossível de resolver errado.
2. Se quiser manter `baseURL`, garanta que ele termine em `/` E que toda rota NÃO comece em `/`
   (`baseURL: '.../api/v1/'` + `ctx.get('metas/')`) — mais frágil (fácil esquecer o `/` em um dos
   dois lados de novo no futuro), prefira a opção 1.

Diagnóstico rápido pra confirmar que é isso: reproduza fora do Playwright com `new URL(rota, baseURL).href`
num REPL de Node — se o resultado não contém o path do `baseURL`, é essa causa.

**Ref:** Família Milionária, sessão 2026-08-07 — implementação da conta E2E sintética
(`docs/superpowers/plans/2026-08-07-e2e-synthetic-account.md`, Task 7). `global-teardown.ts`
(rede de segurança que apaga dado `[E2E]` de produção pós-e2e) 404ava em TODAS as 6 listagens;
confirmado lendo o source de `playwright-core` + repro isolado em Node fora do test runner. Fix:
`familia-frontend/tests/e2e/global-teardown.ts` (commit `8105db1`), URLs absolutas.

---

## `storageState` cacheado de sessão OTP fica inválido entre rodadas separadas: refresh reativo dentro do browser nunca é gravado de volta em disco {#storagestate-refresh-reativo-nao-persiste}

tags: playwright storageState cache, refresh token rotation single-use, auth.setup cache valido,
otp login cache 30 dias, invalid refresh 401, sessao expira entre invocacoes separadas, e2e
automated login token rotation lost

**Sintoma:** um `auth.setup.ts` (ou script equivalente) faz login real (OTP, magic-link, etc.),
salva `access_token`+`refresh_token` num `storageState` em disco, e um sidecar de metadados marca
"válido por ~30 dias" (TTL do refresh). Lógica simples: "se o cache ainda está dentro da janela,
pula o login". **Funciona na primeira invocação, quebra silenciosamente em invocações
posteriores** — uma spec/teste que roda depois volta pra tela de login, com erro
`{"detail":"invalid refresh"}` ao tentar renovar, mesmo dentro da janela de 30 dias.

**Causa raiz:** o access token dura pouco (ex. 15min). Assim que expira, o PRÓPRIO app/frontend
(interceptor de 401, refresh reativo automático) troca o par de tokens sozinho pra manter a UX —
isso é o comportamento CORRETO e desejado em produção. Mas o refresh é **single-use com rotação**:
a resposta de `/token/refresh` vem com um `refresh_token` NOVO que invalida o antigo. Esse refresh
automático acontece DENTRO do browser context daquele teste específico — só existe no `localStorage`
daquela sessão efêmera, nunca é regravado no arquivo de `storageState` em disco (só quem escreve
esse arquivo é o script de setup, que só roda 1x por invocação). A PRÓXIMA invocação (novo processo,
novo browser context) carrega o arquivo ANTIGO, com o `refresh_token` que JÁ FOI consumido/rotacionado
pela rodada anterior → `POST /refresh` rejeita com 401 `invalid refresh` → sessão morre.

**Como confirmar que é isso:** pegue o `refresh_token` gravado no `storageState` em disco e teste
direto contra o endpoint de refresh (`curl -X POST .../token/refresh -d '{"refresh_token":"..."}'`)
— se vier `invalid refresh`/401, o token já foi consumido em algum momento depois da última vez que
o arquivo foi escrito.

**Solução:** não trate "cache válido" como "pula tudo". Trate como "renova PROATIVAMENTE via
`/token/refresh` (rota SEM rate limit, diferente do endpoint de login/OTP que costuma ter) e
regrava o `storageState`+metadados a cada invocação" — só cai pro login completo (OTP/magic-link)
se essa renovação em si falhar (aí sim o refresh morreu de verdade, não só rotacionou). Isso garante
que o arquivo em disco nunca fica desatualizado em relação ao último refresh que aconteceu, seja
ele proativo (nosso) ou reativo (do próprio app numa rodada anterior). Ressalva: isso NÃO cobre
rotação que acontece NO MEIO de uma mesma rodada longa com múltiplas specs sequenciais (>15min de
ponta a ponta) — cada spec nessa mesma invocação ainda carrega o storageState ORIGINAL da memória/
disco do início da rodada; se uma spec do meio disparar o refresh reativo, specs seguintes DA MESMA
rodada podem herdar o token já rotacionado. Mitigação parcial: manter a rodada mais curta que a
validade do access token, ou (não implementado ainda) regravar o storageState após cada spec.

**Ref:** Família Milionária, sessão 2026-08-07 — conta E2E sintética
(`docs/superpowers/plans/2026-08-07-e2e-synthetic-account.md`, Task 7). Confirmado testando o `rt`
do disco direto contra `/token/refresh` (`invalid refresh`). Fix em
`familia-frontend/tests/e2e/auth.setup.ts` (commit `8105db1`): cache válido agora sempre renova
antes de reusar, em vez de só pular.
