## "Em curso" guardado como id global: o `finally` de uma operação apaga o estado da outra {#estado-em-curso-por-id-global-vaza-entre-operacoes}

`tags: React, estado compartilhado, corrida, race condition, finally, diálogo, modal, loading, botão desabilitado, setState, concorrência, UI, async`

**Contexto:** tela com duas ações sobre a mesma lista — arquivar e desarquivar, aprovar e rejeitar,
publicar e despublicar. O padrão natural é um estado só para "o que está em voo":

```ts
const [emCurso, setEmCurso] = useState<string | null>(null)   // 🔴 só o id

async function executar(item, acao) {
  setEmCurso(item.id)
  try { await api[acao](item.id); await recarregar() }
  finally { setEmCurso(null); setConfirmando(null) }          // 🔴 zera o que não é dele
}
```

**Causa raiz:** o id responde *"qual item"* e não responde *"qual ação"* nem *"esta operação ainda é
a minha"*. Duas operações concorrentes escrevem no mesmo lugar, e a que terminar primeiro limpa o
estado da que ainda está em voo.

**Os dois estragos, e o segundo é o que dói:**
1. **Rótulo mentiroso** — o botão do diálogo diz "Arquivando…" e fica desabilitado por causa de uma
   ação que ninguém iniciou ali. Chato, visível, fácil de atribuir a outra coisa.
2. **O diálogo fecha debaixo do usuário** — o `finally` da operação alheia chama
   `setConfirmando(null)`. A pessoa abriu uma confirmação, leu, foi clicar, e ela sumiu. **Não gera
   erro, não entra em log, não vira incidente**: a pessoa conclui que clicou fora e tenta de novo.

**Fix — a operação carrega a própria identidade, e só mexe no que é dela:**

```ts
interface OperacaoEmCurso { id: string; acao: 'arquivar' | 'desarquivar' }
const [emCurso, setEmCurso] = useState<OperacaoEmCurso | null>(null)

async function executar(item, arquivar: boolean) {
  const operacao = { id: item.id, acao: arquivar ? 'arquivar' : 'desarquivar' } as const
  setEmCurso(operacao)
  try { /* … */ }
  finally {
    setEmCurso((atual) =>
      atual?.id === operacao.id && atual.acao === operacao.acao ? null : atual)
    if (arquivar) setConfirmando((atual) => (atual?.id === item.id ? null : atual))
  }
}
```

O **updater funcional** (`setX(atual => …)`) é o miolo: ele lê o estado no momento da limpeza, não o
que estava capturado no closure quando a operação começou.

**O que NÃO fazer:** bloquear a interface inteira durante a requisição. Resolve a corrida e cria um
problema pior — a tela fica refém da requisição mais lenta, e o usuário não consegue nem cancelar.

**Como escrever o teste, e as duas armadilhas dele** (as duas custaram uma rodada vermelha cada, **por
defeito do teste, não do produto**):
1. Para segurar uma resposta em voo você sobrepõe a rota (`page.route` registrado *depois* do mock
   base). Sobrepor **tira o handler que mantinha o estado do mock** — a tela relê uma lista que não
   mudou e o teste falha acusando o produto. Exponha o estado do mock e atualize-o na sobreposição.
2. Com **diálogo modal aberto**, o Radix (e qualquer implementação correta) marca o resto da página
   como `aria-hidden`/`inert`. `getByRole(...)` **não enxerga nada atrás do modal**. Espere pela
   **releitura na rede** (`page.waitForResponse`), que é o sinal que existe de verdade, e só afirme
   sobre a lista depois de fechar o diálogo.

**Onde apareceu:** Empresa Milionária, 2026-08-20, seletor de empresas (M5-3). Achado por review
cross-provider, que relatou o rótulo errado; medindo, o diálogo fechando era o estrago maior.
