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
