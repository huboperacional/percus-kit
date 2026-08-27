## Antes de suspeitar de vazamento por página real, confira se o spam nem carrega JS — bate direto na API {#spam-bate-direto-na-api-sem-passar-pela-pagina}

`tags: spam, bot, honeypot, formulario, api route, atribuicao, tor, user-agent, referer, diagnostico, anti-spam`

**Sintoma:** cliente reportou flood de notificação WhatsApp de "novo lead" com nome/empresa/telefone
óbvios de bot (string aleatória, e-mail com pontuação estranha tipo `d.a.n.n.y.v.e.n01@gmail.com`).
Pergunta natural: "de qual página do site isso está vindo?" — supondo que algum bot achou o
formulário público e está preenchendo via browser automatizado.

**Diagnóstico (sem precisar de ferramenta nova):** grep no log estruturado que a rota já emitia
(`console.log('[contact-form]', {..., request: {ip, user_agent}})`). Três sinais, todos já
disponíveis sem instrumentar nada:
1. **User-agent idêntico** em requests de IPs completamente diferentes — tráfego humano real varia
   (mobile/desktop, browsers, versões); UA fixo é assinatura de script.
2. **IPs em ranges de saída Tor/proxy conhecidos** (ex. `185.220.100.0/24`).
3. **Campo de atribuição client-side sempre vazio** — se o site tem um tracker que só roda depois
   que a página carrega e executa JS (aqui: `<AttributionTracker />` que lê `localStorage`/UTM), e
   ele nunca aparece preenchido, é porque a requisição nunca passou por um browser real rendendo a
   página — foi POST direto na API.

**Conclusão:** não veio de nenhuma página — o bot nunca visitou `/contato`, só descobriu (ou
adivinhou por scan genérico de padrão comum) o endpoint `POST /api/contact` e manda JSON direto,
satisfazendo só o mínimo de validação Zod (comprimento mínimo de string). Isso muda a resposta:
"reforçar a página" não ajuda (o bot nunca a carrega); a defesa tem que estar na API.

**Fix aplicado (camada 1, sem dependência nova):** honeypot (campo invisível, nome sem sentido tipo
`contact_me_by_fax_only` — não `website`, pra não ser autopreenchido por gerenciador de senha —
com `data-lpignore`/`data-1p-ignore`) + timestamp de mount do form comparado ao timestamp do submit,
rejeitando <2.5s. Bot que nunca roda JS/nunca espera falha nos dois automaticamente. Resposta de
sucesso falsa (não avisa o bot que foi pego) + log server-side pra diagnóstico futuro (`referer`
agora também capturado, pra não faltar esse dado na próxima vez).

**Lição:** antes de instrumentar algo novo pra responder "de onde vem esse spam", primeiro confira o
que o log ATUAL já registra (IP, UA, campos client-side que deveriam estar preenchidos e não estão)
— geralmente já tem sinal suficiente pra provar "nem passou pela página" sem precisar de nenhuma
ferramenta nova.

**Ref:** ADS4PROS-Site, `app/api/contact/route.ts` + `lib/attribution-schema.ts`, 2026-08-06/07.
