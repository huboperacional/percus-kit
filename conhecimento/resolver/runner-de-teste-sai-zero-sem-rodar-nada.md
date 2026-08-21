## Runner de teste que sai 0 sem rodar nada — o gate é a PRESENÇA do veredito {#runner-de-teste-sai-zero-sem-rodar-nada}

tags: pytest, harness, gate de deploy, exit code, falso verde, set -e, bash -s, ssh heredoc, postgres efemero, silencio nao e sucesso, pipestatus

**Sintoma:** a suíte "passa", o deploy é liberado, e depois se descobre que **nenhum teste rodou**.
A saída não tinha nenhum vermelho — porque não tinha nada.

**Caso medido** (tiatendo, 2026-08-21, num gate de pré-deploy):

```
==> subindo pg efêmero + rodando pytest no VPS
-- esperando o pg aceitar conexão
/var/run/postgresql:5432 - no response

[exited with code 0]
```

**Causa raiz — duas, e a segunda é a que engana de verdade:**

1. O script remoto era servido por `ssh host "... bash -s" <<'EOF'`. O `set -euo pipefail` estava no
   script **local**; o remoto rodava **sem `-e`**. A checagem do banco falhava, imprimia, e o fluxo
   seguia até o fim sem propagar erro.
2. Mesmo com o código de saída certo, `grep failed` numa saída **vazia** não acha nada — e "nenhuma
   falha" é lido como aprovação. **Ausência de vermelho não é verde.**

**Solução — dois gates explícitos, não um:**

```sh
# GATE 1 — a dependência subiu?
if ! docker exec "$PG" pg_isready -U test -d "$DB"; then
  echo "ERRO: o banco efêmero NÃO subiu — NENHUM teste rodou."
  exit 90
fi

# GATE 2 — o runner produziu VEREDITO?
set +e
docker exec "$APP" sh -c "cd /app && python -m pytest $ALVOS -q" 2>&1 | tee /tmp/out.txt
CODIGO=${PIPESTATUS[0]}          # o exit do pytest, não o do tee
set -e
if ! grep -qE "[0-9]+ (passed|failed|error)" /tmp/out.txt; then
  echo "ERRO: o pytest não produziu veredito — a rodada NÃO aconteceu."
  exit 91
fi
exit $CODIGO
```

⚠️ **`${PIPESTATUS[0]}` é obrigatório** com o `tee`: sem ele, o código de saída é o do `tee`, que é
sempre 0 — trocando um falso verde por outro.

**A regra que fica:** o gate de uma rodada de testes é a **presença literal de `N passed`**, nunca a
ausência de falha. Vale para qualquer runner atrás de rede, container ou serviço externo: o modo de
falha comum não é "o teste quebrou", é "o teste não existiu".

**Armadilha vizinha:** o mesmo harness empacota a **working tree viva**. Rodar a suíte enquanto um
agente ainda escreve mede **arquivo pela metade**, e o vermelho resultante imita perfeitamente
"regressão de outra frente" — três falsos alarmes no mesmo dia, um deles diagnosticado como
"poluição de ordem" que **não existia**. Meça só com a árvore parada.

**Ver também:** [[fail-open-esconde-teste-vacuo]], [[gate-falso-negativo-por-rede]],
[[pg-efemero-testes-destrutivos]].
