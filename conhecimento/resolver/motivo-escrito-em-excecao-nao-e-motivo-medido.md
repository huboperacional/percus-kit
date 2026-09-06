## Motivo escrito em lista de exceção não é motivo MEDIDO — a guarda cobra que ele exista, nunca que seja verdadeiro {#motivo-escrito-em-excecao-nao-e-motivo-medido}

`tags: lista de excecao, declarar ou ligar, motivo por escrito, guarda estatica, envelhece, ja conferido, falso verde, harness de isolamento, multi-tenant, re-medir, R23, ausencia nao verificada`

**Origem:** Empresa Milionária, 2026-09-05 — harness de vazamento multi-tenant. **Dois de cinco
motivos declarados eram FALSOS**, e um deles era contradito por uma variável a três linhas de
distância.

**Contexto:** o padrão *"ligue ao ataque OU declare a exceção com motivo por escrito"*. É um bom
padrão — nasce justamente para acabar com o esquecimento silencioso, e a guarda que o acompanha
costuma ter três asserções: o item está no mapa, o motivo não é vazio, e não há exceção órfã para
item que já não existe. Todas as três passam. **Nenhuma das três olha se o motivo é verdade.**

**Sintoma:** a lista de exceções cresce um item de cada vez, cada um com uma frase plausível.
Meses depois ninguém sabe quais motivos ainda valem, e a guarda segue verde — porque ela mede a
PRESENÇA do texto, não o seu conteúdo. O motivo vira *"já conferido"* para todo mundo que ler
depois, inclusive para quem o escreveu.

**Medido, com nomes:**

- `etapaId` estava fora do ataque com o motivo *"não há etapa da vizinha no cenário. Semear o par
  A/B é trabalho de verdade"* — e a etapa da vizinha **existia desde sempre**, criada anônima
  dentro de um `add_all([...])` sem variável, **a três linhas do próprio comentário**. Só o `id`
  não era alcançável. Custo: **10 rotas** fora do ataque por meses, quase todas de transição de
  estado.
- `tipoEtapaId` dizia o mesmo e a variável `tipoEtapaB` era **nomeada**, no mesmo bloco.
- Os outros três motivos (`orcadoId`, `excecaoId`, `grupoParcelamentoId`) foram conferidos um a um
  e eram verdadeiros — o que confirma que o problema não é desleixo de quem escreveu, é **ausência
  de re-medição**.

**A mesma classe apareceu mais duas vezes no mesmo dia, o que a torna de processo e não de pessoa:**

1. Uma declaração de contexto legítimo afirmava que *"o contexto é restaurado pelo job
   `app/modules/scheduler/anonimizacao.py`"* — o diretório tem 9 jobs e **nenhum** com esse nome; o
   caso de uso não tinha chamador algum em `app/`. Descrevia o desenho PRETENDIDO no tempo verbal
   do MEDIDO.
2. Ao consertar, um revisor **repetiu de volta** o motivo falso do `excecaoId` ("a guarda da
   jornada responde primeiro"), e eu obedeci e revertei minha própria correção. Um segundo revisor
   foi medir: não há guarda de jornada — é **uma consulta com três condições**, e com o parâmetro
   desligado o `id ==` recebe UUID sorteado, não casa linha nenhuma, e o filtro de tenant **nunca é
   avaliado**. 🔑 *"Motivo escrito não é motivo medido" alcança também o motivo que um revisor te
   devolve.*

**Por que "não existe X" é a forma mais perigosa de motivo:** ela é uma afirmação de **ausência**, e
ausência é o que ninguém re-mede — enquanto "existe Y e ele impede Z" convida à conferência. Pior:
é a mais barata de falsificar (`rg` de dez segundos) e por isso a que mais envergonha quando cai.

**How to apply:**

1. **Ao tocar numa lista de exceções, re-meça os motivos que você NÃO vai mexer.** É o passo que
   ninguém faz, e é onde o achado mora. Custa um `rg` por item.
2. **Motivo que afirma ausência tem de dizer ONDE se procurou** — "não há `etapaB` no dicionário
   devolvido pela fixture `cenario` (linha N)" é falseável; "não há etapa da vizinha no cenário"
   não é.
3. **Prefira motivo que aponte MECANISMO a motivo que aponte ausência.** "Mediria cross-CLIENTE
   porque o único usuário alheio é de outra família" sobrevive ao tempo; "não existe" não.
4. **Ao aceitar um finding de review que se apoia num motivo já escrito, meça o motivo, não o
   argumento.** Argumento plausível e mecanismo real falham de formas diferentes, e só o segundo se
   verifica.

**Relacionado:** [O comentário que documenta a guarda pode desligar a guarda](comentario-sobre-a-regra-desliga-a-regra.md) — ali o texto
desliga a guarda; aqui o texto **substitui** a medição. E [Guarda passa verde porque não mede nada](guarda-verde-porque-nao-mede-nada.md),
de que esta é a variante documental.
