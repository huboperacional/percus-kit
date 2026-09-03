## Falsificação NÃO fica vermelha — e a trava está boa; o TESTE é que está fraco {#falsificacao-verde-porque-outra-camada-barrou}

tags: falsificacao verde, teste nao pega regressao, defesa em profundidade esconde teste, mutante
sobrevive, remover filtro e teste passa, resumo parcial esconde defeito

**Sintoma:** você quebra de propósito a coisa que o teste deveria proteger — tira o filtro, inverte
a condição — e a suíte continua **verde**. A leitura fácil é "o código está certo de outro jeito" ou
"o teste é redundante". Em sistema com defesa em profundidade, quase sempre é outra coisa.

**Causa raiz:** **outra camada barrou o efeito visível.** O defeito aconteceu de verdade, e o que o
teste mede não muda porque uma guarda mais abaixo o compensou. Exemplo medido: removi o filtro
`empresa_id` da consulta de um job de varredura. O job passou a varrer o tenant inteiro — mas cada
linha alheia era recusada adiante pela guarda do caso de uso e caía no `except` como *falha
tolerada*. O contador de sucessos não mudou, nada vazou, e o teste chamado
`test_o_job_nao_alcanca_a_empresa_VIZINHA` ficou verde com o job varrendo o vizinho inteiro.

**Solução:** quando a falsificação não fica vermelha, **desconfie do teste antes do código**, e
pergunte *qual camada absorveu o efeito*. Em varredura, asserte o **resumo inteiro** — inclusive
os contadores de erro e de item pulado — em vez de só o efeito final. Foi o contador de falhas que
denunciou: com o filtro fora, ele deixa de ser zero.

**Corolário de desenho:** um `except Exception` amplo em varredura (que existe por boa razão — uma
linha ruim não pode derrubar a rodada) **converte vazamento de escopo em "falha tolerada"**. Conte
as falhas num campo próprio, senão "processou tudo" e "errou em tudo" produzem o mesmo resumo de
zeros.

**Ref:** Empresa Milionária, Fase B Task 6, 2026-08-14. Das seis falsificações da task, cinco
ficaram vermelhas na primeira tentativa; a sexta expôs um teste fraco que eu tinha escrito
acreditando que cobria isolamento de tenant.

---

**Corolário: a camada que absorve pode estar ACIMA, e não abaixo — e aí quem esconde é o
`assert` por FAIXA de status.** Segunda medição, 2026-09-02, mesma classe e mecanismo espelhado.

O harness de isolamento ataca cada rota com o id de um recurso da empresa vizinha e assere
`status_code in range(400, 500)` — deliberadamente uma faixa, para distinguir "a aplicação
recusou" (4xx) de "quem recusou foi o banco" (5xx). Só que a fixture do cenário montava as duas
empresas **sem ativar módulo nenhum**, e toda rota de escrita atrás de uma fronteira de módulo
(`exigirRecursoAtivo`) respondia **403 "módulo desativado"** antes de a consulta do recurso
sequer rodar. 403 está em `range(400, 500)`. A prova: removido o filtro `empresa_id` da consulta
do recurso, o harness seguiu **verde** — e a rota respondia sobre o módulo, não sobre o tenant.
Depois de ligar os módulos no cenário, o mesmo experimento derruba o harness com
`DELETE … devolveu 204`: o usuário de uma empresa apagando a linha da outra.

**O que generaliza:**
- **`assert` por faixa de status aceita a recusa da guarda ERRADA.** `4xx` não diz *qual* camada
  recusou. Onde houver mais de uma guarda no caminho, ou asserte o status exato que a guarda sob
  teste produz, ou asserte o corpo — que nomeia quem recusou.
- **Pré-condição desligada na fixture desarma o teste inteiro, e nada na saída acusa.** Não vira
  `skip` nem `xfail`: vira `PASSED`. Vale para feature flag, módulo, licença, plano — qualquer
  chave que recuse cedo. Na dúvida, ligue tudo o que não é o objeto do teste.
- **Alcance é multiplicativo, não pontual.** Uma linha de fixture cegou o vetor mais caro do
  harness em **44 rotas de escrita** de uma vez, e o custo não é bug hoje — nenhuma das 44 tinha
  o defeito — e sim a primeira guarda de tenant que sumir amanhã, em silêncio.
- **Ligar tudo e reatacar é barato, e é a medição que decide.** Rodou em 36 s, não acendeu nada,
  e foi o que separou "há vazamento" de "há cegueira" — dois diagnósticos com o mesmo sintoma
  (suíte verde) e consequências opostas.

**Ref:** Empresa Milionária, produção fatia 0 Task 5, 2026-09-02 — achado ao ligar a primeira
rota de escrita de um módulo novo, cujo alias nasceu desativado em todo cenário existente.
