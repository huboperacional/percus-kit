## Override que SUBSTITUI o padrão global faz a escrita ir para o lugar errado, em silêncio {#override-substitui-e-a-escrita-vai-pro-lugar-errado}

`tags: override, padrao da casa, system_settings, merge vs replace, jsonb, vocabulario, laco nao converge, falha muda, naming_pattern, heranca, multi-tenant, resolucao de config`

**Contexto:** um produto tem um padrão global ("da casa") e permite que um cliente tenha o seu
próprio. A leitura resolve com `override ?? global`. A escrita — a tela onde o operador **ensina**
coisa nova — grava sempre no global. Enquanto nenhum cliente tem override, os dois caminhos
coincidem e ninguém percebe que são caminhos diferentes.

**O sintoma quando alguém finalmente tem override:** o operador aprova, a tela responde sucesso, e
**o mesmo item volta na rodada seguinte**. Nada quebra, nada loga, nenhum teste fica vermelho. O
número simplesmente não anda.

**Causa raiz:** `override ?? global` é **substituição**, não merge. O helper que normaliza recebe o
global como "fallback", o que parece merge na assinatura (`toNamingConfig(valor, fallback)`) e não é:
o fallback só entra quando o valor é nulo. Cliente com override lê **exclusivamente** o dele, e
acréscimo ao global nunca o alcança.

**Como confirmar em 30 segundos, sem ler código:** peça a config resolvida e a do override do mesmo
cliente e compare. Se `resolved === override` byte a byte, é substituição. Depois procure **um item
que existe só no global** e confirme que ele **não** aparece no resolvido do cliente. Medido em
2026-08-23: a casa tinha 7 entradas de `channel`, o cliente 4, e o cliente não tinha o `SRCH` que a
casa ganhara no dia anterior.

**Por que é caro descobrir tarde:** a gravidade é proporcional à concentração. No caso real, o
ÚNICO cliente com override respondia por **441 das 537 entidades da fila (82%)** — a tela inteira
estava sendo desenhada para o único usuário para quem ela não funcionaria. O defeito não estava no
recurso novo; estava no recurso **que já rodava**.

**Três saídas, e a escolha não é técnica:**

| | o que faz | custo |
|---|---|---|
| escrever no **dono do padrão** | quem tem override recebe no override; os demais no global | menor mudança que destrava; mantém o congelamento como está |
| **merge de verdade** | override passa a somar sobre o global | conserta a classe inteira, mas muda a resolução de TODA leitura — maior risco de regressão |
| **remover o override** | o cliente volta a herdar | perde o que era próprio dele; inaceitável sem migrar antes |

**Como evitar a classe:** ao introduzir override de qualquer config global, escreva **no mesmo
commit** o teste que ensina algo pelo caminho de escrita e afirma que o cliente-override passa a
ver. Sem esse teste, escrita e leitura divergem no dia em que o primeiro override nascer — e a
divergência é muda por construção, porque o caminho feliz (ninguém tem override) continua verde.

⚠️ **Não confie no doc para saber se é merge ou replace.** No caso real o doc dizia "substitui a
config inteira" e estava certo — mas a assinatura do helper sugeria o contrário, e foi preciso ler
o corpo (`if (isNamingConfig(value)) return withCategoryDefaults(value)`) para ter certeza.

Relacionado: [[gate-que-le-estado-pos-mudanca-e-cego]].
