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
