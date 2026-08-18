## Trocar um modelo por um de RACIOCÍNIO esvazia todo consumidor que fixou `max_tokens` pequeno {#troca-para-modelo-de-raciocinio-esvazia-teto-de-tokens}

`tags: modelo de raciocinio, reasoning_tokens, max_tokens, gpt-oss, groq, troca de modelo, fact-check-triage, conselho, resposta vazia, content vazio, status truncated, regex de formato, markdown no veredito, R23`

**Sintoma:** depois de trocar o id de um modelo, a chamada volta `200 OK`, com `usage` preenchido
e `completion_tokens` batendo exatamente no teto — mas `content` vem **string vazia**. Nenhum erro,
nenhum 404, nenhuma exceção. O consumidor a jusante classifica tudo como "não verificado" e segue.

**Causa raiz:** o modelo novo é de **raciocínio** e o antigo não era. Ele gasta tokens pensando
*antes* da primeira letra da resposta, e esses tokens saem do **mesmo** orçamento de `max_tokens`.
Medido em 2026-08-18 trocando `llama-3.3-70b-versatile` → `openai/gpt-oss-120b` na perna Groq do
conselho, com o mesmo prompt de triagem:

| `max_tokens` | `reasoning_tokens` | `content` | `status` |
|---|---|---|---|
| 64 | 62 | **vazio** | `empty` |
| 128 | 126 | **vazio** | `empty` |
| 256 | 160 | presente | `truncated` |
| 1024 | 135–270 | presente | `ok` **ou** `truncated` |

O raciocínio **varia de chamada pra chamada** (62 a 270 tokens no mesmo prompt), então não existe
teto "certo" — existe teto com folga. E `1024` ainda truncou em 1 de 4 amostras.

🔑 **A lição não é "aumente o teto". É que a troca de modelo quebra contrato em três lugares que
ninguém pensa em olhar, todos falhando ABERTO e CALADO:**

1. **Teto de tokens fixado no consumidor.** Quem chamava com `-MaxTokens 64` porque a resposta útil
   tinha uma linha agora recebe vazio sempre. O teto foi dimensionado pra resposta, não pro
   pensamento.
2. **Guarda de `status -eq "ok"`.** Consumidor que lê só a **primeira linha** não precisa da
   resposta inteira, mas rejeita `truncated` e joga fora veredito perfeitamente bom.
3. **Regex de formato.** O modelo novo responde `**SUSPEITA**` (negrito markdown) e acentua
   (`PLAUSÍVEL`). Padrão antigo `^\s*PLAUSIVEL` não casa nem o asterisco nem o acento — tudo cai em
   "formato inesperado". Normalize (tire `*_\`#>~`, use `.` no lugar do acento) **antes** de casar.

⚠️ **Correção de uma heurística que este kit já registrou e que a troca invalidou.** O verbete
[[groq-llama-3-3-decomissionado-404]] diz que latência de três dígitos é a assinatura de perna
morta ("perna que pensa demora dezenas de segundos"). Com `gpt-oss-120b` a perna **saudável**
responde em **636–789 ms**. A heurística de latência morreu junto com o modelo antigo: hoje o sinal
confiável é `status` + `content` não-vazio, não o relógio.

🔴 **Onde isto esconde melhor: no caminho que existe pra impedir erro.** Aqui o consumidor quebrado
era o `fact-check-triage`, que é o pré-requisito da skill `council-consult` antes de escalar finding
crítico. Com ele devolvendo `unverified` em 100% dos findings, a trava anti-"conselho ratifica
premissa não verificada" continuava *rodando* e *não travava nada*. Ferramenta de segurança que
falha aberta é pior que ausente, porque o relatório continua parecendo completo.

⚠️ **Armadilha de stream, no PowerShell:** o wrapper escreve aviso no **stderr**, e a chamada usava
`2>&1`. O `ErrorRecord` entra como elemento `[0]` do array e o `ConvertFrom-Json` morre no primeiro
caractere dele — sintoma "excecao ao chamar wrapper", que também vira `unverified` calado. Filtre
`ErrorRecord` e pegue a linha que começa com `{` antes de parsear. A versão `.sh` irmã **não** tinha
o defeito: `capture_output=True` separa os streams. Mesma lógica, dois idiomas, um bug só num deles.

**Solução (a que foi aplicada):**
1. Teto do consumidor de `64` → `1024`. Custa pouco: o volumoso é o raciocínio, e a resposta útil
   continua com uma linha. A `openai/gpt-oss-120b` sai por $0.15/$0.60 por 1M — mais barata que o
   Llama que substituiu ($0.59/$0.79), então o teto maior ainda deu economia líquida.
2. Aceitar `truncated` junto com `ok` **onde o consumidor lê só a primeira linha**.
3. Normalizar ênfase/acento antes de casar o veredito, e cair pra **próxima linha não vazia** quando
   o motivo não vem na mesma linha do veredito (senão a auditoria grava veredito com `reason` vazio).
4. Filtrar `ErrorRecord` antes do `ConvertFrom-Json`.

**Alternativa não aplicada, se o custo incomodar:** a Groq aceita `reasoning_effort` (`low`/`medium`/
`high`) nos modelos `gpt-oss`. Baixar pra `low` corta o raciocínio na origem em vez de pagar teto
alto. Não foi feito aqui porque exigiria novo parâmetro no wrapper — considere se o volume crescer.

**Ref:** medido em 2026-08-18 no `percus-kit`, canon 6.38.0, com a chave Groq real
(`GET /openai/v1/models` + 9 chamadas de chat). Relacionado:
[[groq-llama-3-3-decomissionado-404]].
