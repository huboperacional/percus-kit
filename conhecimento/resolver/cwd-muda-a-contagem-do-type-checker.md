## O `cwd` muda a contagem do type-checker, e duas sessões medem números diferentes do "mesmo" comando {#cwd-muda-a-contagem-do-type-checker}

`tags: mypy, cwd, resolucao de imports, contagem de erros, wc -l, note vs error, medicao divergente, reproduzir o gate, linter`

**Sintoma:** duas pessoas rodam *o mesmo comando* no *mesmo repositório*, na *mesma máquina*, e
obtêm contagens diferentes de erro. A diferença é pequena — uma ou duas linhas — e cada lado
consegue reproduzir a sua, o que faz as duas parecerem corretas.

**Causa raiz (medida, depois de três hipóteses erradas):** o **diretório de onde se roda** muda a
resolução de imports do type-checker, e com ela o conjunto de mensagens.

| `cwd` | caminho passado | linhas | `': error:'` | `': note:'` |
|---|---|---|---|---|
| raiz do repo | `sub/app/modulo.py` | 276 | **274** | 2 |
| `sub/` | `app/modulo.py` | 275 | **274** | 1 |

Os erros são os **mesmos 274**; o que muda são as notas de `missing-imports`, que só aparecem
quando o import **não** resolve.

🔴 **Isto não é curiosidade: é como se reproduz o gate.** Um hook de pre-commit costuma fazer
`Push-Location <raiz do projeto>` antes de invocar a ferramenta. Quem for depurar um bloqueio
rodando **de dentro do subprojeto não vê o que o gate viu**. Mesma família de
[[hook-le-o-cwd-nao-a-raiz-do-git]], que descreve o outro lado: o hook bloqueando por causa de um
arquivo que existe um diretório acima.

⚠️ **Segundo mecanismo, que se soma e confunde:** contar a saída com `wc -l` mistura `error:`,
`note:` e `warning:` — e ainda erra por um quando falta o newline final. **Conte pelo marcador**
(`grep -c ': error:'`), nunca por linha.

**Por que a diferença de 1 engana tanto:** é exatamente a magnitude que se quer medir num hunk
pequeno. No caso real, alguém atribuiu "274 versus 275" ao próprio commit — **os dois números
eram pós-mudança**, e a diferença era artefato. A conclusão estava certa (o hunk introduzia 1
erro) e a derivação, errada.

**Como resolver:** quando duas medições do "mesmo" comando divergem, **não explique a diferença —
isole a variável**. Quatro explicações plausíveis caíram antes da certa: "é a minha linha",
"é ruído entre execuções", "são duas notas sem newline final", "é a captura do shell". Todas
reproduziam no ambiente de quem as escreveu. O que fechou foi um A/B controlado, mudando **um**
fator por vez.

🔑 **E antes de explicar qualquer coisa: use o que é invariante.** Aqui, `': error:'` = 274 em
todo ambiente e todo `cwd` testado. O invariante estava na tela desde a primeira medição —
ninguém precisava de explicação nenhuma para usá-lo.

**Ref:** Empresa Milionária, 2026-09-05, duas sessões e quatro rodadas atrás de uma diferença de 1.
