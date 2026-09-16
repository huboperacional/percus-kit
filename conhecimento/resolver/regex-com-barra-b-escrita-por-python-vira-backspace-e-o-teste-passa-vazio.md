## `\b` escrito por Python em string não-raw vira backspace (0x08) — a regex do teste nunca casa e o gate passa VAZIO {#regex-com-barra-b-escrita-por-python-vira-backspace-e-o-teste-passa-vazio}

`tags: regex, backspace, 0x08, python, string nao raw, gate vazio, teste vacuo, not.toMatch, edicao por script, R23`

**Sintoma:** um teste do tipo "a tela NÃO deve conter X" (`expect(texto).not.toMatch(/\bCPL\b/)`) passa
sempre — inclusive quando o código mostra X. No editor, a linha parece correta. Nada acusa.

**Reprodução real** (Paid Media, 2026-09-16): dois gates vazios na mesma base, um deles de outra frente,
de semanas antes:

```text
tela-liberada.test.ts   → /<0x08>resolverLink<0x08>(?!DoPedido)/
formatar.test.ts        → /<0x08>CPL<0x08>/
```

O terminal e vários editores **escondem** o 0x08: a linha aparece como `/resolverLink(?!DoPedido)/` ou
`/CPL/`. A regex real procura o caractere backspace, que nunca existe no texto da tela — então
`not.toMatch` é sempre verdadeiro.

**Causa:** o arquivo foi editado por um script Python (heredoc) com o conteúdo numa string **não-raw**.
Em Python, `"\b"` é o escape de backspace, não "barra + b". O mesmo vale para `"\f"` (0x0c) e
`"\v"` (0x0b). O Python só avisa (`SyntaxWarning: invalid escape sequence`) para escapes que NÃO
existem, como `\s` ou `\(` — `\b` é válido, então passa em silêncio.

**Como achar:**

```python
import pathlib
for p in pathlib.Path("src").rglob("*.ts*"):
    n = p.read_bytes().count(bytes([8]))
    if n:
        print(p, n)
```

`grep -P "\x08"` falha em locale não-UTF-8 do Git Bash no Windows ("supports only unibyte and UTF-8
locales") — use o script acima.

**Como corrigir:** trocar o byte, não o texto visível — `bytes([8])` por `bytes([92, 98])` (a barra e o
`b`). Tentar `b.replace(b"\x08", b"\\b")` dentro de OUTRO heredoc pode falhar do mesmo jeito; valores
numéricos explícitos não têm essa armadilha. **Depois, rodar o teste e ver que ele passou a medir** — no
caso real um dos dois gates, ao ficar vivo, passou a acusar um comentário legítimo e precisou virar
"proíbe a chamada `resolverLink(`" em vez de "proíbe a palavra".

**Prevenção:**
- Em script Python que escreve código, use string raw (`r"..."`) ou a ferramenta de edição direta.
- Todo gate negativo (`not.toMatch`, `not.toContain`) precisa ser visto **reprovando** com o defeito
  reintroduzido — gate que só sabe aprovar não mede nada.
- Uma varredura de bytes de controle no repositório é barata e pega os antigos.
