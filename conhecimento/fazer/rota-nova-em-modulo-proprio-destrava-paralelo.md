## Rota nova nasce em módulo próprio, e é isso que torna as frentes paralelizáveis {#rota-nova-em-modulo-proprio-destrava-paralelo}

`tags: paralelismo, frentes, colisao de arquivo, router, fastapi, apirouter, schemas, zona de arquivo, decompor, monolito de rotas, include_router`

**Quando:** várias pendências do mesmo marco precisam **adicionar rotas HTTP**, e o plano paralelo
morre porque todas querem o mesmo arquivo de rotas (o típico `router.py` de 700+ linhas) e o mesmo
`schemas.py`.

**A leitura errada é declarar "essas frentes colidem, então vão em série".** A colisão não é do
trabalho, é do **layout do arquivo** — e layout se muda.

**Passos:**
1. **Meça a colisão antes de aceitá-la.** Liste, por pendência, os arquivos que ela toca. Se o
   choque é só o arquivo de rotas e o de schemas, siga.
2. **Procure o precedente no próprio repo.** Quase sempre já existe um módulo de rotas separado
   (nasceu de outra feature) — no caso de referência, `pj/minhas_empresas.py` com `APIRouter()`
   próprio, **schemas Pydantic declarados dentro do arquivo**, e uma linha de `include_router` no
   `main.py`. Achar o precedente vale mais que propor o padrão: ele já passou por review.
3. **Cada frente nova cria seu módulo** — router e schemas dentro. O único arquivo compartilhado
   vira **uma linha** de registro no `main.py`, que é append trivial e mergeia sem conflito real.
4. **Declare a zona no prompt de cada frente**, incluindo o que ela **NÃO** pode tocar — em
   particular "❌ o `router.py` antigo" e "❌ o `schemas.py` compartilhado". Sem isso a frente
   B escreve no arquivo velho por hábito e o paralelismo morre em silêncio.
5. **A frente que mexe no arquivo antigo é uma só.** Quem já tem irmãos lá (ex.: a rota de
   Movimento, ao lado de baixa e estorno) fica; as demais saem para módulos novos.

**Armadilhas:**
- ⚠️ **Coesão ainda manda.** Não estilhace por estilhaçar: rota que é irmã óbvia de outras (mesmo
  agregado, mesmo caso de uso) fica junto. O critério é "esta frente pode ser escrita sem ler o
  resto do arquivo?".
- ⚠️ **Lógica pronta não se duplica.** No caso de referência, `pj/recorrencia.py` já tinha a
  materialização com 36 testes e **nenhum router**. A frente nova **importa** e expõe; não
  reimplementa nem move.
- ⚠️ **O registro no `main.py` é ordem de leitura**, não só linha: rota mais específica antes da
  genérica quando houver sobreposição de path.

**Relacionado:** [Decompor trabalho grande em frentes](decompor-frentes.md)

**Ref:** Empresa Milionária, 2026-08-18 — M1-6, M1-5, M1-2 e M1-7 disputavam `pj/router.py` (734
linhas) e `pj/schemas.py`; o padrão de `pj/minhas_empresas.py` liberou duas frentes simultâneas.
