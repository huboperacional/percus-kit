## Marcador otimizado pro hook apaga o histórico que o medidor precisa — duas funções no mesmo arquivo, e a otimização de uma cega a outra {#marcador-otimizado-pro-hook-apaga-o-historico-do-medidor}

`tags: telemetria, custo, gasto invisivel, marcador, latest.jsonl, sobrescrita, append, hook O(1), R11, deepseek-review, analyze_council_spend, jsonl, um objeto por arquivo, medidor cego, observabilidade`

**Sintoma:** o painel de faturamento do provedor mostra um número muito maior do que qualquer
relatório interno consegue explicar. Medido em 2026-08-19: painel da DeepSeek em **$29,76** no mês,
e a soma de **todos** os logs mensuráveis dos **62** diretórios `.deepseek` da máquina dava
**$0,89**. **97% do gasto invisível**, sem nenhum erro, sem nenhuma exceção, sem nenhuma linha
vermelha.

**Causa raiz — e ela não é um bug, é uma otimização legítima cobrando o preço dela.** O arquivo
`.deepseek/reviews/latest.jsonl` acumulava duas funções ao mesmo tempo:

1. **Semáforo do commit** — o hook R11 lê o marcador pra saber se existe review recente (janela de
   5 min). Precisa ser **barato de ler**.
2. **Contabilidade** — é onde ficavam `model` e `usage`, ou seja, o preço da chamada. Precisa ser
   **acumulável**.

Essas duas exigências são **opostas**. Em 2026-07-20 a função (1) ganhou, com razão: antes o log era
`<timestamp>.jsonl` e o diretório acumulava milhares de marcadores de TTL 5 min, até o hook pendurar
em **~148 s** e travar os commits do projeto. A correção foi um arquivo fixo, **sobrescrito** a cada
review → hook O(1), acúmulo zero.

🔑 **O que ninguém percebeu é que "sobrescrever" resolveu a leitura e apagou a série histórica.**
Cada review passou a apagar o custo da anterior. Não existe log corrompido pra investigar, nem erro
pra achar: existe um arquivo que sempre tem exatamente uma linha, e ela é sempre a mais recente.

🔴 **Piorado por onde o buraco ficou: no caminho MAIS usado.** `.deepseek/reviews` existia em **48**
projetos; `.deepseek/council-log` — que guarda histórico e portanto era mensurável — em **32**. O
medidor enxergava bem justamente o caminho barato e era cego no caro. Relatório que cobre o
minoritário e ignora o majoritário não é "incompleto": ele **afirma um total que não é o total**.

**Solução: separar as duas funções em vez de escolher entre elas.**

- O marcador continua **idêntico** — sobrescrito, O(1). Não desfaça a correção de 2026-07-20; ela
  tem incidente medido por trás.
- A telemetria ganha **diretório próprio**: `.deepseek/spend/<YYYY-MM>.jsonl`, **append**, **um
  arquivo por mês**. Doze por ano, não milhares — é isso que impede a volta do acúmulo que penduro
  o hook. E o hook **nunca varre** esse diretório.

⚠️ **Armadilha de formato que devolve o problema calado:** `council-log/*.jsonl` tem extensão
`.jsonl` mas é **UM objeto por ARQUIVO**. O spend é JSONL **de verdade** — N objetos, um por LINHA.
Ler o spend com `json.loads(texto_inteiro)` devolve **zero entradas sem erro nenhum** — a mesma
falha silenciosa que a telemetria veio acabar, agora dentro do leitor dela. Parser próprio, e:
- linha cortada por append concorrente é **pulada**, não derruba o mês;
- entrada sem `usage` é **descartada**, não vira zero calado somado ao total.

⚠️ **Padronize o fuso nos dois idiomas.** O irmão `.ps1` gravava hora **local** e o `.sh` **UTC**,
e o leitor tira o offset e compara naive: o mesmo instante cairia em **dia** diferente conforme o
script, e na virada do mês em **arquivo** diferente. Não aparece como erro — aparece como relatório
de N dias silenciosamente torto. Pego pelo R11 antes do commit. E não foi a única divergência entre
os irmãos: o `.sh` também nunca recebeu os campos `model`/`usage` que o `.ps1` ganhou em 2026-08-15
— **par de scripts em dois idiomas diverge em silêncio porque nada compara os dois**, e só se
descobre quando alguém precisa do campo que faltou.

**O que a primeira medição revelou, e que a pergunta original não teria achado:** a pergunta do
operador era *"não estamos usando o modelo errado?"*. Não estava — os três caminhos rodavam o modelo
barato. Uma review real gastou **31.747 tokens de saída, 31.197 deles (98%) em RACIOCÍNIO**, pra
produzir uma lista curta de findings. O gasto era **raciocínio em volume**, ~$0,010 por review,
disparado a cada commit em dezenas de projetos. **Nenhuma inspeção de configuração acharia isso** —
só medir o custo por chamada acha.

⚠️ **Limite que apareceu junto:** o marcador encontrado no disco tinha `provider: cross-claude` e
`model: claude-sonnet-5` — foi escrito **à mão por um agente**, não pelo script. O marcador que
libera o commit **pode existir sem nenhuma chamada ao provedor**. Mais um motivo pra contabilidade
não morar nele: ela seria falsificável pelo mesmo caminho.

**Como reconhecer esta classe em outro lugar:** procure arquivo que é ao mesmo tempo *sinal de
estado atual* e *registro histórico*. Sempre que aparecer "sobrescreve pra ficar rápido", pergunte
**o que estava ali antes e quem precisava daquilo**. Caches de status, `latest.json`, `current.log`,
tabela com uma linha por entidade e `updated_at` — todos podem estar apagando a série que alguém
vai querer somar depois. Telemetria quer **append**; semáforo quer **um valor**. Se estão no mesmo
arquivo, um dos dois está sendo mal servido, e o que perde é sempre o que ninguém está olhando hoje.

**Ref:** medido em 2026-08-19 no `percus-kit`, canon 6.39.0, a partir de um painel de faturamento
que não batia com relatório nenhum. Relacionado:
[[troca-para-modelo-de-raciocinio-esvazia-teto-de-tokens]].
