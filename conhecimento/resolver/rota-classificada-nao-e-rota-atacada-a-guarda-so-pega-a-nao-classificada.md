## Rota classificada não é rota atacada: a guarda de cobertura só pega a NÃO classificada, e a rota nova nasce isolada por convenção {#rota-classificada-nao-e-rota-atacada-a-guarda-so-pega-a-nao-classificada}

`tags: multi-tenant, isolamento, harness, rota nova, cobertura, guarda de cobertura, 404 identico, RLS, review, pre-mortem, R23`

**Sintoma:** o projeto tem um harness de isolamento que ataca cada rota com o recurso da empresa
vizinha e exige **404 idêntico**. Tem também uma guarda de cobertura — `test_toda_rota_registrada_esta_classificada`
ou equivalente — que reprova quem esquecer de classificar a rota nova. Rota nova entra, é
classificada, a suíte fica verde. E **nunca é atacada**: o isolamento dela é convenção, não medida.

**Por que a guarda não pega:** ela mede *classificação*, não *ataque*. As duas listas são
diferentes — uma diz "esta rota existe e tem escopo", a outra diz "esta rota recebe corpo e path da
vizinha". Classificar satisfaz a guarda e **sai da vista**: nenhum teste reprova uma rota
classificada e ausente da lista de ataque, porque a ausência é indistinguível de "esta rota não
precisa de ataque".

### A reincidência é o dado interessante

**Empresa Milionária, 2026-09-15.** Um plano de implementação **citava essa mesma lição em voz
alta** numa das suas tasks (*"classificar não é submeter — conferir que a contagem de ataques
subiu"*) e, três tasks adiante, criou um endpoint novo declarando só o escopo e a alçada. O
pre-mortem de segunda rodada pegou:

> a rota pode ficar classificada e nunca atacada, silenciosamente.

🔑 **Saber a regra não a aplica.** Ela vale por **rota**, não por plano: cada rota nova é uma
decisão nova, e o lugar onde a lição funciona é o **Step da task que cria a rota**, não um
parágrafo de princípios no topo. Lição que mora longe do ponto de uso não é aplicada — é citada.

### O que torna a task correta

Três coisas, e a terceira é a que fecha:

1. **Entrar nas listas de ataque** (o par "recurso da vizinha por parâmetro de path" + "controle da
   listagem", ou equivalente do projeto), não só na classificação de escopo.
2. **Corpo de ataque legítimo** — corpo que a regra de negócio recusaria por outro motivo (campo
   faltando, valor inválido) deixa o harness verde **sem medir isolamento**: a recusa vem da
   validação, não da tenancy.
3. **Conferir que a CONTAGEM de ataques subiu**, com o número antes e depois no relato. É o único
   passo que distingue "entrei na lista" de "a lista me exercitou". Sem ele, um erro de digitação
   no nome do parâmetro tira a rota do ataque em silêncio.

```
# antes:  N ataques coletados
# depois: N+2 (path da vizinha, corpo com id da vizinha)
```

### A guarda que resolve a classe

A guarda de cobertura que faltava não é "toda rota classificada", e sim **"toda rota de escopo de
tenant aparece na coleta de ataques"** — uma varredura que cruza as duas listas e nomeia quem está
numa e não na outra. Enquanto ela não existir, a conferência da contagem é o substituto manual, e
precisa estar escrita como passo obrigatório de toda task que cria rota.

### Verbetes relacionados

- [[harness-de-ataque-com-corpo-incompleto-da-verde-falso]]
- [[plano-nao-emenda-spec-a-excecao-volta-a-spec]]
