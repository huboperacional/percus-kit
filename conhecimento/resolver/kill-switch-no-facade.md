## Kill-switch cujo gate mora nos call-sites cobre menos do que promete — e o docstring vira mentira {#kill-switch-no-facade}

`tags: kill-switch, feature flag, gate, call-site, facade, keyword-only sem default, fail-closed, cobertura parcial, docstring mentira, whatsapp proativo, cold outreach, guard-rail, inspect.signature, funcao fantasma, 409, silencio declarado`

**Sintoma:** kill-switch de envio proativo de WhatsApp (`WA_PROACTIVE_ENABLED`) deployado, flag confirmada `false` em prod, log provando quarentena no startup. Mesmo assim, um clique em `/admin/engajamento/disparar` dispararia **cold outreach em massa** — exatamente o perfil que derruba o device. O docstring dizia "nada é iniciado por nós"; a v1 gateava **2 de 8** remetentes.

**Causa raiz:** o gate foi implementado nos **call-sites**, um por um. Isso torna a cobertura uma função da memória de quem escreve: remetente novo **nasce sem gate** e nada avisa. Pior que não ter switch — a v1 produzia confiança falsa em quem lia o docstring. Um inventário achou 14 remetentes proativos com zero switches.

**Solução (3 camadas, nessa ordem de valor):**
1. **Gate no FACADE, com a decisão obrigatória.** `sendMessage(..., *, proativo: bool)` **keyword-only SEM default**. Sem default é o ponto todo: default `False` faz remetente novo nascer sem gate de novo (a falha original); default `True` deixa o bot **mudo pra usuário real** no primeiro esquecimento. Sem default, esquecer é `TypeError` **alto**, pego pela suíte antes de prod. "Fail-closed" aqui é sobre a DECISÃO ser obrigatória, não sobre bloquear por omissão.
2. **Guard-rail na SUPERFÍCIE do facade, não só nos call-sites.** Validar "todo call-site declarou" deixa o buraco simétrico: uma `sendImage()` nova **no próprio facade** nasce sem gate e todos os testes ficam verdes. Teste por `inspect.signature`: toda corrotina de envio precisa do parâmetro; isenção (`checkNumberExists`) só explícita numa allowlist.
3. **Provar o guard-rail com função fantasma.** Criar o remetente/função que deveria ser pego, rodar (tem que falhar **nomeando-o**), remover. Sem isso você tem um teste que passa, não um teste que protege — foi assim que se descobriu que o padrão antigo (`\b(?:evo|wa_client)\.send…`) devolvia `False` pra `gowa_client.sendMessage`.

**Efeito colateral a decidir conscientemente:** classificar honestamente revela envios que "pareciam inbound" mas são reach-out a terceiro — ex.: escalação pro número de SUPORTE nasce de um inbound, mas quem recebe **não escreveu pra nós**. Marcar como proativo silencia a escalação durante a quarentena; aceitável só porque o registro (`WhatsappLog`) é gravado **antes** e independe do envio. Decida e documente, não deixe implícito.

**Regra geral:** *silêncio de kill-switch precisa ser DECLARADO.* Um endpoint que devolve `200` com zeros na quarentena faz a UI dar toast **verde** de sucesso — a mitigação escrita em `resultado["detalhes"]` era código morto (o front nunca renderizava). Use **409 + `detail`**, e conte a verdade a quem depende do envio (quem adicionou um membro precisa saber que a pessoa **não** foi avisada).

**Ref:** Família Milionária, 2026-07-16 → 19. Commits `25e0a69` (v2 nos call-sites) → `04a5485` (facade). Memória: `incident_2026_07_16_device_ban_numero_queimado`.
