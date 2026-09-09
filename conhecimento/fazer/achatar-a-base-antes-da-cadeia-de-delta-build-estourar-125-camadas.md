## Achatar a base antes da cadeia de delta build estourar 125 camadas {#achatar-a-base-antes-da-cadeia-de-delta-build-estourar-125-camadas}

`tags: docker, deploy, delta build, camadas, max depth exceeded, flatten, healthcheck`

> Irmão de [[docker-build-em-cima-de-imagem-delta-bate-max-depth]], que descreve o SINTOMA e o
> contorno (rodar num container efêmero em vez de empilhar camada). Este aqui é o passo
> seguinte: o dia em que o contorno não basta porque a **própria cadeia de deploy** chegou no
> limite. Se você está lendo aquele, leia este antes do próximo deploy.

**Quando:** projetos que fazem deploy por DELTA (`FROM <versão anterior>` + `COPY` do que mudou).
Cada deploy soma **exatamente uma camada**, então o limite chega por acúmulo silencioso — não há
sinal nenhum até a véspera.

**Meça ANTES de construir, todo deploy:**

```bash
docker image inspect <imagem-base> --format '{{len .RootFS.Layers}}'
```

O teto do Docker é **125**. Medido num caso real: a base estava em **124** — o delta daquele
deploy passaria raspando e o **seguinte** falharia. O sintoma quando estoura é
`docker: Error response from daemon: max depth exceeded`, e ele aparece **primeiro em builds
auxiliares** (um testrunner com pytest sobre a imagem promovida bateu nele enquanto o delta de
deploy ainda cabia).

**Acima de ~115, ache a base antes de gastar a camada:**

1. **Aborte se a imagem declarar `VOLUME`** (`.Config.Volumes != null`) — o `export` não leva o
   conteúdo desses caminhos.
2. `docker create` → `docker export` → `docker import`. Isso preserva o filesystem **byte a byte**:
   nenhuma dependência é reinstalada.
   ⚠️ **Um rebuild completo do Dockerfile NÃO é substituto** — ele re-resolve o gerenciador de
   pacotes e pode trocar versões que ninguém autorizou, no meio de uma janela de produção.
3. `docker import` **perde toda a metadata**. Re-aplique explicitamente com `--change`: `WORKDIR`,
   cada `ENV`, `EXPOSE`, `HEALTHCHECK` e `CMD` — e confira no `image inspect` depois. O
   `HEALTHCHECK` é o que o orquestrador usa pra decidir se o rollout deu certo; sem ele o deploy
   "converge" sem nunca ter sido verificado.
4. **Escreva no artefato de retomada que a imagem `-flat` é base de BUILD, não degrau de
   rollback.** Ela é a mesma versão, achatada; tratá-la como versão é o erro seguinte.

🪤 **Corolário:** planos de deploy costumam trazer um teto de TAMANHO pro pacote do delta ("pare se
passar de ~20 MB"). Esse número apodrece — no caso medido a árvore legítima já pesava 40 MB, quase
toda em assets versionados. O teto queria pegar **lixo acidental**; troque tamanho por checagem de
CONTEÚDO (`grep` no `tar tf` por `__pycache__`, `.pyc`, `.log`, `.env`, `node_modules`, `.venv`),
que responde a pergunta certa e não apodrece.
