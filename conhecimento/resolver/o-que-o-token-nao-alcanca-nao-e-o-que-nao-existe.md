## O que o token não alcança não é o que não existe {#o-que-o-token-nao-alcanca-nao-e-o-que-nao-existe}

`tags: inventário, ausência, credencial, escopo, permissão, api, meta ads, google ads, alcance, instrumento, relatório ao operador, falso negativo`

**Contexto:** perguntaram quantas contas de anúncio um cliente tem. Listei o que a credencial
devolvia (`/me/adaccounts`), agrupei por Business Manager e reportei: *"não há conta fora do nosso
cadastro"*. Estavam faltando duas, criadas três meses antes.

**Por que sumiram:** elas existiam, mas **não estavam atribuídas ao system user** que eu usava.
Ficavam fora de `/me/adaccounts` e devolviam `user_tasks: None` (contra
`['DRAFT','ANALYZE','ADVERTISE','MANAGE']` nas que apareciam). Eu conseguia até **ler campos
básicos** delas por `GET` direto — o BM era visível —, o que torna a armadilha pior: o objeto
responde, só não aparece em listagem. Quando o operador concedeu acesso, a **mesma chamada** que
antes devolvia 31 passou a devolver 33.

**O erro não foi a medição — foi a frase.** Eu medi *"nenhuma que o token alcança"* e reportei
*"nenhuma que existe"*. A segunda é mais forte do que o instrumento sustenta, e ninguém tinha como
notar a diferença lendo minha resposta.

**O custo foi real:** essas duas contas ficaram de fora de um lote de campanhas de teste sem
ninguém perceber, e o cliente passou semanas achando que tinha "conta travada" — quando o que havia
era conta vazia que nós não víamos.

**Como aplicar**

1. **Nomeie o instrumento na conclusão.** "O token alcança N" — nunca "existem N". Se a pergunta é
   sobre existência, a resposta honesta é: *"o que eu enxergo é X; para afirmar que não há mais
   nada, alguém precisa olhar no painel com uma conta de admin"*.
2. **Antes de concluir ausência, teste o alcance.** Há quase sempre um campo que denuncia:
   `user_tasks` vazio (Meta), conta fora do MCC (Google), tabela populada por job que filtra
   (Postgres). Ausência de permissão e ausência de objeto produzem a **mesma resposta vazia**.
3. **Quando o inventário sustenta uma decisão, cruze com uma segunda fonte.** Foi o que expôs o
   buraco: o registro interno dizia 1 criação numa conta onde a API mostrava 3 objetos.
4. **Contradição do operador é sinal, não ruído.** Ele insistiu — *"como pode? você tinha me
   passado uma lista"* — e a insistência estava certa: ele lembrava do que eu não via.

**Família:** é a mesma classe de
[[ausencia-numa-tabela-so-e-prova-se-o-produtor-escreve-nela]] e de
[[agregado-no-pai-esconde-a-ausencia-do-filho]] — o instrumento responde com confiança sobre uma
região que ele não cobre, e a resposta vazia é lida como fato.
