## Teste que repete a expressão do alvo é espelho, e só reprova se você injetar o defeito nos dois lados {#teste-que-repete-a-expressao-do-alvo-e-espelho}

`tags: gate vazio, espelho, mutante, injecao de defeito, bash, shell, sonda, default derivado, source, teste de contrato`

**Contexto:** um review achou que a sonda `check_jobs_watchdog` lia um caminho de heartbeat com
default FIXO (`/var/lib/.../ultimo_tick`), enquanto quem ESCREVE o tick usa `$JOBS_STATE_DIR`. Um
operador que mudasse `JOBS_STATE_DIR` poria a sonda a vigiar um arquivo que nunca existe — alerta
*"nunca escreveu"* para sempre, com o avaliador vivo e correto.

**A correção foi certa; o gate escrito para travá-la, não.** O teste ficou assim:

```bash
_caminho_da_sonda() {
    printf '%s' "${JOBS_WD_HEARTBEAT:-${JOBS_STATE_DIR:-/var/lib/...}/ultimo_tick}"
}
[ "$(JOBS_STATE_DIR=/tmp/xyz _caminho_da_sonda)" = "/tmp/xyz/ultimo_tick" ] && ok || bad "..."
```

Ele **repete a expressão** que a sonda usa, em vez de chamar a sonda. Ao injetar o defeito só no
alvo, o teste continuou verde — o espelho tinha a versão correta. Só reprovou quando o defeito foi
injetado **nos dois lados**, que é o exato oposto do que um gate deve fazer.

**Como perceber:** se para ver o gate reprovar você precisou editar o teste junto com o alvo, o
gate não mede o alvo. O procedimento de mutante já denuncia isso — a pergunta *"quantos arquivos
tive de tocar para injetar este defeito?"* tem de ter resposta **um**.

**A correção:** chamar a função real. No caso, ela já estava no escopo por um `source` em cadeia,
então bastou montar o estado e invocá-la:

```bash
_tmp="$(mktemp -d)"; : > "$_tmp/ultimo_tick"
( JOBS_STATE_DIR="$_tmp" check_jobs_watchdog ) && ok || bad "..."
( JOBS_STATE_DIR="$_tmp/nao_existe" check_jobs_watchdog ) && bad "..." || ok
```

Com o defeito injetado **só na sonda** e o teste intocado, ele reprova.

**Por que a versão espelho é sedutora:** quando o alvo é um `local f="${A:-${B:-default}}/x"` dentro
de uma função que faz outras coisas (lê `stat`, calcula idade, mexe em `LAST_FAIL_DETAIL`), copiar
só a expressão parece mais limpo e mais rápido — testa "a regra", sem montar o cenário. Mas a regra
não existe separada da função: o que se quer travar é o comportamento DELA.

**Regra prática:** um teste nunca deve reescrever uma expressão que existe no alvo. Se testar o
alvo é difícil (precisa de arquivo, de env, de `mktemp`), **essa dificuldade é o teste** — montar o
cenário é o que dá valor. Um `mktemp -d` e duas linhas resolveram aqui.

**Família:** é o mesmo defeito de `mock_mirrors_bug` e `mirror_test_satisfied_docstring` — o dublê
concorda com a suposição de quem o escreveu. A diferença é que aqui o dublê está dentro do próprio
teste, o que o torna mais difícil de ver: não há `mock` nenhum na linha.

Relacionados: [[a-sabotagem-prova-o-que-voce-imaginou]], [[placar-errado-no-plano-e-sintoma-de-lacuna]]
