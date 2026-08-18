## Ferramenta de monitoramento roda INERTE com os testes verdes: `source` de outro script clobrou o entry point {#source-clobra-entry-point}

`tags: bash, source, shell, funcao sobrescrita, main, monitor inerte, cron, teste unitario passa, falso verde, colisao de nomes`

**Origem:** auth-service, 2026-07-30 — o vigia de CORS subiu quebrado e só apareceu ao rodar na VPS.

`cors-watch.sh` faz `. cors-smoke.sh` no fim (pra reusar uma função) e **depois** chama `main`. Só
que os dois arquivos definiam `main()`. Como o `source` vem **depois** das definições, a `main` do
smoke sobrescreveu a do watch: o cron rodava o smoke e ia embora — **sem estado, sem alerta, sem
log**. Os 20 testes unitários passavam porque carregam **só** o watch, onde não há colisão.

- **A regra:** script que faz `source` de outro é dono de um namespace compartilhado. Nome genérico
  (`main`, `log`, `init`, `run`, `cleanup`) é colisão esperando acontecer — prefixe o entry point
  (`watch_main`) e **teste a ausência de colisão**, não só o comportamento.
- **O assert que pega a classe inteira** (não só a ocorrência):
  ```sh
  _funcs_of() { bash -c 'set +u; source "$1" >/dev/null 2>&1; declare -F' _ "$1" | awk '{print $3}' | sort; }
  comm -12 <(_funcs_of a.sh) <(_funcs_of b.sh)   # tem que sair VAZIO
  ```
- **Sintoma-assinatura:** o script "roda" (exit 0) e produz a saída do arquivo **sourceado**, mas
  nenhum efeito colateral próprio (arquivo de estado não criado, log próprio ausente).
- **Lição de método:** teste unitário que carrega um só arquivo **não** exercita o wiring. Rode a
  ferramenta pelo caminho real (o do cron) antes de chamar de pronta.
