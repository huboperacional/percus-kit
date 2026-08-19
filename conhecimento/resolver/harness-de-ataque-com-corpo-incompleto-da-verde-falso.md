## Harness de ataque com corpo incompleto dá verde falso {#harness-de-ataque-com-corpo-incompleto-da-verde-falso}

`tags: multi-tenant, harness de isolamento, teste de seguranca, falso negativo, 422, pydantic, corpo legitimo, rota nova, tenancy, ataque parametrizado`

**Contexto:** um harness genérico de isolamento ataca cada rota trocando um `*_id` do corpo por
um recurso da empresa vizinha e exige `4xx`. Rota nova entrou, o ataque rodou, **verde** — e o
verde não provava nada.

**Causa raiz:** o helper que monta o "corpo legítimo" da requisição era um `if/elif` por sufixo
de caminho, com `return {}` no fim. A rota nova não tinha ramo, então o ataque partia de `{}`,
acrescentava só o campo alheio e enviava um corpo **sem os campos obrigatórios**. O Pydantic
recusava por *campo faltando* — **422, que é `4xx`** — antes de qualquer consulta ao banco. A
guarda de tenant nunca chegou a ser exercida: apagá-la inteira não mudaria a cor do teste.

**Sintoma que engana:** o número de testes sobe, a rota nova aparece na parametrização, e o
relatório diz "rota coberta pelo harness de isolamento". Nada disso é falso — e nada disso é a
mesma coisa que a guarda ter sido testada.

**Como confirmar em 30 segundos:** imprima o corpo que o ataque enviou, ou leia o `detail` da
resposta. Se ele fala em campo obrigatório (`field required`, `missing`) em vez de falar do
recurso alheio, o ataque morreu no schema.

**Correção:** o corpo legítimo tem que ser **completo e válido, com recursos da própria
empresa** — o único elemento alheio é o campo sob ataque. Aí um `4xx` só pode vir da guarda.

**Regra geral, que vale para qualquer teste negativo:** *asserção de família de status
(`4xx`, "não-2xx") não distingue **por que** falhou.* Onde o teste existe para provar que uma
guarda específica recusou, ou se afirma a razão (mensagem, código de erro) ou se garante que
todos os outros motivos de recusa foram eliminados do cenário. Um teste negativo que passaria
mesmo sem o código sob teste é decoração.

**Reforço estrutural:** o mesmo harness já obrigava rota nova a se **declarar** numa lista, sob
pena de derrubar a suíte — e essa parte funcionou, foi ela que pegou a rota nova. O buraco estava
um nível abaixo: declarar a rota é obrigatório, montar corpo para ela não era. Toda tabela de
"como testar X" com fallback silencioso (`return {}`, `pytest.skip`, `default`) recria isso.
Fallback em harness de segurança deveria **falhar pedindo o dado**, nunca devolver vazio.

Ver também [[404-por-design-esconde-tenancy]].
