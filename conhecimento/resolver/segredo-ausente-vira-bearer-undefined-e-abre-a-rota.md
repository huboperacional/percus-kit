## Segredo ausente vira `Bearer undefined` literal e abre a rota para qualquer um {#segredo-ausente-vira-bearer-undefined-e-abre-a-rota}

`tags: autenticacao, cron, bearer, falha aberta, fail-open, env ausente, timingSafeEqual, next.js, route handler, R23`

**Sintoma:** nenhum. É o pior tipo — a rota parece protegida, o código de autenticação está lá e
lê bem, e nada quebra em teste. A rota só está aberta quando uma variável de ambiente falta.

**Reprodução real** (LiliFlow, 2026-09-12): quatro rotas de cron, todas com este padrão herdado uma
da outra:

```ts
const authHeader = request.headers.get("authorization");
const cronSecret = process.env.CRON_SECRET || process.env.NEXTAUTH_SECRET;

if (authHeader !== `Bearer ${cronSecret}`) {
  return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
}
```

Sem nenhuma das duas variáveis no ambiente, `cronSecret` é `undefined`, a interpolação produz a
string `"Bearer undefined"`, e **quem mandar exatamente esse header passa**. Uma das rotas apagava
dado por política de retenção.

**Por que passa despercebido:** o código tem cara de correto — há comparação, há 401, há segredo. O
defeito não está na lógica, está no que a interpolação faz com `undefined`. E em ambiente de
desenvolvimento as variáveis normalmente existem, então o caminho vulnerável nunca é exercitado. É
configuração faltando que vira buraco de autenticação, não bug de código.

**Conserto — falhar fechado, e comparar em tempo constante:**

```ts
export function authorizeCronRequest(request: NextRequest): NextResponse | null {
  const secret = process.env.CRON_SECRET || process.env.NEXTAUTH_SECRET;
  if (!secret) return unauthorized();          // <- sem segredo, ninguem entra

  const header = request.headers.get("authorization");
  if (!header) return unauthorized();

  const a = Buffer.from(header);
  const b = Buffer.from(`Bearer ${secret}`);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return unauthorized();

  return null;
}
```

O comprimento vaza (a checagem vem antes do `timingSafeEqual`, que exige buffers de tamanho igual),
o que é aceitável: saber o tamanho de um segredo não o revela.

**Teste que prova o conserto** — é o teste que ninguém escreve, porque testa a ausência de config:

```ts
it("sem segredo no ambiente, recusa ate o header literal 'Bearer undefined'", () => {
  delete process.env.CRON_SECRET;
  delete process.env.NEXTAUTH_SECRET;
  expect(authorizeCronRequest(pedido("Bearer undefined"))?.status).toBe(401);
});
```

**Onde mais procurar a mesma forma:** qualquer lugar que interpole variável de ambiente dentro de
uma string comparada para autorizar. Webhook com token na querystring, header de serviço interno,
`X-API-Key`. O grep que acha:

```
grep -rn 'process\.env\.[A-Z_]*}\?`' --include=*.ts | grep -iE 'bearer|token|secret|key'
```

**Regra geral:** comparação de segredo tem que ter um passo anterior perguntando se o segredo
existe. `if (!secret) return 401` é uma linha e é a diferença entre falhar fechado e falhar aberto.

Relacionado: [[corrigir-a-classe-num-metodo-nao-a-corrige-no-vizinho]] — aqui o padrão estava
copiado em quatro rotas, e consertar só a que o lint apontou teria deixado três abertas.
