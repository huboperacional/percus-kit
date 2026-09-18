## Inventário de rotas FastAPI tem de descer no Mount e ler a guarda no corpo {#inventario-de-rotas-fastapi-tem-de-descer-no-mount-e-ler-a-guarda-no-corpo}

`tags: fastapi, rbac, auditoria de autorizacao, inventario de rotas, Mount, sub-aplicacao, dependant, Depends, requireAbility, include_router, APIRouter, checagem no corpo, afericao, positivo conhecido, verificacao que volta vazia`

**Sintoma:** uma auditoria de autorização ("toda rota mutante tem a guarda certa?") devolve um número
limpo e pequeno — e está errada nas duas direções. Medido no tIAtendo em 18/09 (`§00ar`): a 1ª versão
da sonda achou **46 rotas e nenhuma do painel**; o painel inteiro tinha 326.

**Causa — quatro lugares onde a guarda mora, e três deles escapam de busca textual:**

1. **Sub-aplicação montada.** `app.mount("/admin", dashboardApp)` não aparece em `app.routes` como
   `APIRoute`: vira um `Mount` com a sua própria lista. Quem itera só `APIRoute` perde tudo o que está
   montado — e o resultado parece plausível, porque as rotas públicas do app de fora aparecem.
2. **Guarda em camadas.** A dependência pode estar no `include_router(..., dependencies=[...])`, no
   `APIRouter(dependencies=[...])` ou na assinatura da rota. `grep` numa camada perde as outras. A
   árvore `route.dependant` é o que o FastAPI de fato resolve — é ali que se lê.
3. **Checagem à mão no corpo.** `if session.get("role") != "super_admin": raise HTTPException(403)`
   não é dependência nenhuma. Sem AST do corpo, a rota aparece como "só login" e o inventário
   **superestima** o buraco.
4. 🔴 **Checagem em FUNÇÃO AUXILIAR chamada no corpo** (`_checkTenantAccess(...)`,
   `_requireSuperAdmin(...)`, nomes locais de cada módulo). **Esta é a que a sonda do tIAtendo
   perdeu, e o erro foi de quem escreveu este verbete:** ela procurava uma LISTA FIXA de nomes de
   guarda no corpo e só nas rotas "só login". Resultado medido por outra sessão (`tiatendo-36`,
   18/09), relendo rota a rota: "15 expostas + 28 latentes" eram, de verdade, **14 expostas, 8
   latentes e 21 protegidas à mão**. O inventário superestimou por 20 rotas — e o desenho que saiu
   dele quase devolveu a um papel uma permissão que um ADR tinha tirado de propósito.
   **Regra:** procure checagem no corpo em TODAS as rotas, não só nas que parecem abertas, e siga
   as chamadas do corpo até a função que levanta 403 (ou leia rota a rota as que sobrarem). Lista
   fixa de nomes envelhece no primeiro auxiliar novo.

**Solução:** importar o app real (sem subir servidor, sem banco), descer recursivamente em `Mount`
prefixando o caminho, ler as guardas da árvore `dependant` (a fábrica `requireAbility(X)` devolve uma
função interna — o valor de `X` sai do `__closure__`) e, por AST, as chamadas e comparações de papel
no corpo. Várias `requireAbility` numa rota valem **juntas (E)**: cada uma é uma dependência própria
que levanta 403 sozinha.

**Como provar que o inventário não está vazio:** afira contra rotas que você SABE que existem
(no caso: `/api/lgpd`, `/api/faq`, `/settings/hours`). Foi essa aferição que pegou as duas falhas —
sem ela, "46 rotas, nenhum buraco" teria virado conclusão. A cerca de regressão que nascer dessa
auditoria deve **se aferir sozinha** contra os mesmos positivos e falhar se não os achar.

**Limite:** classificar por método HTTP deixa de fora `GET` que muta estado (callback de OAuth,
invalidação de cache). É outra classe; declare-a em vez de fingir que o inventário a cobre.
