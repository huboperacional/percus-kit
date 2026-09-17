## Migration que o código consulta no boot tem de subir ANTES do container, não depois {#migration-que-o-boot-consulta-tem-de-subir-antes-do-container}

tags: deploy, alembic, migration, scheduler, fail-open, ordem

**Sintoma.** Você deploya um conserto que depende de uma tabela nova, o deploy termina com sucesso,
e o defeito que você acabou de consertar **acontece mais uma vez** logo depois — sem erro visível,
só um `warning` no log.

**A ordem que causa isso.** O script de deploy da casa (`execution/deploy_v2.py`) faz: sincroniza
arquivos → constrói a imagem → **atualiza o serviço** → espera health → **roda `alembic upgrade`**.
A migration é o **passo 7 de 7**. Ou seja, existe uma janela de dezenas de segundos em que o código
NOVO já está rodando e a tabela NOVA ainda não existe.

**Por que a janela morde.** Se o código novo consulta a tabela **no boot** — scheduler que dispara um
tick no startup, cache que se aquece, job de reconciliação — ele vai bater na tabela ausente dentro
da janela. E se esse caminho for **fail-open** (ver
[[dois-automatos-que-sempre-respondem-formam-loop]]), a exceção é engolida e o comportamento volta a
ser o **pré-conserto**, mascarado por um log. Medido na Família Milionária em 2026-09-17: o claim
durável do alerta de trial cairia no `except`, devolveria "pode avisar", e o operador receberia
exatamente o alerta repetido que o conserto elimina.

**O conserto: aplique a migration antes, no container que já roda.**

```bash
scp <migration>.py root@<host>:/tmp/
docker cp /tmp/<migration>.py <container>:/app/alembic/versions/
docker exec <container> alembic upgrade head
```

O container antigo não conhece a tabela, então criá-la é inofensivo para ele; e quando o código novo
sobe, a tabela já está lá. Depois, o passo de migration do próprio deploy vira no-op.

**Como saber se o seu caso é desses.** Pergunte: *algum código que a migration habilita roda antes de
alguém chamar um endpoint?* Se a resposta for sim (scheduler, `lifespan`, worker), a ordem importa.
Se a tabela só é tocada em request, a janela é inofensiva e o deploy padrão basta.

⚠️ **Verifique o resultado no banco, não no log do deploy**: `SELECT version_num FROM alembic_version`
e a existência da tabela. "Deploy complete" já mentiu antes nesta casa
(ver [[deploy-quick-pula-scp-inteiro-nao-so-arquivo-novo]]).
