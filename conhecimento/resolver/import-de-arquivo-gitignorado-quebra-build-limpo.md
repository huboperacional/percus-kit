## Import estático de arquivo gitignorado quebra o build no checkout limpo {#import-de-arquivo-gitignorado-quebra-build-limpo}

`tags: gitignore, build, deploy, checkout limpo, VPS, snapshot de dado real, dev-preview, fixture, co-design, import estatico, next build, R11, dado de cliente, bundle`

**Contexto:** para desenhar uma tela contra dado de verdade, capturei o payload de produção de um
cliente num JSON e apontei a rota de preview versionada para ele. O JSON foi (corretamente) para o
`.gitignore` — é dado de cliente e não pode entrar no repo.

```ts
// arquivo VERSIONADO
import bruto30 from "./_dados/cliente-30d.json";   // _dados/ está no .gitignore
```

**O defeito:** na máquina de dev funciona perfeitamente, porque o arquivo está lá. **No checkout
limpo não existe**, e import estático de arquivo ausente é **erro de build**, não warning. O deploy
canônico deste projeto é exatamente um checkout limpo (bundle → `git worktree add --detach` na VPS →
build), então o build de produção cairia — depois de todo o trabalho estar commitado e revisado.

**Causa raiz:** `.gitignore` e `import` são dois sistemas que não se falam. O primeiro afirma "isto
não pertence ao repo"; o segundo afirma "isto é obrigatório para compilar". Apontar os dois para o
mesmo caminho é uma contradição que **só se manifesta onde ninguém testa** — e o lugar onde ninguém
testa é a produção.

**Por que nenhum gate local pega:** `tsc --noEmit`, a suíte inteira e o dev server rodam na máquina
que **tem** o arquivo. Todos passam. O único sinal viria de um build a partir de uma árvore limpa.

**Correção:** a rota versionada importa **fixture sintética versionada**, sempre. O snapshot real
vira ferramenta local — apontar o import para ele sem commitar, e voltar antes de fechar. A fixture
não precisa ser bonita, precisa **exercitar os cortes e os casos de borda** (volume concentrado,
cauda longa, auto-laço, estado em zero); é isso que a torna útil como prova visual.

**Gate:** rode `npm run build` (não só `tsc --noEmit`) antes de deployar sempre que o diff adicionou
import novo — `tsc` não resolve import de JSON do mesmo jeito que o bundler. Confirme `EXIT=0`.

⚠️ **Segundo risco na mesma linha:** se a rota de preview for alcançável em produção, o import
estático também **embute o dado do cliente no bundle público**. Bloqueio por middleware ajuda, mas
não pode ser a única defesa — o dado já estaria compilado no artefato.

**Como detectar em revisão:** procure por `import ... from "./<algo>"` cujo caminho case com alguma
linha do `.gitignore`. É uma checagem mecânica e vale a pena automatizar.

Relacionado: [git-archive-no-windows-grava-crlf](#git-archive-no-windows-grava-crlf) — mesma família,
o build da VPS falha por algo que a máquina de dev nunca reproduz.
