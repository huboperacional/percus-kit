## O snapshot do erro mostra o elemento PRESENTE — e mesmo assim o teste falhou {#snapshot-do-erro-mostra-o-elemento-presente}

`tags: playwright, e2e, flake, intermitente, next dev, compilacao sob demanda, timeout de assercao, verde envenenado, cache quente, reuseexistingserver, snapshot enganoso, falso positivo de regressao`

**Sintoma:** um teste de tela falha com `expect(locator).toBeVisible() failed … element(s) not
found` (ou `Test timeout exceeded`), e o **snapshot anexado ao erro mostra o elemento lá**,
renderizado e com `ref`. Rodando o mesmo teste sozinho, ele passa em 2–3 s. Na rodada seguinte
falha **outro** teste, em outra rota.

**Contexto:** aconteceu ao trocar o contrato de erro de uma API. A suíte de painel foi de 73/73
para 72 + 1 falho, e a falha caiu na tela mais pesada. Como havia mudança de contrato na mesa,
tudo apontava para regressão — e não era.

**Causa raiz: a suíte roda contra `next dev`, que compila cada rota SOB DEMANDA no primeiro
acesso.** O primeiro teste a tocar uma rota paga a compilação inteira; os seguintes pegam quente.
Como o `expect` do Playwright tem timeout **próprio** (5 s por padrão) e o teste tem o dele
(30 s), a rota fria estoura um dos dois — e qual estoura depende de **quais rotas já estavam
compiladas**, que muda a cada execução.

⚠️ **A explicação intuitiva — "contenção de CPU entre workers" — é falsa e custa tempo.** No caso
real o config tinha `workers: 1`, execução serial: não havia com quem competir. Confira o
`workers` **antes** de aceitar essa hipótese.

⚠️ **Rodar `npm run build` entre as suítes REINTRODUZ o problema**: o build de produção reescreve
`.next/`, o dev server com `reuseExistingServer: true` perde o compilado e a rodada seguinte é
toda fria. Verificação `build → e2e` na mesma sessão é justamente a ordem que mais flaka.

**O sinal que confirma em 1 minuto:** compare a **duração total** da suíte entre uma rodada fria e
uma quente. No caso real: **4,4 min frio × 2,3 min quente**, mesmos 73 testes. Se a diferença é
essa, é compilação, não código.

⚠️ **Não é só timeout, e é aqui que a maioria conserta errado.** Foram três execuções e três
mecanismos: 5 s do `expect`, 30 s do teste inteiro, e — o que fecha o argumento — um
`expect(...).toBe(true)` **sem relação nenhuma com tempo**. Esse último lia
`performance.getEntriesByType('resource')`, cujo buffer guarda **250 entradas**: em `next dev` a
página busca centenas de chunks separados, o buffer transborda e a requisição procurada é
**despejada**. O servidor de desenvolvimento não atrasa a medição — ele **estraga o instrumento**.
Quem responder a isso subindo timeout vai continuar vendo falha e sem entender por quê.

**Por que é pior do que um teste quebrado:** teste que falha sempre você conserta. Teste que falha
metade das vezes vira ruído tolerado — e a partir daí **o verde da suíte inteira deixa de ser
prova**. Toda entrega que usa aquela suíte como evidência carrega uma dúvida que ninguém resolve
olhando o relatório.

**Como confirmar antes de acusar o seu diff:**
1. Rode **só aquele teste** (`-g "trecho do nome"`). Passou rápido? Não é contrato.
2. Falhou teste **diferente** na rodada seguinte? Rota fria, não regressão — regressão é estável.
3. A rota que falhou tem relação com o seu diff? `/login` quebrando numa mudança de API de
   domínio é forte indício de infraestrutura.

**Como resolver, do mais correto ao mais barato:**
1. **Rode a e2e contra o build de produção** (`next build && next start`), não contra `next dev`:
   mata a classe inteira, e de quebra você testa o que vai para o ar.
2. **Passo de aquecimento** antes da suíte: um `page.goto` em cada rota, fora das asserções.
3. **Timeout explícito e folgado** na asserção da rota mais pesada, **com o porquê escrito** —
   qual tela, qual tempo medido, sob qual condição. Sem a frase, o próximo leitor vê número
   mágico e corta de volta "porque 15 s é exagero".

**O que NÃO fazer:**
- ❌ Subir o timeout **global**: some com o sinal de lentidão de todo o resto.
- ❌ `test.retry()` como primeira medida: vira política e o verde continua sem significar nada.
- ❌ `skip` "até investigar": tela que ninguém mede é tela que ninguém garante.

**A regra que sobra:** *timeout de asserção não é margem de segurança, é uma afirmação sobre
quanto a tela demora.* Contra servidor de desenvolvimento, essa duração **não é uma constante** —
depende do que já foi compilado, e é por isso que a suíte parece honesta na sua máquina e flaka
na primeira execução limpa.

**Relacionado:** [Alarme falso mata o alarme](alarme-falso-mata-o-alarme.md)

**Ref:** Empresa Milionária, 2026-08-20, `empresa-frontend/tests/e2e/guarda-visual.spec.ts` e
`playwright.pj.config.ts` — descoberto durante o P21 (envelope de erro), quando a falha se
disfarçou de quebra de contrato. Primeiro diagnóstico deste verbete foi **contenção entre
workers**, refutado pelo próprio `workers: 1` do config.
