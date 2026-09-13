## A linha nova perde para a antiga quando o seletor implícito ordena por `createdAt asc` {#linha-nova-perde-para-a-antiga-quando-o-seletor-implicito-ordena-por-createdat-asc}

`tags: multi-tenant, workspace, tenant ativo, membership, findFirst, orderBy, createdAt, prisma, insert sem efeito, seletor implicito, escrita silenciosa, R23`

**Sintoma.** Você insere a linha que liga um usuário ao tenant certo — membership,
participação, vínculo de organização — e **a tela não muda**. O `INSERT` volta com
sucesso, o `SELECT` de conferência mostra a linha lá, e mesmo assim o usuário
continua vendo o tenant errado (normalmente um vazio). Repetir o insert não ajuda;
um segundo par de olhos relê o código de permissão e não acha nada errado, porque
não é permissão.

**Causa raiz.** O app não tem seletor explícito de tenant. Quem decide qual tenant
está ativo é uma consulta implícita, escondida numa função de contexto:

```ts
prisma.workspaceMember.findFirst({ where: { userId }, orderBy: { createdAt: "asc" } })
```

`findFirst` + `orderBy createdAt asc` = **vence a associação mais antiga**. E o
usuário quase sempre já tem uma: o primeiro login costuma criar um tenant próprio
na hora (`ensureWorkspaceForUser`, `getOrCreateOrg`, o padrão tem vários nomes).
Essa linha auto-criada é mais velha que a sua, então a sua nunca é escolhida.

O que torna o caso traiçoeiro é que **nada falha**. Não há erro, não há permissão
negada, não há log. A escrita aconteceu de verdade; ela só não tem efeito sobre a
pergunta "qual tenant está ativo?", e essa pergunta é respondida em outro lugar do
que você editou.

**Diagnóstico.** Antes de escrever, ache quem responde "qual tenant está ativo" e
leia o `orderBy`. Procure por `findFirst` sem `orderBy` (aí vence a ordem do
índice, pior ainda) e por `orderBy: { createdAt: "asc" | "desc" }`:

```sh
rg -n "findFirst" --glob '**/*.ts' | rg -i "member|tenant|workspace|org"
rg -n "activeWorkspace|switchWorkspace|setTenant"   # vazio = nao ha seletor explicito
```

Se a segunda busca vier vazia, o seletor é implícito e a ordenação **é** a regra de
negócio.

**Solução.** Escreva a linha com o campo de ordenação **explícito**, posicionado do
lado que vence — não com o `now()` do default:

```ts
await prisma.workspaceMember.create({
  data: { workspaceId: ALVO, userId, role: "MEMBER", createdAt: new Date("2026-09-12T00:00:00Z") },
});
```

E **verifique reproduzindo a mesma consulta que o app faz**, não a que você acha
que ele faz — um `findFirst` com o mesmo `where` e o mesmo `orderBy`. Conferir "a
linha existe?" responde a pergunta errada; a certa é "quem vence agora?".

Alternativa mais destrutiva, só quando o tenant auto-criado é claramente lixo:
apagar a associação velha. Custa mais e não é reversível com um `DELETE`.

**Armadilha de método.** É tentador conferir o resultado pelo banco
(`SELECT * FROM membership WHERE user = ...`) e declarar feito. O banco vai
concordar com você e a tela vai continuar errada. A verificação que vale é a tela,
ou a consulta exata do app — foi só abrindo o navegador e vendo "1 conta conectada"
no lugar de "0 contas conectadas" que a correção virou fato.

**Família:** mesma classe de
[contexto de tenant não é prova de acesso](contexto-de-tenant-nao-e-prova-de-acesso.md)
— lá o contexto existe e não autoriza; aqui o vínculo existe e não seleciona. Nos
dois casos o erro é supor que escrever a linha certa basta, sem ler quem a lê.

**Ref:** LiliFlow, desbloqueio do App Review da Meta (2026-09-13). O revisor
precisava enxergar a conta do Instagram conectada; a associação foi criada e o
painel seguiu em "0 contas conectadas" até a linha nascer datada antes da
associação que o próprio primeiro login criara. `lib/workspace.ts:57` e
`lib/workspace-access.ts:38`, os dois com `findFirst orderBy createdAt asc`.
