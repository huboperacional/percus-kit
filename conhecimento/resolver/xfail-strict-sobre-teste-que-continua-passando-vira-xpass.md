## Feature desligada não faz o teste dela falhar: `xfail(strict)` sobre teste que continua passando vira XPASS e derruba a suíte {#xfail-strict-sobre-teste-que-continua-passando-vira-xpass}

`tags: pytest, xfail, xpass, skipif, decisao de produto, teste que guarda, plano, R23`

**Sintoma:** uma decisão de produto desliga uma feature, e o plano manda trocar o `skipif` do teste
dela por `xfail(strict=True)` com a razão *"a feature não existe mais"*. Parece o registro honesto —
declarar em vez de apagar. Mas se o teste **continua passando**, `strict` transforma isso em
**XPASS**, que é falha: a suíte fica vermelha com o produto correto.

**Por que ele continua passando:** o teste mede um invariante do código, não a feature desligada. O
caminho de aplicação que criava o dado sumiu, mas o teste planta o dado **direto** (ORM ou `INSERT`)
e afirma o que a leitura faz com ele.

**Reprodução real** (Empresa Milionária, V2.3, 18/09/2026): com a contra-entrega desligada (Q3 = B),
o plano mandava `xfail(strict=True, reason="sem contra-entrega, linha negativa não existe")` no teste
`test_a_contra_entrega_negativa_ENTRA_em_entregue`. Medido: o `CHECK` do banco é `quantidade <> 0`,
aceita negativo; o teste grava a linha negativa direto e a soma não filtra. Ele **passa**. O achado
veio do review cross-provider sobre o plano, antes de virar código.

**A leitura certa:** rode o teste e leia o resultado antes de escolher a marca.

| O teste, hoje | O que fazer |
|---|---|
| **Passa** | Não é lixo: é uma **guarda**. Renomeie e reescreva o docstring para o que ele protege agora, e deixe **ativo** |
| **Falha por asserção** | `xfail(strict=True)` é legítimo — e ainda precisa da segunda prova: que ele fica verde quando a feature voltar |
| **Falha por erro de coleta** (`rc` 4/5, import quebrado) | Não é vermelho: é teste que não roda. Conserte antes de marcar qualquer coisa |

No caso real, o teste virou `test_somasPorItem_nao_tem_clausula_de_exclusao_escondida_para_linha_negativa`:
a linha negativa passou a existir só como **defeito**, e a guarda é justamente o que impede alguém de
"consertar" a soma com um filtro `quantidade > 0` que cegaria a varredura que caça o defeito.

Relacionado: [[xfail-strict-que-nunca-libera-e-guarda-impossivel]],
[[xfail-que-xpassa-anuncia-defeito-que-nao-demonstra]].
