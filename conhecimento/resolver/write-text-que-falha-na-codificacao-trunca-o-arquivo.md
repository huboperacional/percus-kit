## `Path.write_text` que falha na CODIFICAÇÃO já truncou o arquivo — o erro destrói o que você estava editando {#write-text-que-falha-na-codificacao-trunca-o-arquivo}

`tags: python, write_text, truncate, surrogates not allowed, UnicodeEncodeError, perda de arquivo, edicao de doc, emoji, par substituto, escrita atomica, git checkout`

**Sintoma:** um script Python que reescreve um arquivo levanta
`UnicodeEncodeError: 'utf-8' codec can't encode characters in position N: surrogates not allowed`
— e o arquivo fica com **0 bytes**. O traceback parece dizer "não escrevi nada"; ele escreveu nada
**por cima de tudo**.

**Causa.** `Path.write_text(dados)` abre o arquivo em modo `"w"`, que **trunca na hora da
abertura**, e só então empurra os dados pelo encoder. Se a codificação falha, a truncagem já
aconteceu. Não é exclusivo de `write_text`: qualquer `open(p, "w")` seguido de um `write` que
levanta tem o mesmo desenho.

**O gatilho mais comum no nosso contexto:** emoji fora do BMP escrito como **par substituto** em
escapes. `"🟠"` (a tentativa de 🟠) é um par de surrogates soltos, que Python aceita na
string e o encoder UTF-8 **recusa**. O certo é o codepoint inteiro: `"\U0001F7E0"`. Escrever o
caractere literal também funciona — mas veja o aviso de stdin abaixo.

**Correção — codifique ANTES de tocar no arquivo:**
```python
dados = "".join(linhas).encode("utf-8")   # levanta aqui, com o arquivo intacto
p.write_bytes(dados)
```
Para edições grandes, escreva em `p.with_suffix(".tmp")` e `os.replace()` por cima (troca atômica).

**Se já truncou:** `git checkout -- <arquivo>` recupera do índice/HEAD. ⚠️ **Confira antes se
havia mudança sua ou de outra sessão não commitada** (`git diff --cached --stat <arquivo>`) — num
worktree compartilhado, restaurar do HEAD pode apagar trabalho alheio. No caso real o arquivo
estava limpo e as 227 linhas voltaram inteiras.

⚠️ **Armadilha vizinha, mesma família (Windows):** `python - <<'PY'` no Git Bash entrega o script
com `sys.stdin.encoding = cp1252`, então **acento e emoji literais no heredoc chegam corrompidos**
— e um `assert velho in src` falha misteriosamente porque o literal foi mangled, não porque o
trecho mudou. Pior: escapes de barra invertida podem ser reinterpretados no caminho (`\\n` chegando
como newline real), fazendo um `str.replace` não casar. **Para editar arquivo com acento/emoji,
use a ferramenta de edição do harness ou escreva o script num arquivo `.py`** em vez de mandar por
stdin.

**Ref:** Paid Media Automation, 2026-09-06 — `docs/HANDOFF.md` (227 linhas) zerado ao inserir 🟠
num script de atualização de checkpoint; recuperado por `git checkout` e refeito com `write_bytes`.
