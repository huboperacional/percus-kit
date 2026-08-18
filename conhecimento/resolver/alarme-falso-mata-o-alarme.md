## Alarme falso treina todo mundo a ignorar o alarme de verdade {#alarme-falso-mata-o-alarme}

`tags: playwright, globalTeardown, config.projects, --project, falso positivo, ruido, storageState, mtime, deteccao de rodada`

**Origem:** Família Milionária, 2026-07-31 — pego na própria verificação do fix acima.

A 1ª versão do teardown gritava *"🚨 ficou lixo em PRODUÇÃO"* ao fim de uma rodada
`--project=publico`, que **não cria nada**. Um alerta que dispara quando não há problema treina o
time a ignorá-lo — e foi assim que uma suíte morta passou 3 semanas despercebida.

- **Gotcha concreto:** `config.projects` no `globalTeardown` **NÃO** é filtrado por `--project` —
  numa rodada `--project=publico` ele ainda lista o `chromium`. Não serve pra saber o que rodou.
- **O sinal honesto:** o **mtime do `storageState`**. Só o `auth.setup` o escreve, e só o projeto
  autenticado depende dele; reescrito depois que o processo subiu = a rodada autenticada aconteceu
  agora. De quebra separa token expirado **antes** (nada rodou, nada criado) de expirado **no meio**
  (aí há lixo órfão, e o alarme é legítimo).
- **A regra:** antes de escrever um alerta, pergunte "quando ele dispara sem haver problema?". Se a
  resposta não for "nunca", ele nasce ruidoso e morre ignorado.
