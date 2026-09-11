## `navigator.clipboard` virou getter-only no jsdom 25 — `Object.assign`/atribuição direta quebra o mock {#navigator-clipboard-getter-only-jsdom25}

tags: jsdom, vitest, navigator.clipboard, clipboard api, object.assign, object.defineproperty, getter-only, accessor property, ci vermelho, teste flaky, singlefork, poolOptions.forks.singleFork

**Sintoma:** um teste que mockava `navigator.clipboard` com `Object.assign(navigator, { clipboard:
{...} })` (ou atribuição direta `navigator.clipboard = {...}`) passa a lançar `TypeError: Cannot set
property clipboard of #<Navigator> which has only a getter`. Frequentemente aparece só no CI (ou só
depois de atualizar dependências), nunca reproduzindo num `npx vitest run <arquivo>` isolado — o que
engana a pensar que é flake de CI, não bug real do teste.

**Causa raiz:** a partir do jsdom 25, `navigator.clipboard` passou a ser implementado como uma
propriedade ACCESSOR (getter) somente-leitura no `Navigator.prototype` — mais fiel ao browser real
(onde `navigator.clipboard` também é read-only). `Object.assign`/atribuição direta fazem um `[[Set]]`
no objeto `navigator`; como ele não tem uma OWN property `clipboard` ainda, o `[[Set]]` sobe a
prototype chain, encontra o getter-sem-setter herdado, e falha — em vez de silenciosamente criar uma
own property que sombreia o getter (isso era o que acontecia em versões antigas do jsdom, onde
`clipboard` simplesmente não existia e a atribuição criava uma propriedade nova sem conflito).

Por que só aparece no CI: `Object.defineProperty(navigator, 'clipboard', {value: {...}})` (o fix
correto) opera direto na OWN property e não colide com o getter herdado, ENTÃO um arquivo de teste
já corrigido "conserta" `navigator.clipboard` como own-property pro resto do processo. Se a suíte
roda com `--poolOptions.forks.singleFork` (processo único compartilhado entre arquivos — usado pra
evitar OOM/crash de esbuild na suíte cheia, ver comentário no `ci.yml`), um arquivo mais cedo na
ordem de execução que já usa `Object.defineProperty` deixa `navigator.clipboard` como own-property
writable-ou-não pro resto da run; um arquivo que ainda usa `Object.assign` pode passar "por
acidente" dependendo da ordem. Rodar o arquivo isolado (processo próprio, sem `singleFork`) NÃO
reproduz a falha de ordem — só rodar com a MESMA flag que o CI usa reproduz de verdade.

**Solução:** trocar `Object.assign(navigator, {clipboard: {...}})` por:
```js
Object.defineProperty(navigator, 'clipboard', {
  configurable: true,
  value: { writeText: vi.fn().mockResolvedValue(undefined) },
})
```
`configurable: true` é obrigatório — sem ele, uma segunda chamada (outro teste, outro `beforeEach`)
não consegue redefinir a propriedade de novo. Pra confirmar que o fix realmente resolve (não só
"parece resolver" isolado), rode com a MESMA flag do CI: `npx vitest run <arquivo>
--poolOptions.forks.singleFork` — se o CI usa singleFork e o fix isolado, sem a flag, "passa", isso
não prova nada sobre ordem de execução compartilhada.

**Ref:** Plexco Tasks, 2026-09-10/11 — `frontend/src/components/tasks/__tests__/
task-detail-header.test.tsx` (achado numa varredura de CI/branches a pedido do operador; CI estava
vermelho em `master` desde a tarde de 10/09). O fix já existia, não-documentado, em dois outros
arquivos do mesmo repo (`task-detail-copiar-id.test.tsx`, `team-page.test.tsx`) — só faltava aplicar
no terceiro. Commit `dcaf054`.
