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

**Causa raiz (achada 2026-09-12, `council-orchestrator.ps1` linha ~326):** a decisão de usar a API
em vez do subagente é tomada **antes de tentar**, olhando apenas se `ANTHROPIC_API_KEY` *existe* —
nunca se a chave *funciona*. Quando existe, o orchestrator zera `$wantsCrossClaude` e o bloco que
emite `__PERCUS_NEEDS_CROSS_CLAUDE__` fica **inalcançável**. Chave presente e quebrada = perna morta
em silêncio. É o mesmo erro de classe que o canon combate noutro lugar: decidir pela **presença** do
insumo em vez do **resultado** da operação — medir delta em vez de tamanho.

**Corrigido em 6.46.0**, em três partes:

1. **Fallback pelo resultado.** O marcador passou a ter dois pontos de emissão: o antigo (chave
   ausente) e um novo, **depois da coleta** — se a resposta de `cross-claude` voltou com
   `status != ok`, o marcador sai com o prompt. Extraído para `Write-CrossClaudeMarker` /
   `emitir_marcador_cross_claude`, porque bloco duplicado divergiria no primeiro conserto e o
   agente depende do formato exato para achar o prompt.
2. **`PERCUS_CROSS_CLAUDE=subagent`** força o caminho do subagente mesmo com chave boa — é a
   alavanca para quem paga assinatura e não API. Sem ela, a única forma seria apagar a variável do
   ambiente, que outros componentes usam. `auto` (default) tenta a API e cai no subagente se falhar.
3. **Resumo do F3 honesto:** `nao-verificado=N` entrou na linha de resumo, e quando todos os
   findings ficam sem verificação a mensagem diz isso em voz alta. Antes saía
   `total=4 confirmado=0 infundado=0 parcial=0` — lido como "review limpo" por duas sessões
   diferentes no mesmo dia.

**Prova:** `plugin/percus-review/tests/council-fallback-cross-claude.tests.ps1` (**11 casos**: 8 em
PowerShell com provider falso devolvendo o erro real de crédito, mais 3 que rodam o `.sh` de verdade
— a paridade entre as duas implementações é afirmada por artefato, não por texto) e
`fact-check-resumo-honesto.tests.ps1` (6 casos, função recortada do script real por marcador). O RED
do segundo foi provado rodando o teste contra a versão anterior via `git show HEAD:` — ela imprime a
linha enganosa e nenhuma menção a não-verificado.

**Discriminante que sobrevive:** guarda que escolhe caminho pela **presença** de um insumo nunca
descobre que o insumo é ruim. Se há um plano B, a condição de cair nele tem que ser o **resultado**
da tentativa, não a existência da configuração.
