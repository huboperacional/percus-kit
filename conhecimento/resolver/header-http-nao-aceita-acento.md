## Cabeçalho HTTP com acento ou travessão derruba a resposta com 500 {#header-http-nao-aceita-acento}

tags: http, next, middleware, encoding, 500

**Sintoma.** A rota devolve **500** em vez do status esperado, e o log traz:

```
TypeError: Cannot convert argument to a ByteString because the character
at index 24 has a value of 8212 which is greater than 255.
```

O número no fim é o code point do caractere ofensor: `8212` é `—` (travessão), `225` é `á`,
`231` é `ç`.

**Causa.** Cabeçalho HTTP é **ByteString** — só aceita bytes de 0 a 255 (latin-1). Qualquer
caractere fora disso lança na hora de construir a resposta, e o erro sobe como 500 genérico,
sem apontar o cabeçalho.

Acontece com texto que parece inofensivo porque é *só uma mensagem*:

```ts
// derruba a rota inteira
new NextResponse('Acesso restrito', {
  status: 401,
  headers: { 'WWW-Authenticate': 'Basic realm="Salas Flex — em construcao"' },
})
```

**Correção.** Nada de acento, travessão, aspa tipográfica ou emoji em valor de cabeçalho:

```ts
headers: { 'WWW-Authenticate': 'Basic realm="Salas Flex", charset="UTF-8"' }
```

Se o texto precisar mesmo de acento, codifique em RFC 8187 (`filename*=UTF-8''...`) — vale para
`Content-Disposition`, por exemplo.

**Onde costuma morder.** `WWW-Authenticate` (realm), `Content-Disposition` (nome de arquivo),
cabeçalho customizado com mensagem de erro em português, e header de redirect com query string
não codificada.

**Por que é difícil de achar.** O 500 aparece em **toda** rota que passa pelo middleware, então
parece falha geral da aplicação, não de uma string. A pista está no `index` do erro: conte os
caracteres até ele no valor do cabeçalho e o culpado aparece.

Visto em produção no Salas Flex, 2026-08-19: um travessão no realm do Basic Auth fez o site
inteiro responder 500 em vez de 401.
