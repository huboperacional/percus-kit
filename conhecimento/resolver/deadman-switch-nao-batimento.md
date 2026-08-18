## Como saber se um cron/monitor MORREU: batimento periódico não serve — só dead-man's switch {#deadman-switch-nao-batimento}

`tags: cron, watchdog, monitor, heartbeat, batimento, dead man switch, silencio, alerta, quem vigia o vigia, observabilidade`

**Origem:** auth-service, 2026-07-30/31 — desenho corrigido pelo time Micro Investors antes de virar código.

Um monitor que só fala quando algo quebra tem um modo de falha invisível: **monitor morto e monitor
saudável são indistinguíveis**, porque os dois são silenciosos. Um `crontab -e` distraído, ou um
`git pull` de deploy abortando em working tree suja, e ninguém sabe.

**A correção intuitiva está errada.** "O monitor manda um resumo periódico (vivo, N ciclos)" **não**
resolve: se ele morre, o resumo simplesmente **não chega** — e "não chegou nada" é indistinguível de
"semana tranquila". Move o problema de *silêncio parece saúde* para *silêncio parece saúde, com mais
passos*.

- **O desenho que funciona (dead-man's switch):** o monitor **carimba** (arquivo, chave, endpoint) e
  **outro processo** alerta quando o carimbo passa da validade.
- **Por quê:** alertar na **presença** de um evento falha aberto (evento não veio = silêncio);
  alertar na **ausência** exige alguém contando o tempo — é o único desenho em que **morrer gera
  sinal**.
- **Regra dura:** quem alerta tem que ser processo **diferente** do que pode morrer. O monitor
  auto-verificando-se é justamente o processo que pode não estar rodando.
- **Implementação barata:** um watchdog que já existe checa o `mtime` do arquivo de estado
  (`age > 3 ciclos` = morto). Não crie infra nova — e **peça** ao dono do watchdog em vez de editar
  a ferramenta de outro produto.
