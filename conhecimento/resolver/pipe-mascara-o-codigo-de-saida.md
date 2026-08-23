## `| tee` e `| tail` devolvem o exit code do PIPE, não do comando — suíte vermelha vira `exit 0` {#pipe-mascara-o-codigo-de-saida}

`tags: bash, exit code, PIPESTATUS, pipefail, tee, tail, pytest, deploy, verde falso, CI, background task`

**Contexto:** rodei a suíte com `pytest -q 2>&1 | tail -25` em background. A tarefa reportou **exit code 0**. A suíte tinha **1 teste vermelho**. No mesmo dia, um `deploy.sh 2>&1 | tee log` reportou exit 0 com a verificação externa devolvendo **502**. Três vezes em um dia, com três comandos diferentes.

**Causa raiz:** num pipeline, o shell devolve o status do **último** comando. `tail` e `tee` praticamente sempre saem 0 — então o status real do comando da esquerda é descartado. Não é bug de ferramenta nenhuma: é a semântica do pipe, e ela morde exatamente quando se quer automação ("a tarefa terminou bem?").

O agravante é que o pipe normalmente é acrescentado **para poder ler a saída** — ou seja, o gesto de tornar o resultado legível é o mesmo que destrói o sinal de sucesso.

**Fix — três formas, por ordem de simplicidade:**

```bash
# 1. Sem pipe: redireciona e captura o status
pytest -q > /tmp/saida.txt 2>&1; echo "EXIT=$?"; tail -4 /tmp/saida.txt

# 2. pipefail: o pipeline devolve o primeiro status != 0
set -o pipefail
pytest -q | tail -25          # agora sai != 0 se o pytest falhar

# 3. PIPESTATUS: o status de cada elo (bash)
pytest -q | tail -25
echo "pytest saiu com ${PIPESTATUS[0]}"
```

⚠️ **`set -euo pipefail` no topo do script não protege quem CHAMA o script por pipe.** O `deploy.sh` tinha `pipefail` e mesmo assim a chamada `ssh vps "./deploy.sh" | tee log` reportou 0 — o `pipefail` valia dentro do script, não no pipeline de fora.

📌 **Regra prática:** quando o código de saída for a informação que interessa — automação, CI, tarefa em background, gate de deploy — **capture `$?` sem pipe**. Leia o arquivo depois. Ler e verificar são dois atos; juntá-los num pipeline custa o segundo.

📌 **E não confie no "exit 0" de uma tarefa em background sem olhar a saída.** Foi só porque fui ler as últimas linhas que descobri as duas primeiras ocorrências.

**Ref:** Empresa Milionária, 2026-08-22/23 — três ocorrências no mesmo dia (suíte, deploy, e a terceira num `git commit` cuja mensagem passou por crase no shell).
