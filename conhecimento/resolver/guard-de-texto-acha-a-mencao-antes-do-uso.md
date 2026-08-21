## Guard que lê texto acha a menção antes do uso — cinco formas do mesmo erro {#guard-de-texto-acha-a-mencao-antes-do-uso}

`tags: guard, teste de arquivo, grep, regex, falso positivo, falso negativo, verde decorativo, comentario, import, definicao de funcao, review, teste negativo`

**Contexto:** guards que leem o **código-fonte como texto** (`expect(fonte).toContain(...)`,
`grep` num portão de deploy) são baratos e cobrem o que teste de unidade não alcança —
ordem de declaração, presença de configuração, ausência de padrão proibido. E erram todos
pelo mesmo motivo: **acham a menção antes do uso**.

**Frequência medida: cinco vezes numa única sessão** (2026-08-20), todas em guards que eu
mesmo tinha acabado de escrever, e três delas só apareceram porque testei o guard **pelo
lado negativo**.

| # | O que o guard casou | Consequência |
|---|---|---|
| 1 | `var(--x)` dentro de um **comentário explicativo** do config | passou a cobrar valor escuro para uma variável chamada `--x`, que não existe |
| 2 | a linha `setAttribute('data-theme','light')` citada no **comentário que explica por que ela saiu** | guard acusou a própria explicação; para ficar verde, teria que apagar o comentário |
| 3 | o nome da função na linha de **`import`** | `includes('fecharComWriteBack')` passou VERDE com a chamada removida |
| 4 | a **definição** da função (`function salvarRotacao(`) | passou VERDE com `await salvarRotacao(...)` apagado |
| 5 | o ternário antigo citado no **comentário que documenta a substituição** dele | portão de deploy reprovou um deploy correto |

🔑 O padrão: código que **explica** uma mudança contém, quase sempre, o texto do estado
anterior. Um guard ingênuo trata explicação e implementação como a mesma coisa — e aí
**obriga a apagar a explicação para ficar verde**, que é exatamente o comentário que impede
a volta do bug.

### Consertos, na ordem de robustez

1. **Tire os comentários antes de medir.** Uma linha, e mata os casos 1, 2 e 5:
   ```js
   const semComentarios = (s) =>
     s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^[ \t]*\/\/.*$/gm, '')
   ```
   Trate `//` como comentário **só quando abre a linha** — senão `https://` dentro de uma
   string vira truncamento silencioso.

2. **Cobre a CHAMADA, não o nome.** `fecharComWriteBack(` com parêntese descarta o import
   (caso 3). Para distinguir chamada de definição (caso 4), inclua o que só a chamada tem:
   `await salvarRotacao(`.

3. **Ancore em início de linha** quando o alvo é uma *declaração*: `/^\s*--surface:/m` não
   casa a citação da variável no meio de um parágrafo.

4. **Conte, não pergunte se existe.** Guard de presença não vê multiplicidade. Um script
   que criava **dois** contextos e devolvia **um** passava num `includes(...)`; só
   `contagem(criar) === contagem(devolver)` pegou.

### O guard do guard

Nenhuma dessas correções vale sem duas coisas:

- **Asserção de cegueira.** Se o parser quebrar, o guard passa verde tendo medido nada.
  Toda varredura precisa afirmar antes que ENCONTROU algo: `expect(itens.length).toBeGreaterThan(N)`,
  ou um `throw` quando o corte devolve vazio.
- **Teste negativo obrigatório.** Reintroduza a violação, veja o guard reprovar, restaure.
  Três dos cinco casos acima só apareceram assim — e um guard nunca exercitado pelo lado
  negativo é indistinguível de um `it('ok', () => {})`.

### Exceção declarada continua precisando de prova

Quando um alvo legítimo precisa escapar do guard, liste-o **e exija que a razão exista**.
Uma ferramenta foi absolvida por ter "mecanismo próprio"; o guard checava
`toContain('salvarRotacao(')`, que casa a **definição** — a exceção continuou absolvendo
depois de a chamada ser apagada. A entrada de exceção é uma afirmação como qualquer outra:
tem que ser testável, e testada pelo lado negativo.

Ver também: [[alargar-matcher-de-guarda-troca-miss-por-alvo-errado]],
[[teste-string-nao-prova-gate-runtime]], [[comentario-afirma-garantia-que-o-codigo-nao-entrega]],
[[grep-com-regex-em-css-emitido-mente]].
