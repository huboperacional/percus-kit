## Regex que nunca casa: `\b` escrito por gerador Python vira um BYTE DE BACKSPACE (0x08) invisível {#escape-b-em-gerador-python-vira-byte-de-backspace}

tags: Python, escape, string literal, raw string, backslash, \b, \s, \n, backspace, 0x08, regex, heredoc, gerador de codigo, cat -A, byte invisivel, SyntaxWarning, gate que nao casa, drift, terceira ocorrencia

**Sintoma:** um regex escrito por script gerador (Python que emite `.ts`/`.js`/`.sh`) **nunca
casa**, mesmo com o alvo obviamente presente. O arquivo parece correto no editor, no `grep`, no
`git diff` e na revisão. Testar as duas metades da condição separadamente, **reescrevendo o regex
na hora**, dá `true` — o que reforça a conclusão errada de que o regex está certo e o problema é
outro (cache, ordem de execução, escopo).

**Causa:** numa string Python **não-raw**, `\b` é um escape **VÁLIDO** — é o caractere
*backspace*, `0x08`. Então:

```python
t = "  /\\busePageHeader\\s*\\(/.test(txt)"   # o autor quis \b de regex
```

produz no arquivo um `0x08` literal antes de `usePageHeader`. O regex resultante exige um
backspace de verdade no texto, e por isso não casa com nada.

**O que torna isto especialmente traiçoeiro é a assimetria dos avisos:**

| escape | Python | avisa? |
|---|---|---|
| `\s` | inválido | ✅ `SyntaxWarning: invalid escape sequence` |
| `\(` | inválido | ✅ avisa |
| **`\b`** | **VÁLIDO (backspace)** | ❌ **silêncio total** |
| `\n`, `\t` | válidos | ❌ silêncio (e viram quebra/tab de verdade) |

Ou seja: o dev vê avisos sobre `\s` e `\(` na mesma linha, corrige *aqueles*, e conclui que o
resto está bem. `\b` e `\n` passam calados e são justamente os que corrompem.

**Como ver:** só o `cat -A` mostra (`^H` para 0x08, `$` no fim da linha). `grep`, editor e
navegador de diff renderizam o backspace como nada.

```bash
sed -n '146p' arquivo.ts | cat -A
#   /^Hredirect\(|router\.replace\(/.test(fonte)   ← o ^H é o byte 0x08
```

**Solução:**

1. **String RAW sempre** que o conteúdo emitido tiver barra invertida: `r'...\b...'`.
2. Quando a própria substituição é sobre barras, use **códigos de caractere** e não confie em
   escapar o escape: `chr(92) + 'b'` para `\b`, `chr(92) + 'n'` para `\n`.
3. **Varra o resultado** depois de gerar: `assert chr(8) not in texto` (e `chr(0)`, `chr(27)`).
4. Prefira a ferramenta de escrita de arquivo do agente a um heredoc `python - <<'PY'` quando o
   conteúdo tem muita barra, crase ou `${}`.

**Why:** o modo de falha é **silencioso em toda a cadeia de verificação** — não há erro de
sintaxe, o `tsc` compila, o teste roda, o gate fica VERDE e simplesmente não vigia nada. Um gate
assim é pior que gate nenhum: dá a sensação de cobertura.

⚠️ **Isto é DRIFT, não distração.** Medido 3 vezes no mesmo projeto (`Paid Midia Automation`),
sendo uma delas **ao escrever o próprio adendo que documentava o bug** — a frase sobre o
backspace nasceu com backspaces. Reincidência em escape é gatilho do loop `drift.md`.

Relacionado: [[guard-cego-por-escape-em-template-literal]],
[[gate-que-nunca-foi-visto-reprovando-aprova-tudo]].
