## `if lista:` não é o mesmo teste que "algo na lista importa" — e as duas coincidências que escondem a diferença {#gate-por-presenca-de-lista-nao-e-gate-por-categoria-do-conteudo}

`tags: gate por presenca, categoria do conteudo, coincidencia esconde bug, dois casos reais nao provam generalidade, cross-provider convergiu na mesma linha, semeadura condicional, sabotagem nos dois sentidos`

**Contexto:** uma feature nova (semeadura de feriados nacionais ao aplicar um template de nicho,
Empresa Milionária, 2026-09-03) decidia SE devia rodar um efeito colateral (semear
`dias_nao_uteis`) checando `if template.get("etapas"):` — "este template tem alguma etapa
cadastrada?". A intenção real, escrita no próprio comentário do código, era outra: "só quem tem
etapa que **disputa capacidade** precisa de calendário". Para os DOIS templates reais do
repositório a checagem por presença e a checagem por categoria davam a mesma resposta (um tinha
zero etapas; o outro só tinha etapas de produção) — a coincidência escondeu que a condição escrita
não era a condição pretendida.

**O defeito, por extenso:** `CategoriaEtapa` tem três valores — `PRODUCAO`, `INSTALACAO`,
`POS_ENTREGA` — e o próprio modelo já documentava que `POS_ENTREGA` "não disputa capacidade de
ninguém". Um template hipotético só com etapas de pós-entrega (ex.: um nicho de serviço que só
rastreia "avaliação enviada") teria `etapas` não-vazio, passaria no `if template.get("etapas")`, e
semearia calendário nacional para uma empresa que nunca vai consultar `dias_nao_uteis` — cadastro
morto que ninguém pediu, sem sintoma visível até alguém abrir a tabela e perguntar "por que isto
está aqui".

**Como foi achado:** DUAS sessões Claude independentes, rodando `percus-review-auto.ps1` (review
cross-provider por `git diff HEAD`, não `--cached` — numa árvore compartilhada isso mistura
diffs de sessões diferentes) para commitar OUTRA coisa, bateram na MESMA linha do código ainda não
commitado e reportaram o MESMO risco na mesma noite. Duas vozes convergindo na mesma linha, sem
combinar entre si, é o sinal mais forte que este canon reconhece para "isto é real, não ruído do
modelo" — mais forte até que um 2/3 de conselho formal, porque veio de duas RODADAS diferentes de
revisão, não de três providers na mesma rodada.

**A correção mais estreita também estava errada, e só um segundo teste pegou isso:** a primeira
sugestão (de um dos providers) foi trocar para `if categoria == PRODUCAO`. Isso teria corrigido o
caso de pós-entrega, mas quebrado um terceiro caso nunca cogitado: um template só com etapas de
`INSTALACAO` (que disputa capacidade da EQUIPE, não de uma pessoa — mas disputa) deixaria de
semear calendário, contradizendo o próprio ADR que a feature implementa. A correção certa era
`categoria in (PRODUCAO, INSTALACAO)`, e só ficou clara depois de escrever DOIS testes de
regressão com templates fictícios — um só-pós-entrega (não semeia) e um só-instalação (semeia) —
e notar que a correção mais óbvia passava no primeiro e falhava no segundo.

**Como confirmar que a correção discrimina de verdade:** sabotagem nos dois sentidos, não um só.
Reduzir a tupla `(PRODUCAO, INSTALACAO)` para só `(PRODUCAO,)` tem que derrubar o teste
só-instalação; reintroduzir `if lista:` no lugar do `any(categoria in ...)` tem que derrubar o
teste só-pós-entrega. As duas sabotagens, e as duas guardas caindo exatamente como esperado, são
o que distingue "os testes passam" de "os testes discriminam" — dois casos reais concordando nunca
prova que o critério certo foi escrito; só um terceiro caso, hipotético e explícito no teste,
prova.

**Como generalizar o diagnóstico:** sempre que uma condição usa a PRESENÇA de uma coleção
(`if lista:`, `if lista.length`, `.get("chave", [])` truthy) como proxy para uma propriedade do
CONTEÚDO dessa coleção (categoria, tipo, estado de um item dentro dela), pergunte: existe um
elemento cuja presença faria a lista não-vazia mas cujo CONTEÚDO não deveria disparar o efeito?
Se a resposta é "sim, mas nenhum dado real tem isso hoje" — é exatamente o caso deste verbete: o
bug existe, só não tem sintoma ainda porque os dados reais são coincidentemente bem-comportados.

**Ref:** Empresa Milionária, sessão de produção 2026-09-03 (`empresa-milionaria-e3`) —
`app/casos_uso/aplicar_template_nicho.py` (semeadura de `dias_nao_uteis`, ADR-0019), achado por
`empresa-milionaria-49` (via `percus-review-auto.ps1`) e independentemente pela própria sessão
autora ao rodar o R11 antes do commit; corrigido e testado antes de `91d543a`. Relacionado, mas
DIFERENTE de [[categoria-nova-esquecida-em-lista-de-enumeracao]] — lá o bug é "esqueceram de somar
um valor a uma lista de enumeração"; aqui é "a lista existe e está completa, mas o teste aplicado
sobre ela mede a coisa errada" (presença em vez de categoria).
