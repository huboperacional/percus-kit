## Um `else` que afirma a causa mais comum mente exatamente no caso raro {#else-que-afirma-a-causa-mais-comum-mente-no-caso-raro}

`tags: mensagem de erro, diagnostico, causa raiz, else generico, default, api de terceiro, meta, graph api, google ads, hubspot, ghl, ux de erro, funcao pura, testabilidade, rota, acusacao errada, degradacao honesta`

**Contexto:** conectar uma conta de anúncio devolvia *"Conta não acessível pelo token global da
agência (verifique se foi atribuída ao BM): Conta com status 3 (esperado 1=ACTIVE)"*. As duas
metades se contradiziam — o token **lia a conta inteira** (nome, moeda, saldo, campanhas). O que
bloqueava era o estado financeiro da conta. A mensagem mandou o operador investigar Business
Manager, onde não havia nada errado.

**Causa raiz:** o probe devolvia `{ ok: false }` para causas diferentes **sem dizer qual**, e o
chamador carimbava a mesma dica em cima de todas:

```ts
const hint = tokenProprio ? "Token inválido" : "Conta não acessível... verifique o BM";
return `${hint}: ${probe.error}`;
```

**O que torna isto uma armadilha e não um bug simples:** consertar a causa que apareceu **não
resolve**. Ao tratar a primeira como exceção e deixar o resto no `else`, o mesmo defeito
reapareceu em **quatro** causas seguintes — token válido apontando outra conta, timeout de rede,
erro do provedor sem código, e rate limit. Todas saíam como *"Token inválido"*.

**Solução — inverta a direção do default:**

```ts
switch (probe.reason) {
  case "status":
  case "conta_diferente": return probe.error;                 // já se explicam sozinhas
  case "token":           return `${dicaDeTokenOuBM}: ${probe.error}`;
  default:                return `Não foi possível validar: ${probe.error}`;  // ⬅️ neutro
}
```

🔑 **A dica específica é a EXCEÇÃO; o texto neutro é o DEFAULT.** Assim, uma causa nova que alguém
esqueça de tratar degrada para uma frase honesta em vez de virar acusação errada. O custo de
esquecer deixa de ser *"o sistema culpa a coisa errada"* e passa a ser *"o sistema é vago"* — e
vago é recuperável; acusação errada faz a pessoa investigar o lugar errado por horas.

**Corolário sobre ONDE a lógica mora:** a escolha da frase estava dentro da rota HTTP, junto de
sessão, RBAC e ORM. Nenhum teste alcançava aquele ponto sem levantar tudo isso — **e foi por isso
que o defeito sobreviveu**. Mover a decisão para uma função pura foi parte do conserto, não um
extra de estilo. Regra que se generaliza: *decisão de produto que mora onde o teste não alcança
vai errar em silêncio.*

**O teste que guarda a decisão** não é o das causas conhecidas — é o da **causa desconhecida**:

```ts
expect(mensagemDeRecusaMeta({ error: "algo novo" })).not.toContain("Token inválido");
```

Sem ele, o próximo `reason` reabre o defeito e todos os outros testes continuam verdes.

**Onde procurar o mesmo padrão:** qualquer tradução de falha de terceiro para frase acionável —
Google Ads, HubSpot, GHL, gateways de mensagem. Procure por `else` que afirma causa, e por
`catch` que devolve erro sem classificar.

**Relacionadas:** `#validador-confirma-string-nao-sistema` ·
`#job-morre-no-import-e-o-except-nao-bloqueante-esconde-por-dias`
