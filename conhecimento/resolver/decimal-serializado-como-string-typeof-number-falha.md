## API serializa Decimal como STRING no JSON — `typeof x === 'number'` no frontend falha em silêncio {#decimal-serializado-como-string-typeof-number-falha}

tags: decimal, pydantic, fastapi, json, typeof, number, string, serializacao, frontend, dinheiro, preco, regressao, teste mockado diverge do real, e2e mock

**Sintoma:** tela mostra o preço/valor de TABELA em vez do valor real do contrato, mesmo com o
backend retornando o campo certo (`GET /billing/subscription` respondendo 200, sem erro). Card
"Status da assinatura" dizia R$19,90/mês pra quem paga R$11,94 (com cupom) — o MESMO bug já tinha
sido corrigido antes (fix documentado, deploy no ar), mas voltou a acontecer em prod.

**Causa raiz:** um `Decimal` num schema Pydantic (`valorMensal: Decimal | None = Field(alias=
"valor_mensal")`) serializa por padrão como **STRING** no JSON de resposta (`"valor_mensal":
"11.94"`, com aspas) — não como `number` — pra preservar precisão decimal. O código do frontend
fazia `typeof status?.valor_mensal === 'number' ? status.valor_mensal : null`, que é **sempre
falso** pra uma string, então tratava o valor como ausente e caía no fallback "sem valor cobrado"
(mostra o preço de tabela cheio, sem desconto). O bug NÃO aparecia nos testes porque o e2e mockava
a resposta com um NÚMERO literal JS (`valor_mensal: 11.94`), nunca exercitando o formato real que a
API devolve — teste verde, prod quebrado.

**Solução:** ao ler um campo Decimal/numérico vindo de uma API Python (Pydantic/FastAPI) no
frontend, NUNCA usar `typeof x === 'number'` como guarda de presença — o tipo declarado no
OpenAPI/TS gerado (`valor_mensal?: string | null`) já denuncia isso se for conferido antes de
escrever o guard. Checar `null`/`undefined` PRIMEIRO (`x == null`), só então coagir com `Number(x)`
(que aceita tanto string quanto number) — coagir direto sem o guard de nulidade troca o problema por
outro pior: `Number(null)` é `0` e `Number(undefined)` é `NaN`, reproduzindo a MESMA classe de
exibição errada (agora com "R$ 0,00" ou "NaN" em vez de mostrar o fallback correto). Padrão seguro:
`const valor = x != null ? Number(x) : null`. Se o mesmo campo já é lido em OUTRA tela do mesmo
projeto, verifique como ELA faz — muito provavelmente já tem o guard certo e é só replicar, em vez
de reinventar um novo que erra de novo. No teste, cubra os 3 formatos que a API pode mandar: string
válida (`"11.94"`), `null`, e ausente (`undefined`) — não só o que "faria sentido" em JS.

**Ref:** Família Milionária, sessão 2026-08-07 — `resumoPreco()` em
`familia-frontend/src/app/assinatura/page.tsx`, commit `9a3c684`. A tela irmã
`/assinatura/confirmacao` já tinha `Number(sub.valor_mensal)` certo desde 25/07 (linha 193) — nunca
foi replicado em `/assinatura`. Achado navegando a tela ao vivo em prod via Playwright MCP (não por
review de código) — API respondendo 200, zero erro de console, e mesmo assim preço errado. Fix
verificado chamando `fetch()` direto no endpoint pra ver o JSON cru antes de mexer no código
(`"valor_mensal":"11.94"`, com aspas — a prova).
