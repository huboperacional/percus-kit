## `rm -rf` de "limpeza" no dir de deploy do VPS apaga segredos reais nunca commitados {#rm-rf-deploy-dir-apaga-env}

`tags: rm -rf, vps, deploy, env, secrets, deploy/.env, git archive, tar, docker service inspect, backup, gitignore, stack.yml, disaster recovery`

**Contexto.** Perseguindo o achado acima ([docker-context-stale-tree-recorrencia](docker-context-stale-tree-recorrencia.md)), rodei um `rm -rf` "de limpeza total" no diretório de deploy do VPS antes de re-extrair via `tar` — pra garantir que não sobrasse NENHUMA árvore obsoleta, não só a que eu já tinha identificado.

**O que quebrou.** `deploy/.env` (segredos reais — chave Stripe LIVE, senha de admin, token de API, session secret) é **gitignored de propósito**: vive só no host, nunca no repo (é doc explícita do `stack.yml` do projeto). `rm -rf` numa lista que incluiu a pasta `deploy/` apagou esse arquivo; o `tar xzf` do `git archive` **não o repõe** (ele só carrega o que está commitado). Build seguinte quebrou com "`.env`: No such file or directory".

**Por que não foi mais grave.** O serviço Docker Swarm **já rodando** não foi afetado — `docker stack deploy` assa o `env_file:` na spec do serviço NO MOMENTO do deploy; o container sobrevive à perda do arquivo fonte (mesmo mecanismo do gap de rotação de segredo já documentado em `reference_vps_secret_rotation_gap_and_envfile_reload`). Zero downtime.

**Recuperação.** `docker service inspect <servico> --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}'` no serviço rodando devolve o env INTEIRO já assado, inclusive os valores que vieram do `.env` apagado — reconstrua o arquivo linha por linha a partir dessa saída (`chmod 600`/dono certo pra igualar o original). Só funciona enquanto o serviço antigo continuar de pé — se ele caísse ANTES da recuperação, os segredos LIVE estariam perdidos sem backup (nunca existiu cópia fora do host).

**Regra prática.** Num diretório de deploy de VPS, NUNCA `rm -rf` uma lista ampla "pra garantir" — esses diretórios acumulam arquivo real (segredos, uploads, volumes) que não está em nenhum git. Antes de limpar: `ls -la` primeiro, separar mentalmente "o que o `git archive`/deploy repõe" (código) de "o que só existe ali" (`.env`, dados de volume) — remover só o item específico já identificado como lixo, nunca uma lista ampla.

**Ref:** 2026-08-11, ads4agencies-site, sessão scraper-prospeccao. R23. Memória do projeto: `reference_vps_deploy_dir_rm_rf_deletes_untracked_env`.
