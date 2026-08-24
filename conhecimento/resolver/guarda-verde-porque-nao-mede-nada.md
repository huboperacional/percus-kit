## Guarda passa verde porque não mede nada — sabote a guarda, não só o código {#guarda-verde-porque-nao-mede-nada}

`tags: e2e, playwright, guarda, sabotagem, innerText, content, acordeao, word swap, acento, NFD, evidencia, screenshot, falso verde, teste cego`

**Contexto:** guarda E2E de conteúdo — varrer páginas por termos proibidos (voz de marca errada,
promessa sem lastro, preço herdado) ou comparar duas cópias do mesmo texto (JSON-LD × texto visível).
Ela roda, fica verde, e **nunca foi capaz de falhar**.

**Sintoma:** todos os testes passam. Ao introduzir de propósito o defeito que a guarda diz pegar,
**continuam passando**. Sem esse passo, o falso verde é indistinguível do verde real — e é pior que
não ter guarda: fica no repositório dando impressão de proteção e desencorajando quem viria conferir
à mão.

**Três causas medidas no mesmo dia (2026-08-24), todas na mesma família de specs:**

1. **`innerText` não devolve texto oculto.** FAQ em acordeão nasce fechada; `page.locator('body').innerText()` obedece ao CSS e pula o conteúdo colapsado. A guarda ficava cega
   **exatamente onde a copy problemática mora**, que é dentro de resposta de FAQ.
   ⚠️ Uma guarda irmã passava **por acaso**: aquele acordeão recortava (`max-height: 0` +
   `overflow: hidden`) em vez de remover do fluxo, então o texto sobrevivia no `innerText`. Trocar
   para renderização condicional — mudança trivial — a apagaria em silêncio.

2. **Componente que troca a palavra no tempo.** Um `WordSwap` alternava a manchete a cada 2,6s entre
   duas frases. Ler o DOM **uma vez** enxerga uma delas. Termo proibido colocado na outra posição é
   invisível na maioria das rodadas — e, quando calha de estar montado, faz a guarda **piscar
   vermelha sem causa aparente**, que é o caminho mais curto para alguém desligá-la.

3. **Acento.** `da família` não casa com `da familia`. Texto sem acento não é hipótese: mensagens de
   commit, copy digitada às pressas e migrações de encoding produzem a grafia crua o tempo todo. A
   guarda pegava só a grafia bonita e deixava passar a descuidada, que é a mais provável de vazar.

**Correção:**

```ts
// 1. Documento inteiro — acordeão fechado, JSON-LD e payload do framework juntos.
let texto = await page.content()

// 2. Onde houver troca no tempo, amostre o ciclo em vez de confiar num instante.
if (await page.locator('.word-swap').count()) {
  for (let i = 0; i < 10; i++) { await page.waitForTimeout(320); texto += await page.content() }
}

// 3. Normalize acento nos DOIS lados. Escape ASCII, nunca os combinantes literais.
const normalizar = (s: string) =>
  s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
```

Quando precisar do texto **sem** os `script` — por exemplo para comparar JSON-LD com o que a pessoa
lê —, clone o `body`, remova `script, style` e leia o `textContent`: `innerText` perde o colapsado,
e manter os `script` faz o teste comparar o schema **consigo mesmo** e passar sempre.

**Evidência também engana, e do mesmo jeito.** Um screenshot disparado no meio de uma animação
gravou uma caixa opaca com um fantasma de texto — e três hipóteses foram abertas em cima dele
(*"a página quebrou"*, *"é contraste"*, *"basta esperar a opacidade"*). Nenhuma era verdade: a
medição por estilo computado deu **5,16:1**, dentro de AA. Esperar `opacity > 0.95` não resolve —
a espera não governa o instante do `screenshot`. E `animations: 'disabled'` do Playwright **piora**:
ele avança a animação finita até o fim, e o fim de um fade-out é `opacity: 0`. O caminho
determinístico é neutralizar por CSS antes da foto:

```ts
await page.addStyleTag({ content:
  '.word-swap__item { animation: none !important; opacity: 1 !important; transform: none !important; }' })
```

**Como não repetir:**

- Depois de escrever a guarda, **sabote a guarda** pelo defeito que ela declara pegar, e confirme que
  ela fica vermelha **nomeando** rota e termo. Guarda que nunca ficou vermelha não é guarda.
- Guarda de conteúdo mede o **objeto renderizado**, nunca o arquivo-fonte: comentário que explica um
  conserto é indistinguível do defeito.
- Guarda de aparência mede o **resultado computado** (luminância do primeiro ancestral opaco), nunca
  o nome da classe: classe repintada continua casando e mente sobre a cor.
- Inclua uma asserção **contra verde por vacuidade** (`expect(lista.length).toBeGreaterThan(0)`) —
  laço sobre lista vazia passa.
- Escape unicode em regex vai como `\u0300-\u036f`, e confira com `cat -A`: ferramentas de edição gravam o
  caractere real no lugar do escape, em silêncio.

Relacionados: [[texto-sobre-a-regra-e-indistinguivel-da-regra]],
[[rodar-a-suite-reescreve-a-evidencia-historica]], [[a-sabotagem-prova-o-que-voce-imaginou]]
