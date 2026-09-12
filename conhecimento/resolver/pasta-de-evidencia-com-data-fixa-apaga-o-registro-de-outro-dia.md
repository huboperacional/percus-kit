## Caminho de screenshot com data FIXA faz o run de hoje apagar a evidência de outro dia {#pasta-de-evidencia-com-data-fixa-apaga-o-registro-de-outro-dia}

`tags: evidencia, screenshot, playwright, r1, git, diff binario, registro datado, falha silenciosa, R23`

**Sintoma:** depois de rodar uma suíte de R1, o `git status` mostra uma PNG **modificada** dentro de
uma pasta `docs/evidencias/<data-antiga>-.../`. O diff é `Bin 151720 -> 161473 bytes` — ruído
binário que ninguém abre e que passa em qualquer review de texto.

**Causa:** o spec grava o screenshot num caminho com a data **em que ele foi escrito**, não a do run:

```ts
await page.screenshot({
  path: path.join(__dirname, '..','..','..',
    'docs/evidencias/2026-09-04-fr156-fr159-r1-alocacao-inline/etapa-alocada-confirmada-travada.png'),
})
```

Toda execução futura despeja a foto de hoje dentro do registro daquele dia. **Duas perdas de uma
vez, as duas em silêncio:** a prova do dia antigo deixa de existir, e a prova de hoje fica datada
errado. Pasta de evidência é **registro datado** — é o que sustenta frases como *"provado em 04/09"*
no PLANO. Quando a foto lá dentro é de 12/09, a frase vira falsa sem que ninguém tenha editado texto
nenhum.

**Conserto — derive a pasta do run:**

```ts
const hoje = new Date()
const pasta = `${hoje.getFullYear()}-${String(hoje.getMonth()+1).padStart(2,'0')}`
            + `-${String(hoje.getDate()).padStart(2,'0')}-fr156-fr159-r1-alocacao-inline`
await page.screenshot({ path: path.join(RAIZ, 'docs/evidencias', pasta, 'nome.png') })
```

**Se já aconteceu:** copie a foto nova para a pasta datada de hoje **antes** de restaurar, senão
você destrói a prova de hoje ao recuperar a de ontem:

```bash
cp docs/evidencias/<data-antiga>-x/foto.png docs/evidencias/<hoje>-x/foto.png
git checkout -- docs/evidencias/<data-antiga>-x/foto.png
```

**Variante que não modifica nada e engana mais:** quando o nome do arquivo também muda, o run cria
um arquivo **novo** (`?? untracked`) dentro da pasta antiga. Não há diff, não há "modified" — só uma
foto de hoje morando no registro de outro dia.

Achado em 2026-09-12, projeto Empresa Milionária, rodando `tests/r1/producao-alocacao.spec.ts`
(sobrescreveu a foto de 04/09) e `tests/r1/hoje.spec.ts` (criou arquivo novo na pasta de 09/09).
