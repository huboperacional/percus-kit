## Gerar script com heredoc de Python come o `\1` do sed — vira `\x01` e o script falha calado {#heredoc-de-python-come-barra-1-do-sed-e-vira-byte-de-controle}

`tags: python, heredoc, sed, bash, gerar script, escape, raw string, byte de controle, falha calada, SyntaxWarning, powershell, BOM, utf-8-sig`

**Sintoma:** você edita um `.sh` (ou `.ps1`) por um heredoc de Python, o `bash -n` diz que a sintaxe
está OK, os testes passam, e **um comando dentro do script devolve vazio pra sempre**. Nada
quebra — só para de funcionar, em silêncio.

**A causa:** numa string **não-raw** do Python, `\1` é um escape octal, e vira o byte `\x01` (SOH).
Então isto:

```python
s = s.replace(velho, """... | sed 's/.*"\([^"]*\)"$/\1/'""")
```

grava no arquivo:

```bash
... | sed 's/.*"\([^"]*\)"$/^A/'     # o \1 virou o byte de controle
```

O `sed` continua sintaticamente válido — ele só substitui pelo byte `\x01` em vez de pelo grupo
capturado. A variável recebe lixo invisível, todo `grep`/`case` sobre ela falha, e **o caminho que
dependia dela morre sem erro nenhum**.

**O Python avisa, e o aviso passa batido:**

```
SyntaxWarning: "\(" is an invalid escape sequence.
Did you mean "\\("? A raw string is also an option.
```

Ele reclama do `\(` — que é inofensivo — e **não** do `\1`, que é o que realmente corrompe. Quem lê
o warning pensa "é só o regex, tá funcionando" e segue.

**Como evitar:** ao gerar/editar script por Python, use **string raw** para qualquer trecho com
barra invertida:

```python
good = r"""sed 's/.*"\([^"]*\)"$/\1/'"""
```

**Como detectar depois do estrago** (vale como checagem de rotina após qualquer edição
programática):

```bash
grep -c $'\x01' arquivo.sh        # tem que dar 0
grep -n 'MODELO=' arquivo.sh | cat -A   # `cat -A` mostra ^A onde o byte se escondeu
```

`bash -n` **não** pega: o byte é um literal válido. O único jeito de a suíte pegar é um teste que
exercite o campo que aquele `sed` extrai — e foi justamente o fixture que usava o valor default que
deixou isto passar (ver [[paridade-testada-no-caso-facil-nao-e-paridade]]).

**Mesma família, outro alvo:** editar `.ps1` por Python come o **BOM** se você abrir com `utf-8` em
vez de `utf-8-sig` — e aí o `ps51-compat` fica vermelho sem o diff denunciar nada. A regra que cobre
as duas: **edição programática de script é edição de bytes**, e bytes que o seu editor não mostra
(BOM, `\x01`, CRLF) são exatamente os que quebram. Depois de gerar, confira os bytes:

```bash
head -c 6 arquivo.ps1 | xxd | head -1   # efbbbf = BOM presente
```

**Discriminante:** você usou uma linguagem com escapes próprios (Python, PowerShell, JS) para
escrever um arquivo que **também** tem escapes próprios (sed, regex, bash)? Então há duas camadas de
escape e uma delas vai comer a outra. Raw string na de fora, e confira o resultado **no arquivo**,
não no código que o gerou.
