## Sessão de login "morre sozinha" em todos os produtos ao mesmo tempo {#sessao-morre-invalidacao-por-pessoa}

`tags: sessão expira, login não dura, logout sozinho, refresh token, family invalidation, invalidate_all_families_for_subject, re-OTP, cross-produto, sub canal:destino, custo OTP, SSO 15 minutos, rt no fragmento, allkeys-lru, maxmemory-policy`

**Contexto:** usuários de VÁRIOS produtos reclamam que não ficam logados — voltam no dia seguinte (às vezes em horas) e tomam OTP de novo. Cada time acha que é "coisa do meu app". O TTL do refresh está correto (ex.: 30 dias) e a rotação até desliza a janela, então "a conta fecha" no papel.

**Causa raiz (a que já aconteceu):** algum fluxo de login chamava uma primitiva de invalidação **chaveada pelo `sub`**. Em auth multi-produto o `sub` costuma ser `canal:destino` (`whatsapp:+55…`) — ou seja, **a PESSOA, não a audience**. Invalidar por `sub` num login apaga as famílias de refresh daquela pessoa em **todos os produtos**: um único login por magic-link em qualquer app derruba todos os outros, e o usuário entra num **loop de re-OTP cross-produto** (logou no A → caiu no B; logou no B → caiu no A). Com OTP pago (Cloud API), isso é custo direto por mensagem.

Agrava: era **intencional** (matar refresh token roubado) e estava **testado como correto** — o teste criava famílias em duas audiences e afirmava que ambas morriam. Ninguém tinha ligado aquele teste ao efeito no login.

**Como distinguir das outras causas (medir, não teorizar):** pegue o intervalo entre logins por identidade (ex.: `created_at` da tabela de OTP) e olhe a distribuição:
- mortes a ~TTL do access (minutos) ⇒ **o consumer não renova** — não guarda o `rt` ou não chama o refresh;
- mortes correlacionadas a login em OUTRO produto ⇒ **invalidação por pessoa** (este verbete);
- mortes aleatórias e em massa ⇒ **despejo no Redis** — cheque `CONFIG GET maxmemory-policy`; `allkeys-*` despeja token antes do TTL e o sintoma é idêntico.

**Solução:** login **nunca** destrói sessão. Roubo de token é tratado por rotação + reuse-detection (RFC 6749 §10.4), que é a defesa desenhada pra isso. Logout destrói **só o serviço que pediu** — não construa "logout-all": cross-produto reintroduz o bug sob demanda e vira vetor de DoS; "sair deste serviço" já é o revoke da família apresentada.

**Verifique também as OUTRAS portas de entrada.** No mesmo incidente, o hop de SSO devolvia só o access token (15 min) e nenhum refresh — sessão morta por construção, e ninguém tinha percebido porque o sintoma se confundia com o bug principal. Se um fluxo entrega token, ele tem que entregar o par.

**Trave com barreira estática (AST), não com teste comportamental.** Um teste da primitiva continua verde depois que você tira a chamada do router — ele não pega a reintrodução. Barre no **call-site** e, principalmente, no **import**: guardar só o nome deixa passar alias (`import x as _nuke`), `getattr` e `functools.partial`. Inclua as peças de um wipe artesanal (enumerar chaves do subject + deletar), senão a regressão volta sem citar a função óbvia. E prove a barreira **injetando a regressão e vendo falhar** — barreira que nunca ficou vermelha não vale nada.

**Ref:** auth-service, ADR-0015 (2026-07-23). Sintoma: nenhum dos 10 produtos mantinha login por 1 dia contra 30 planejados.
