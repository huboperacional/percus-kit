## Integração externa OPCIONAL desarmada não grita: silêncio é idêntico a "ninguém usou ainda" {#integracao-opcional-desarmada-nao-grita}

`tags: best-effort, fail-silent, env vazia, bridge, webhook, billing, afiliado, startup check, consequencia observavel, integracao opcional`

Integração que **não pode derrubar o produto** costuma ser escrita como best-effort: se a variável está vazia, retorna cedo e segue a vida. A decisão está certa — canal opcional não pode impedir o boot. O que ela cria é um estado onde **desarmada e "funcionando, sem uso ainda" produzem exatamente os mesmos sinais**: nenhum log de erro, nenhuma métrica, nenhum teste vermelho.

O caso: produto no ar, vendendo, com duas integrações apagadas em produção e **nada dizendo**.

| Integração | Estado | Como falhava |
|---|---|---|
| Bridge de comissionamento | `INGEST_URL` e `INGEST_KEY` vazias | `forwardEvent` retorna `False` na 1ª linha. A pessoa indica, o cliente assina, a comissão **nunca existe** |
| Gateway de pagamento | `ENV=test`, zero `PLAN_ID` | O produto anuncia preço e **não tem como receber** |

**Solução: um registro das integrações opcionais, cada uma declarando a CONSEQUÊNCIA OBSERVÁVEL de estar desarmada, e o startup anunciando o estado de cada uma.** Desarmada continua não derrubando o boot — só para de ser secreta.

⚠️ **`consequencia` descreve o que o USUÁRIO observa, não a causa técnica.** "A variável está vazia" não ajuda ninguém às 3 da manhã; "o afiliado não recebe porque a conversão nunca é registrada" manda a pessoa ao lugar certo.

⚠️ **Meia configuração é o estado mais perigoso, porque PARECE de pé.** URL preenchida e chave vazia se comporta como nada preenchido, e quem inspecionar o ambiente vê a URL e conclui que está armado. A guarda exige **todas** as variáveis que o caminho real exige.

⚠️ **`"   "` é truthy.** Espaço sobrando em arquivo de env passa por `if not valor` e reporta armado estando morto. Teste por `.strip()`.

⚠️ **Segredo tipado (`SecretStr` e similares) não é string.** Inspecionar via `model_dump()` devolve o **objeto**. No pydantic v2 dá certo por acaso — `SecretStr("")` é falsy e `str()` dele é `""`, enquanto o preenchido vira `"**********"` (truthy). **Correção acidental precisa de teste**, senão uma atualização da lib faz a guarda reportar ARMADA uma integração sem chave, que é o silêncio de volta.

⚠️ **Virar para `live` sem a chave de `live` merece caso próprio.** Não é "faltou configurar": alguém decidiu cobrar de verdade. A chave de teste preenchida **não salva**, porque o resolvedor escolhe pelo ambiente e nem consulta a outra.

**A trava não é o `if`; é estrutural.** Integração nova que nasça sem declarar consequência **derruba a suíte** — mesmo padrão de "rota nova sem classificação de tenancy derruba a suíte". Sem isso, o próximo canal repete o defeito e o registro vira decoração.

**Vizinhos:** [#feature-sobre-flag-off-nasce-morta](feature-sobre-flag-off-nasce-morta.md) — lá a feature nasce morta atrás de flag; aqui ela nasce viva e o canal é que está mudo. [#guarda-muda-sem-a-ferramenta-que-usa-pra-falar](guarda-muda-sem-a-ferramenta-que-usa-pra-falar.md) — a guarda perde a voz; aqui a integração nunca teve.

**Ref:** Empresa Milionária, 2026-08-17. Achado medindo `printenv` dentro do container de produção, não lendo código — nenhum teste, log ou métrica apontava para lá. O precedente que existia (a chave de consumer do auth-service, que já gritava no startup) estava certo e **não tinha teste**, então nada obrigava a integração seguinte a seguir o padrão.
