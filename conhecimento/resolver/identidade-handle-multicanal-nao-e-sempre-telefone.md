## `identidade["handle"]` de auth multi-canal não é sempre telefone — função downstream que assume isso vira 500 ou concede RLS por valor escolhido pelo chamador {#identidade-handle-multicanal-nao-e-sempre-telefone}

tags: auth multi-canal, otp, handle, row level security, whatsapp, email, canal, normalizeWhatsapp,
identidade autenticada, guc, session context, adr-0009

**O padrão que engana:** um dependency de auth (`getIdentidadeAutenticada` ou equivalente) devolve
um dict genérico `{"authIdentityId", "canal", "handle"}` pra suportar login por mais de um canal
(WhatsApp OTP, e-mail OTP). O `handle` é normalizado **condicionalmente**, por canal, no próprio
dependency: telefone vira E.164, e-mail vira lowercase — cada canal recebe o tratamento certo pro
formato dele.

**O buraco:** uma função nova, mais abaixo na pilha (ex.: uma que prova a posse do WhatsApp e seta
um GUC de sessão pra RLS), recebe só `identidade["handle"]` como string solta — sem o `canal`
junto — e assume que aquilo É um telefone, porque o único chamador vivo NO MOMENTO em que foi
escrita só existia pro canal WhatsApp. A função até faz a coisa certa por dentro (chama a mesma
normalização de telefone antes de confiar no valor — boa prática deliberada, documentada como "não
confia que quem chamou já normalizou"). O problema não é a normalização em si: é que ela é
aplicada **sem saber que o valor pode não ser um telefone**.

No dia em que essa função é ligada num ponto do fluxo que os DOIS canais atravessam (ex.: uma rota
de "primeiro acesso" chamada depois de QUALQUER OTP bem-sucedido, independente de canal), o
`handle` de quem logou por e-mail chega ali como e-mail cru:

```python
# normalizeWhatsapp real, escrita pra aceitar variacoes de formato de telefone:
digits = "".join(c for c in raw if c.isdigit())
if len(digits) == 11: return f"+55{digits}"
...
raise ValueError(...)  # só se o total de dígitos não bater com formato nenhum conhecido
```

Duas consequências, nenhuma óbvia sem rastrear os DOIS canais até o mesmo ponto de código:

1. **E-mail sem dígitos suficientes** (`voce@email.com`) → a extração de dígitos dá string vazia
   ou curta demais → `ValueError` não tratado → se não houver handler específico, cai no handler
   global genérico → **500** onde antes (sem essa função no caminho) o fluxo respondia limpo
   (ex.: 404 "sem cadastro").
2. **E-mail com dígitos suficientes por coincidência** (`5511987654321@dominio.com`,
   `contab5567920024429@x.com`) → a extração produz um número de telefone **válido segundo o
   formato**, mas o dígito vem do CHAMADOR (é literalmente o texto que ele digitou como e-mail),
   não de prova nenhuma de posse daquele telefone. Se a função seta um GUC de sessão usado por uma
   política RLS ("quem provou este número pode ler tal linha"), o chamador acabou de conceder a si
   mesmo a leitura associada a um número que ele nunca provou — só ESCOLHEU, embutido no e-mail.

**Por que passa por review sem ser pego:** cada peça isolada está correta e bem revisada — o
dependency normaliza certo por canal; a função nova normaliza por dentro (defesa em profundidade
deliberada); o teste de wiring roda sob canal fixo (o único que existia quando a task foi escrita)
e passa verde. O buraco só existe na COMPOSIÇÃO: ninguém, numa review task-a-task, perguntou "essa
chamada roda pros dois canais, e faz sentido pros dois?" — só uma revisão que olha o fluxo inteiro
(ponta a ponta, através de TODOS os canais reais, não só o canal que motivou a task) alcança isso.

**Correção:** o filtro certo não é "normalizar/validar o valor melhor" (isso só troca 500 por 4xx
mais bonito, ainda concede o GUC pra um e-mail com dígitos parecidos). É **checar o canal antes de
chamar a função**, no ponto de wiring — a prova só é válida pro canal que ela prova:

```python
if identidade["canal"] == "whatsapp":
    await provarWhatsapp(session, identidade["handle"])
```

**Regra prática pra generalizar:** toda vez que um dependency de auth devolve um campo genérico
(`handle`, `identifier`, `subject`) que representa coisas semanticamente diferentes por canal,
qualquer função downstream que consome esse campo — especialmente uma que alimenta uma decisão de
autorização (RLS, feature flag por identidade, rate limit por identidade) — precisa do `canal`
junto, não só do valor. "Já recebo só o dado validado" (princípio tipo ADR-0009, "não confie em
corpo/query, só em identidade já autenticada") garante que o VALOR veio de alguém autenticado —
não garante que o valor **significa o que a função downstream assume que significa**.

**Ref:** Empresa Milionária, Frente A (primeiro acesso via WhatsApp provado), achado na revisão
final do branch inteiro (não em nenhuma review por task), 2026-08-26. `app/core/dependencies.py`
(`getIdentidadeAutenticada`), `app/core/tenant_context.py` (`provarWhatsapp`),
`app/modules/pj/rotas_convite.py` (`primeiroAcesso`). Corrigido em `f500f6d`.
