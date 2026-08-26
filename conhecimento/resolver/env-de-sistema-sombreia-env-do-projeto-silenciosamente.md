## Uma variável de ambiente do SISTEMA sombreia o `.env` do projeto sem aviso nenhum {#env-de-sistema-sombreia-env-do-projeto-silenciosamente}

`tags: env var, dotenv, shadowing, deepseek, api key rotacionada, wrapper bash, cross-provider review, r11, chave invalida silenciosa, windows environment variables`

**Contexto:** o operador rotacionou `DEEPSEEK_API_KEY` no `.env` do projeto (Scraper-prospeccao) e
pediu smoke test. Testado direto via `curl` lendo o `.env` com `grep`/`cut` — **HTTP 200, resposta
real**. Minutos depois, a review R11 (`deepseek-review.sh`, o mesmo provider usado pelo wrapper de
commit) falhou com `authentication_error: invalid api key` e o wrapper caiu no placeholder que
libera o gate por TTL (comportamento já documentado como perigoso — nunca confiar nele).

**Causa raiz:** `deepseek-review.sh` carrega `.env` só condicionalmente:
```bash
if [[ -z "${DEEPSEEK_API_KEY:-}" && -f .env ]]; then ... fi
```
Ou seja: **se a variável já existir no ambiente do processo, o `.env` do projeto nunca é lido.** E
existia uma `DEEPSEEK_API_KEY` de sistema/usuário no Windows (visível via `env | grep -i deepseek`
mesmo numa sessão de Bash nova) com uma chave **antiga**, diferente da que o operador acabou de
colar no `.env` — e essa antiga é justamente a que estava inválida.

**Como isso passa despercebido:** qualquer teste que faça `source .env` ou leia o arquivo diretamente
(como o smoke test que rodei primeiro) usa a chave certa e "prova" que está tudo bem. Só o script que
segue o padrão "so carrega .env se a env var não existir" (comum em wrappers bash pra permitir
override manual) é que herda silenciosamente o valor velho do ambiente do sistema.

**Diagnóstico rápido:** `env | grep -i <NOME_DA_VAR>` numa sessão de shell nova, ANTES de rodar
qualquer script que dependa da variável — se aparecer algo, é a variável de sistema, não o `.env`,
que vai valer.

**Fix pontual (sem mexer no ambiente do sistema, que é fora do escopo do projeto):**
`env -u DEEPSEEK_API_KEY bash script.sh` — remove a variável só para aquela chamada, forçando o
script a cair no `.env` do projeto.

**Fix estrutural (não feito aqui, vale para quem mantém o wrapper):** inverter a prioridade —
`.env` do projeto deveria vencer a env var de sistema quando ambos existem, ou pelo menos logar
qual fonte foi usada (`"lendo de .env"` vs `"usando env var já definida"`), já que hoje o silêncio é
exatamente o que torna isto invisível.

⚠️ **Isto pode retroativamente explicar parte do histórico de "DeepSeek falhou intermitentemente"
já documentado neste projeto** (Insufficient Balance, placeholders liberando o gate) — vale
verificar `env | grep -i deepseek` da próxima vez que a review falhar sem explicação clara, antes de
assumir que é saldo ou instabilidade do provider.
