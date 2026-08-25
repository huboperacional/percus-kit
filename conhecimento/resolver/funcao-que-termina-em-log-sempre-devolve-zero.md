## Função que termina em `log` sempre devolve zero — e o gate que alimenta o `rc` à mão não vê {#funcao-que-termina-em-log-sempre-devolve-zero}

`tags: shell, bash, valor de retorno, && ||, curto-circuito, funcao mentirosa, rc, gate vazio, produtor do valor, mutation testing, watchdog, entrega, R23`

**Contexto:** um wrapper de alerta, em shell, tratava os dois casos — entregou e não entregou:

```sh
alert() {
    if command -v ops_alert >/dev/null 2>&1; then
        ops_alert "$1" && log "ALERTA enviado" || log "WARN: canal nao entregou"
    fi
}
```

Parece correto, e o **log** de fato fica correto. Mas o valor de retorno de uma função em shell é o
do **último comando executado**, e nos dois ramos o último é `log`, que sempre sai 0. Logo `alert()`
devolvia **sucesso mesmo sem entregar**, na mesma linha em que escrevia `canal nao entregou`.

`A && B || C` **não é** `if/else`: o `||` captura a falha do `&&` inteiro, e qualquer comando de log
no fim zera o status.

**O estrago não é o log — é quem consome o `rc`.** Neste caso havia uma garantia escrita:
*"o contador de falhas só anda depois de o envio dar certo"*, para que um alerta não entregue fosse
**retentado** no ciclo seguinte em vez de pular para o próximo marco (1h depois). Com a função
mentindo, a garantia era **texto**: canal fora = alerta perdido calado.

**Medido (2026-08-24):** com o token do canal trocado por lixo, o log dizia `canal nao entregou`, o
contador andou `1 → 2` assim mesmo, e isolado `alert()` → `0` enquanto a função real de envio → `1`.

**Por que ninguém tinha pego, e é a parte que se transfere:** os testes da garantia passavam o `rc`
**à mão** para a função que o consome. Isso testa a aritmética do contador e **não testa nada** sobre
quem PRODUZ o `rc`. O defeito morava exatamente no vão entre os dois. O gate que faltava chama o
caminho real inteiro — `escalar → _enviar → alert → envio` — com o canal reprovando, e cobra que o
contador **fique** onde estava.

**Conserto:** função cujo retorno é contrato não termina em `A && B || C`. Use `if`, com `return`
explícito em cada ramo — inclusive no ramo "biblioteca ausente", porque ausência de canal também é
não-entrega.

**Antes de mudar o retorno de uma função em script compartilhado, meça duas coisas:** quem consome o
`rc` (aqui era um só; três outros projetos ignoravam) e se há `set -e` (aqui não havia). Sem isso,
"consertar" o retorno derruba o script de todo mundo.

**Regra de bolso:** se um teste **fabrica** a entrada que a função sob teste deveria receber do
mundo, ele mede a função e não o acoplamento. Exercite o produtor, ou o defeito mora no vão.

Relacionado: [[status-de-sucesso-nao-prova-efeito]],
[[a-sabotagem-prova-o-que-voce-imaginou]].
