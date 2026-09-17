## Plano não emenda spec: a "exceção única declarada no plano" vira violação de FR que nenhum review pega {#plano-nao-emenda-spec-a-excecao-volta-a-spec}

`tags: spec, plano, FR, pre-mortem, conselho, excecao declarada, log, LGPD, rodada 2, R9, R11, R23`

**Sintoma:** o pre-mortem acha um buraco no plano ("se X falhar, o dado some"), o plano conserta e
**declara a exceção em voz alta** — *"esta é a única exceção à regra Y"*. O parecer fica honesto, o
revisor seguinte lê a declaração como decisão tomada, e ninguém volta à spec para ver **de quem é a
regra Y**. Quando a regra é um FR, a "exceção declarada" é uma **violação de requisito**, escrita com
todas as letras e aprovada por engano.

**Reprodução real** (Empresa Milionária, 2026-09-15, plano da guarda do documento no Drive do cliente):

- **Rodada 1 do pre-mortem:** *"se o INSERT do arquivo órfão também falhar, o id do arquivo no Drive
  se perde e o arquivo fica impossível de achar."* Procede.
- **Correção aplicada:** logar `guarda_orfao_nao_registrado` com o `arquivo_id_drive`, com a nota
  *"única exceção declarada à regra 'nenhum log com id do Drive'"*.
- **Rodada 2, com revisor novo:** a regra **não era do plano**. O FR-383 da spec dizia
  *"nenhum log da guarda DEVE conter nome do arquivo, conta conectada, id de arquivo no Drive ou
  credencial"* — **sem cláusula de exceção**. O plano tinha, de fato, emendado a spec.

🔑 **O erro não é logar o id. É o plano decidir sozinho que um "nunca" da spec tem exceção.** Quem
escreve o plano está resolvendo um problema de implementação e enxerga a regra como obstáculo local;
quem escreveu o FR estava decidindo o que o produto nunca faz. Uma exceção de plano não passa por
conselho de spec, não vai ao operador e não aparece em nenhuma tabela de requisitos — ela só existe
num parágrafo no meio de uma Task.

### Por que a declaração em voz alta ATRAPALHA aqui

Declarar o desvio é a regra certa em quase tudo (estilo, dívida, risco aceito) — e é por isso que
esta armadilha passa. A frase *"exceção única declarada"* tem a **forma** de rigor: nomeia a regra,
limita o alcance, promete que o teste continua proibindo o resto. O revisor seguinte lê rigor e não
abre a spec. Compare:

| O que o plano escreveu | O que o revisor precisava ler |
|---|---|
| "única exceção à regra 'nenhum log com id do Drive'" | "o FR-383 diz 'nunca' e **eu vou contra ele**" |

A segunda frase teria parado a revisão na hora. A primeira não para ninguém.

### O teste, em uma pergunta

Antes de escrever "exceção" num plano: **de quem é a regra que estou excepcionando?**

- **Do plano** (convenção de implementação, molde de teste, ordem de tasks) → exceção declarada
  resolve, e basta.
- **Da spec (FR), de um ADR ou do canon** → **não resolve.** Só há três saídas legítimas:
  1. **achar solução que não precise da exceção** (a melhor, e quase sempre existe);
  2. **voltar à spec** com emenda do FR, que re-roda o conselho de spec;
  3. **virar pergunta ao operador**, com a consequência das duas respostas escrita.

### A solução que quase sempre existe: o dado já está em outro lugar

No caso real, a recuperação do órfão **não precisava do log**. O mesmo plano já mandava gravar
`titulo_id` e `impressao_digital` como **propriedades do arquivo no próprio Drive** no momento do
envio. Ou seja: o arquivo órfão era achável por varredura de propriedade, sem que o id passasse por
log nenhum.

O conserto ficou:

1. **repetir o `INSERT` do órfão numa sessão NOVA e isolada** (a falha provável é a transação
   envenenada pelo `rollback` anterior — sessão nova muda materialmente o resultado), até 3 tentativas;
2. só depois, o log **sem** o id — o FR-383 continua literal;
3. a recuperação passa a ser a **busca por propriedade** no Drive.

🔑 **Generalizando:** quando um plano pede exceção a um "nunca" de segurança, privacidade ou
retenção, pergunte **onde mais aquele identificador já está persistido legitimamente**. Costuma
haver um lugar — propriedade do objeto externo, coluna já existente, chave derivável do conteúdo — e
é ele que dispensa a exceção.

### Guarda barata

Duas, e nenhuma custa rodada de conselho:

- **`rg -n "exceção (única|declarada)" no plano** antes de fechar: cada ocorrência exige a resposta
  escrita de "de quem é a regra" — e, se a regra for FR, o número do FR mais a citação do texto dele.
- **Na autorrevisão do plano**, a tabela FR → Task ganha uma coluna "contraria algum FR?" — a tabela
  já é lida FR a FR no fechamento, e é o lugar onde a contradição fica impossível de não ver.

### O que fez a rodada 2 pegar

**Revisor novo, que não leu a rodada 1** — e, por isso, não herdou a premissa de que aquela regra era
do plano. Um revisor retomado teria requentado o próprio veredito. É o mesmo motivo pelo qual a
rodada 2 do conselho pede agente fresco.

### Verbetes relacionados

- [[conselho-2x-e-direcao-nao-spec]]
- [[fact-check-de-spec-que-nao-abre-o-codigo-produz-defeito-fantasma]]
- [[alvo-do-spec-stale]]
