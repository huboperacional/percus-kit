## Normalizar cabeçalho de arquivo malformado ANTES de decodificar corrompe o corpo em outro encoding {#normalizar-cabecalho-antes-de-decodificar-corrompe-o-corpo}

`tags: encoding, utf-8, cp1252, latin-1, decode, bytes vs texto, regex, header malformado, ofx, ofxparse, banco brasileiro, corrupcao silenciosa, R11`

**Contexto:** um arquivo de terceiro (aqui, extrato bancário OFX) chega com um cabeçalho que
declara o próprio encoding — mas o valor vem malformado (`ENCODING: UTF - 8`, com espaços ao
redor do hífen, em vez de `UTF-8`). A biblioteca que interpreta o arquivo inteiro (`ofxparse2`)
não reconhece a grafia e quebra com `UnboundLocalError` antes de chegar ao corpo.

**O erro fácil de cometer ao consertar:** normalizar o cabeçalho por regex é natural fazer sobre
**texto**, então a tentação é `conteudo.decode('utf-8', errors='replace')` primeiro, aplicar o
regex, e re-codificar para entregar à biblioteca. Isso FUNCIONA para o caso que motivou o
conserto — se o arquivo realmente for UTF-8. **E corrompe silenciosamente qualquer arquivo que
não seja**: o mesmo cabeçalho malformado costuma vir ao lado de `CHARSET: 1252` (Windows-1252),
que MUITOS bancos brasileiros realmente usam no corpo. Decodificar como UTF-8 primeiro faz cada
byte fora do ASCII virar `?` (com `errors='replace'`) — o acento morre ANTES de a biblioteca
sequer ler o `CHARSET` que diria o encoding certo.

**Por que "funciona no teste" não prova nada aqui:** se o arquivo de teste for coincidentemente
UTF-8 (aconteceu: um extrato real anonimizado, que por acaso não tinha nenhum byte fora do
ASCII na primeira versão), a suíte inteira passa com o bug agarrado. O sintoma só aparece com um
arquivo de OUTRO banco, em produção, meses depois — e aparece como acento sumido, não como
exceção.

**A regra:** cabeçalho de protocolo (`ENCODING:`, `CHARSET:`, e afins) é **sempre ASCII puro**
por definição — é o CORPO que varia de encoding. Por isso a normalização do cabeçalho pode (e
deve) rodar em **bytes**, com um regex `rb"..."`, sem decodificar nada:

```python
# ERRADO — decodifica o CORPO inteiro antes de saber o encoding dele
texto = conteudo.decode("utf-8", errors="replace")
texto = padrao_texto.sub(r"\1UTF-8", texto)
lib.parse(io.BytesIO(texto.encode("utf-8")))

# CERTO — normaliza em bytes, o corpo original nunca é tocado
padrao_bytes = re.compile(rb"(?im)^(ENCODING\s*:\s*)UTF\s*-\s*8\s*$")
conteudo = padrao_bytes.sub(rb"\1UTF-8", conteudo)
lib.parse(io.BytesIO(conteudo))  # a lib decide o encoding do corpo sozinha
```

A biblioteca correta (`ofxparse2`, e provavelmente qualquer parser de protocolo com
`ENCODING`/`CHARSET` próprio) já sabe decodificar o corpo pelo header — o trabalho de quem
normaliza é não atrapalhar essa decisão tocando em bytes que ainda não foram interpretados.

**Como provar que importa, e não só documentar:** construir um arquivo sintético mínimo com um
caractere fora do ASCII codificado no encoding REAL declarado (ex.: `"ã"` em CP1252 é o byte
único `0xE3`; em UTF-8 são dois bytes, `0xC3 0xA3`) e afirmar que ele sobrevive ao round-trip.
Sabotar a versão "decodifica primeiro" contra esse arquivo mostra a corrupção na hora — sem o
arquivo sintético, o bug fica invisível até um extrato real de outro banco chegar.

**Achado por review cross-provider (R11)**, não pela sabotagem original do autor — a primeira
versão do código já tinha 7 testes verdes, nenhum expondo o caminho CP1252. Mesma classe do
corolário de [[a-sabotagem-prova-o-que-voce-imaginou]]: a sabotagem prova a classe que você
imaginou testar; aqui, a classe "arquivo em outro encoding" só apareceu porque um revisor de
fora leu o código, não porque um teste a exercitou primeiro.

Relacionado: [[get-content-sem-encoding-mojibake-51]] (mesma família — decisão de encoding no
lugar errado —, runtime e sintoma diferentes), [[subprocess-text-true-sem-encoding-cp1252]].
