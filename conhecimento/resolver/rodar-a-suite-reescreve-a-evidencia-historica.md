## Rodar a suíte reescreve a evidência histórica, e o diff parece ruído binário {#rodar-a-suite-reescreve-a-evidencia-historica}

`tags: playwright, screenshot, evidencia, testMatch, prova de entrega, PNG, diretorio datado, arqueologia, falso ruido, e2e, regressao silenciosa`

**Contexto:** projeto que decide entrega por screenshot guarda as fotos em diretórios **datados**
(`docs/evidencias/2026-08-19-16-paineis/`). Um spec de Playwright as gera. O `testMatch` da config
casa por prefixo (`/(pj-|guarda-).*\.spec\.ts/`) e o spec de evidência começa com o mesmo prefixo —
então **toda rodada de rotina regenera as fotos**, dentro do diretório de uma data que já passou.

**O que acontece:** em 2026-08-24, três execuções da suíte reescreveram 21 PNGs de 19, 20 e 21 de
agosto com a tela de hoje. `git status` mostrou 21 arquivos modificados e nenhuma linha de código
correspondente.

**Por que passa batido:** o diff de PNG é binário e ilegível. A primeira leitura foi *"recompressão
lossless, benigno"* — plausível e errada. Só descomprimindo os pixels dos dois lados a diferença
apareceu: **0,09% dos bytes, concentrados em 41 linhas**. Não era ruído: era conteúdo. `venceu há 1
dia` virou `venceu há 4 dias` (data relativa, que anda sozinha) e um bloco de anúncio trocou de
texto.

**Por que importa mais do que parece:** a foto de 19/08 **é a prova** de como a tela estava em
19/08. Regenerá-la apaga o registro de que a tela já esteve diferente — e apaga em silêncio, com o
teste verde. Num projeto onde entrega se decide por screenshot, isso destrói o instrumento de
medida, não um arquivo.

**A causa que parece autoria:** a investigação inicial correlacionou o horário do arquivo com quem
tinha editado um componente naquela janela, e apontou essa pessoa. Estava errada — **ninguém editou
imagem nenhuma**. Quem as reescreveu foi rodar a suíte, que é a operação mais rotineira que existe.
⚠️ Quando um artefato muda sem autor plausível, procure o **mecanismo** antes do culpado: correlação
de horário aponta quem estava por perto, não o que aconteceu.

**Diagnóstico (a ordem que funciona):**
1. `git status` acusa PNG modificado sem mudança de código correspondente.
2. **Não confie na hipótese de compressão.** Descomprima os pixels dos dois lados e compare;
   `%` de bytes diferentes **concentrado em poucas linhas** = conteúdo, espalhado = compressão.
3. `grep -rn "page.screenshot\|const SAIDA\|EVIDENCIA" tests/` — ache **todos** os specs que
   escrevem em `docs/evidencias/`. Não é só o que se chama `evidencia`: no caso medido, cinco
   arquivos gravavam ali, e só um tinha "evidencia" no nome.
4. Confira o `testMatch` da config: se ele casa o spec de evidência, a suíte regenera.

**Fix:** grave a foto **só sob intenção declarada**, e mantenha as asserções rodando sempre:

```ts
export async function fotoDeEvidencia(page, caminho, opcoes = { fullPage: true }) {
  if (process.env.EVIDENCIA !== '1') return false
  await page.screenshot({ ...opcoes, path: caminho })
  return true
}
```

`EVIDENCIA=1 npx playwright test ...` grava; a rodada normal pula a foto e continua verde pelas
asserções — que é o que importa proteger, porque foi uma delas que pegou uma tela nem montada.

⚠️ **Duas armadilhas ao aplicar o fix:**
- Um regex que case `path: X, fullPage: true` **não pega** a chamada que usa `clip:` em vez de
  `fullPage`. Confira com `grep -rn "page.screenshot("` que sobrou zero chamada crua.
- Depois de guardar, **restaure os PNGs antes de medir** (`git checkout -- docs/evidencias/`). Sem
  isso você mede o resíduo da rodada anterior e conclui que a guarda não funciona.

**Prova do fix:** restaurar → rodar a suíte inteira → `git status docs/evidencias/` vazio.

**Alternativa recusada:** tirar os specs de evidência do `testMatch`. Perderia as asserções deles,
que são reais — no caso medido, uma delas provou que a linha do tempo estava atrás de um alternador
e nem chegava a montar.

Relacionado: [[o-screenshot-pega-o-que-a-guarda-nao-ve]].
