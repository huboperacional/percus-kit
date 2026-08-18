## Preencher os gatilhos S/N no dia 1 de projeto novo {#gatilhos-dia-1}

`tags: gatilhos, discovery, multi-tenant, dado regulado, LGPD, persistencia, endpoint publico, CLAUDE.md, greenfield, MDS`

**Quando:** passo 2 de `comandos/COMANDO_PROJETO_NOVO.md`, ao gerar `CLAUDE.md` a partir do
template — antes de qualquer código.

**Passos:**
1. Responda as 4 linhas da mini-tabela "Gatilhos de projeto" em `CLAUDE.md` (herdada de
   `templates/CLAUDE.template.md`): persistência? multi-tenant? dado regulado (LGPD/HIPAA/PCI)?
   endpoint público?
2. Gatilho que não dispara **exige** "N/A, motivo em 1 linha" — nunca deixe em branco.
3. Use `v2/loops/grilling.md` (camada "Gatilhos estruturais", `v2/referencia/discovery-camadas.md`)
   se a resposta não for óbvia de cara.

**Armadilhas:** decidir de cabeça sem escrever — o valor inteiro do gatilho é a decisão **datada**,
não a decisão em si. Caso real que ancora o custo de mudar tenancy tarde (não de "decisão
silenciosa" — a decisão original foi deliberada, o caro foi mudar depois de já estar em
produção): Micro Investors precisou provisionar um 2º tenant por duplicação física de banco,
meses depois do produto já estar rodando single-tenant (ver
[tenant-novo-cadeia-migrations-quebrada](../resolver/tenant-novo-cadeia-migrations-quebrada.md)). Não adicione gatilho novo à tabela
por especulação — só depois de retrabalho comprovado uma vez.

**Ref:** `06_CONSELHO_PERCUS.md` seção "Mapeamento MDS ↔ Percus".
