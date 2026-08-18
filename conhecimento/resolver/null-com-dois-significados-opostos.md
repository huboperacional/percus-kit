## `null` que significa duas coisas opostas: separe o "não há com o que comparar" do "o outro lado está vazio" {#null-com-dois-significados-opostos}

`tags: null ambiguo, comparacao entre fontes, alerta em massa, sentinela, ausencia estrutural, dois significados opostos, falso alerta`

**Classe:** comparação entre duas fontes quando uma delas pode não existir por construção.

**Sintoma:** um estado de alerta novo dispara em massa, em linhas que estão perfeitamente
configuradas.

**Causa raiz:** a leitura da segunda fonte devolve `null` por motivos estruturalmente diferentes —
*aquela plataforma não tem essa fonte*, *aquela linha não alimenta essa fonte*, e *a fonte existe e
está vazia*. O código testa o valor (`if (a && !b)`) e trata os três igual.

**Regra:** calcule primeiro um booleano de **elegibilidade** ("existe segunda fonte para comparar
aqui?") e só depois olhe valor nenhum. O booleano tem que ser avaliado ANTES, não depois:

```ts
const comparavel = ehPrimario && PLATAFORMAS_COM_A_SEGUNDA_FONTE.has(plataforma);
if (!comparavel) return valor ? {estado: "ok"} : {estado: "vazio"};
// só aqui a ausência do outro lado significa divergência
```

**Teste que pega:** um caso por MOTIVO de ausência, não um caso de ausência. Aqui foram três:
plataforma sem a coluna, linha não-primária, e coluna existente e vazia.

**Ref:** Paid Media Automation, `build-matrix.ts`, 2026-08-12. Sem a separação, todo destino
primário de GA4/TikTok aparecia como "dessincronizado".
