## Antes de consultar o conselho sobre uma decisão arquitetural, procure se ela já foi tomada {#decisao-arquitetural-pode-ja-ter-sido-tomada-e-revisada}

tags: conselho, council-consult, retrabalho, docs prévios, arquitetura, RLS, multi-tenant,
pergunta ao operador, contexto perdido entre sessões

**O padrão que engana:** uma sessão chega numa task (ex.: "task D0: decidir a chave de
isolamento de tabela X") cuja decisão parece aberta — não há nada no `HANDOFF.md` nem no
`PLANO.md` marcando-a como resolvida. A sessão faz o trabalho certo *na superfície*: pergunta
ao operador, recebe uma resposta em linguagem natural ("provavelmente vai ser assim..."),
formaliza a pergunta com opções A/B/C, consulta o conselho (`council-consult`), recebe
consenso, e implementa — tudo dentro do processo declarado, tudo documentado, revisão
cross-provider limpa.

**O buraco:** a decisão **já tinha sido tomada e revisada 2 vezes por conselho de 3 provedores**
numa sessão anterior, num documento de análise (`docs/2026-08-24-...md`) que não estava
referenciado no `HANDOFF.md` nem no `PLANO.md` — só citado de passagem num comentário de teste
não relacionado (`test_rls.py`, docstring de outro teste, `docs/2026-08-24-fase-d-isolamento-
do-canal.md §1.1`). A nova sessão implementou, testou, tudo passou — e só ao escrever um teste
que citava um arquivo vizinho (mesmo prefixo de data, nome parecido) é que a existência do
documento anterior apareceu. A decisão nova (`grupo_id`) **contradizia diretamente** a decisão
antiga (`empresa_id`), que era estruturalmente mais sofisticada (dois modos de operação,
regra de precedência, ciclo de vida de vínculo) porque tinha sido **bloqueada duas vezes** pelo
conselho até ficar certa.

**Por que isso é pior que não perguntar nada:** o processo *pareceu* rigoroso — pergunta ao
operador, conselho consultado, 2/2 de consenso — e por isso é fácil de defender como "eu segui
o processo". Mas o conselho consultado na segunda rodada **não tinha o contexto da primeira**:
respondeu a uma pergunta empobrecida ("o número atende um grupo, não uma empresa") sem saber
que uma sessão anterior já tinha modelado exatamente esse cenário ("linha compartilhada" vs.
"linha dedicada") e chegado numa resposta diferente e mais completa. Consenso construído sobre
premissa incompleta é o modo mais caro do conselho errar — e aqui quem empobreceu a premissa
foi a própria sessão, sem querer.

**Por que a busca não achou o documento sozinha:** o nome do arquivo
(`2026-08-24-fase-d-isolamento-do-canal.md`) não aparecia em nenhum grep óbvio pela pergunta
("O6", "grupo_id", "device") — só apareceu ao ler um ARQUIVO DE TESTE inteiro (`test_rls.py`)
de cabo a rabo por outro motivo (buscar o padrão de fixture pra copiar) e notar uma referência
de docstring a um arquivo vizinho. Um `grep -r "isolamento do canal" docs/` ou um
`ls docs/2026-08-24-*` teria achado em segundos — mas nenhum dos dois foi tentado, porque a
sessão não tinha razão pra suspeitar que a pergunta já tinha resposta.

**Como se evita:** antes de levar uma decisão arquitetural not-trivial ao operador ou ao
conselho — principalmente uma que toque migration, RLS, ou qualquer coisa com efeito de anos —
rode `ls docs/<data-recente>-*` e um grep pelo TEMA (não só pela sigla da task) na pasta `docs/`
inteira. Um documento de análise que já existe é sinal de trabalho anterior; a ausência de
menção no `HANDOFF.md` não prova que a decisão está em aberto, só que o handoff não linkou pra
ela — `HANDOFF.md` tem teto de linhas e comprime; documentos de análise ficam soltos em
`docs/AAAA-MM-DD-*.md` sem índice central.

**O que fazer quando descobrir tarde:** parar imediatamente (não commitar o trabalho da
premissa errada), reverter (`git checkout --` nos arquivos modificados, `rm` nos novos, se
nada foi commitado ainda), levar o CONFLITO ao operador de forma explícita — não silenciar a
descoberta nem decidir sozinho qual das duas versões vale — e refazer pelo desenho já aprovado.

**Ref:** Empresa Milionária, Fase D Task D0 (migration do canal WhatsApp), 2026-08-27. Decisão
nova por `grupo_id` (não commitada) descartada em favor de `docs/2026-08-24-fase-d-isolamento-
do-canal.md` (`empresa_id`, resolução pelo remetente, revisado 2x por conselho de 3 provedores
em 24-25/08).
