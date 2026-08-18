## O enriquecedor que "ignora" a entrada vazia APAGA a intenção de remover {#enriquecedor-ignora-vazio-e-apaga-intencao-de-remover}

`tags: PATCH parcial, contrato de API, enriquecedor, valor vazio, limpar campo, camada intermediaria, teste de unidade cego, intencao de remover`

**Classe:** contrato de PATCH parcial atravessando uma camada que valida/enriquece.

**Sintoma:** o operador clica "Limpar", confirma o aviso de consequência, lê "salvo" — e o valor
continua gravado. Nenhum erro, nenhum log, nenhum alerta. O teste de unidade da tela passa (ele
checa o corpo que a tela MONTA) e o do backend passa (ele checa o corpo que o backend RECEBE).

**Causa raiz:** entre os dois existe um gate que valida cada entrada contra um serviço externo e
devolve um mapa NOVO, só com o que validou:

```ts
for (const type of TIPOS) {
  const input = conversions[type];
  if (!input) continue;        // <-- `null` cai aqui junto com `undefined`
  enriched[type] = await validar(input);
}
return { conversions: enriched };   // o `null` sumiu do mapa
```

`null` e "não enviado" são falsy do mesmo jeito, então o `continue` trata os dois igual. Só que
eles são **opostos** num PATCH parcial: `{tipo: null}` significa *apague*, e a ausência da chave
significa *não toque*. Ao devolver `enriched`, o gate converte um em outro — e o merge por tipo do
destino, que preserva o que não veio, faz exatamente o que foi mandado.

**Regra:** num caminho de PATCH parcial, separe **remoções** de **entradas a validar** ANTES do
laço, valide só as segundas, e re-junte as duas na saída. Remoção não passa por validação (não há o
que validar) nem por pré-requisito de validação (aqui, exigir `customer_id` para poder apagar era
pedir a conta do serviço externo para desfazer).

```ts
const paraRemover = {}, paraValidar = {};
for (const [k, v] of Object.entries(conversions)) (v === null ? paraRemover : paraValidar)[k] = v;
if (!Object.keys(paraValidar).length) return { ...config, conversions: paraRemover };
return { ...config, conversions: { ...paraRemover, ...(await validar(paraValidar)) } };
```

**Teste que pega:** asserção sobre o corpo que sai do GATE, não sobre o que a tela monta nem sobre o
que o backend aceita. Visto falhando antes do fix: `expected {} to deeply equal { venda: null }`.

**Onde mais aparece:** qualquer enriquecedor/normalizador no meio de um PATCH parcial — sanitizador
de formulário, camada de defaults, mapper de DTO. A pergunta é sempre a mesma: *este laço distingue
"veio vazio" de "não veio"?*

**Ref:** Paid Media Automation, Matriz de Conversões F3, 2026-08-12 (`gateGadsConfig` +
`validateAndEnrichGadsConversions`). Achado pelo review cross-provider; o finding descrevia o
mecanismo errado (previa um 400), mas apontava o lugar certo.
