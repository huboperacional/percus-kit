## `.cmd` gravado em LF ou com acento faz o `cmd.exe` comer caracteres: `setlocal` vira `tlocal` {#cmd-em-lf-ou-com-acento-faz-o-interpretador-comer-caracteres}

`tags: cmd.exe, CRLF, LF, encoding, UTF-8, acento, ASCII, hook, wrapper, ferramenta de edicao, exit 255`

**Sintoma:** um `.cmd` que você acabou de escrever falha com erros absurdos, citando comandos que
não existem no arquivo:

```
'tlocal' nao e reconhecido como um comando interno ou externo...
'M' nao e reconhecido como um comando interno ou externo...
```

`tlocal` é `setlocal` sem as duas primeiras letras. `M` é `REM` sem as duas primeiras. O
interpretador está **comendo caracteres no início das linhas** — e o exit code vira 255.

**Duas causas, e geralmente as duas juntas:**

1. **Quebra de linha LF em vez de CRLF.** A maioria das ferramentas de edição (e `io.open(...,
   newline='')` em Python) grava LF. O `cmd.exe` espera CRLF e desalinha a leitura.
2. **Qualquer byte não-ASCII.** Um `ç` ou `õ` num **comentário** é suficiente: em UTF-8 ele ocupa
   2 bytes, e o `cmd.exe` lê com a code page do console (cp850/cp1252), deslocando tudo depois.

No caso medido (2026-09-12) o arquivo tinha **138 linhas LF, 0 CRLF** e **4 bytes não-ASCII**, vindos
da palavra "iterações" dentro de um `REM`.

**Conserto e verificação:**

```python
s = io.open(p, encoding='utf-8').read()
s = ''.join(c for c in unicodedata.normalize('NFD', s)
            if unicodedata.category(c) != 'Mn')        # tira acento, mantem a letra
s = s.replace('\r\n', '\n').replace('\n', '\r\n')      # CRLF
open(p, 'wb').write(s.encode('ascii'))                  # estoura se sobrou nao-ASCII
```

O `.encode('ascii')` no fim é a parte importante: ele **falha** se restou byte alto, em vez de
gravar um arquivo que só quebra na hora de rodar.

Confira contra um `.cmd` irmão que já funciona, e não contra a sua expectativa:

```python
b = open('hooks/pre-commit-check.cmd', 'rb').read()
print(b.count(b'\r\n'), sum(1 for c in b if c > 127))   # esperado: N, 0
```

**Por que isso reaparece:** a disciplina "ASCII puro nos comentários" já estava escrita nos scripts
do kit, e mesmo assim o arquivo novo nasceu com acento — porque ele foi criado por **ferramenta de
edição**, e não copiando um irmão. Convenção que mora só na cabeça de quem já leu o arquivo antigo
não sobrevive ao próximo arquivo.

**Discriminante:** erro de `cmd.exe` citando um comando que **não existe no seu arquivo**, mas que é
um sufixo de um que existe? Não procure o erro na lógica. Olhe os **bytes**: quebra de linha e
code page, nessa ordem.
