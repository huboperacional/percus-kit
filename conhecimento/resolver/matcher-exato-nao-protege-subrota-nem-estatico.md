## Matcher de gate com path exato deixa passar sub-rotas e arquivos estáticos no mesmo prefixo {#matcher-exato-nao-protege-subrota-nem-estatico}

`tags: middleware, matcher, gate, otp, nextjs, public folder, arquivo estatico, subrota, defesa em camadas, review, deepseek`

**Sintoma:** ferramenta interna nova (`/monetizacao`, ADS4PROS) tinha o matcher do middleware
listando o path exato (`'/monetizacao'`) igual aos outros gates existentes no projeto
(`/comissoes`, `/paginas`). Passou no typecheck, no build, e a página em si redirecionava certo
pro `/acesso` sem sessão.

**Causa raiz:** a página tinha 6 botões "ver apresentação" apontando pra arquivos `.pptx` em
`public/monetizacao/*.pptx` — servidos pelo Next.js diretamente do filesystem, no MESMO prefixo de
path da rota gated. Matcher com o path exato (`'/monetizacao'`, sem `/:path*`) só intercepta
`GET /monetizacao`; uma request pra `GET /monetizacao/site.pptx` nunca passa pelo middleware, então
os 6 arquivos ficavam baixáveis por qualquer um com a URL, sem OTP nenhum — apesar da página em
volta estar corretamente protegida. Só apareceu numa revisão externa (DeepSeek), não em teste manual
(que só clicou nos elementos da própria página, nunca testou a URL do arquivo direto).

**Solução:** trocar o path exato por `'/monetizacao'` + `'/monetizacao/:path*'` no `matcher` do
`config`, e a condição de dentro do middleware pra `pathname === '/monetizacao' ||
pathname.startsWith('/monetizacao/')` — mesmo padrão que `/fechamento/:path*` já usava no mesmo
arquivo (só não tinha sido replicado pro gate novo). Confirmado em prod: `curl` direto no `.pptx`
sem cookie → 307 pro `/acesso`, igual à página.

**Lição:** ao copiar um padrão de gate existente (`pathname === '/rota'`) pra uma rota nova, checar
se essa rota tem QUALQUER coisa embaixo dela no mesmo prefixo — sub-rota dinâmica, ou (mais fácil de
esquecer) arquivo estático em `public/<mesmo-prefixo>/`. Se tiver, o gate precisa do `:path*`, não
só do path exato. Teste manual clicando na UI não pega esse buraco porque os links da própria
página já passam pela navegação normal do browser (com cookie já setado na sessão de teste) — só um
`curl` direto no asset, sem cookie, expõe.

**Ref:** ADS4PROS-Site, `middleware.ts` + `app/monetizacao/`, 2026-08-27. Achado por
`/percus-review:review` (DeepSeek) antes do commit, R11.
