## Perna Cross-Claude do conselho devolve 401 e não dispara o fallback por subagent {#cross-claude-nativo-401-sem-disparar-fallback}

`tags: conselho, council, cross-claude, 401, invalid x-api-key, __PERCUS_NEEDS_CROSS_CLAUDE__, provider, degradado, PENDENTE`

**Sintoma (2026-09-12, `council-orchestrator.ps1 -Mode consult -Providers "deepseek,groq-llama,cross-claude"`):**
o orchestrator responde `2 de 3 pernas responderam. Degradadas: cross-claude: error`, e o JSON traz
`"error": "401 (Unauthorized) ... invalid x-api-key"` vindo de
`plugins/cache/percus-tools/percus-review/<versao>/providers/cross-claude.ps1`. O marcador
`__PERCUS_NEEDS_CROSS_CLAUDE__`, que a skill `council-consult` documenta como gatilho para rodar a
perna via subagent Sonnet (passo 4), **não aparece** no stderr — o provider tentou a API direta com
chave inválida e reportou erro em vez de pedir o fallback.

**Efeito:** todo consult "3 membros" vira 2/3 silenciosamente se o agente não ler a lista
`respostas_degradadas`. O orchestrator avisa ("perna vazia NÃO conta como perspectiva"), então o
sinal existe — mas o caminho documentado de recuperação não é acionado por ele.

**Contorno usado:** rodar a 3ª perna à mão com a tool Agent (subagent `general-purpose`, modelo
Sonnet) com o mesmo prompt e instrução explícita de não usar ferramentas; consolidar manualmente.

**Mesma raiz no fact-check F3 do review R11 (mesmo dia):** `percus-review-auto.ps1` reporta
`fact-check: total=4 confirmado=0 infundado=0 parcial=0` e a tabela de audit traz todos os findings
como **unverified** com `400 Bad Request: Your credit balance is too low to access the Anthropic
API`. O F3 chama a API Anthropic com chave, e a conta de API não tem crédito — o operador usa o
**crédito mensal do login Claude Code**, não API. Efeito: o filtro de findings INFUNDADO não roda e
tudo chega cru; o agente tem que verificar cada finding à mão (foi o caso: 1 de 4 era falso).

**Segundo registro no mesmo dia (sessão Empresa-Milionaria, commit `54404fd` do kit):** perna nativa
devolveu **400** (não 401) com a mesma mensagem de crédito; fact-check saiu `total=0 confirmado=0
infundado=0` com todo finding `unverified` — e *"quem lê rápido lê `total=0` como review limpo"*.
Perna Sonnet completada à mão, escopada nos arquivos da sessão, salva em
`.deepseek/reviews/2026-09-12-1345-cross-claude.jsonl` — convenção de nome a seguir.

**PENDENTE (não corrigido):** decidir se `cross-claude.ps1` e o F3 devem (a) emitir o marcador de
fallback quando a chave falhar (401/400), ou (b) deixar de usar chave e sempre pedir subagent — que
roda na assinatura. O operador declarou: *"não é para usar API, é para usar meu crédito mensal"* —
aponta para (b). Registrado aqui para não ser reinvestigado do zero.
