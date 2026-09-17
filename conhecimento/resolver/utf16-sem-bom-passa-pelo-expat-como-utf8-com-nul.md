## UTF-16 sem BOM passa pelo expat como "UTF-8 com NUL" e a árvore sai certa, então quem decide a codificação é o parser {#utf16-sem-bom-passa-pelo-expat-como-utf8-com-nul}

`tags: xml, expat, xml.etree, ElementTree, codificação, encoding, utf-16, bom, nul, decodificação estrita, entrada hostil, python`

**Sintoma:** o módulo decide a codificação do XML pelos BYTES, de forma estrita: BOM, depois a declaração, depois UTF-8.
Depois monta a árvore sobre o `str`, porque `ET.fromstring` e o expat ignoram a codificação declarada quando recebem `str`.
Os testes de UTF-8, ISO-8859-1, windows-1252 e UTF-16 com BOM passam. Mas um arquivo UTF-16 **sem BOM**:

- **só com ASCII:** decodifica "como UTF-8" sem erro, porque todo `\x00` é UTF-8 válido. O texto sai com NUL entre as
  letras, e mesmo assim a árvore sai **certa** (`<nota><valor>100.00</valor>`), nas duas ordens de bytes;
- **com acento:** a mesma nota é recusada como "não pôde ser lido na codificação UTF-8" (`\xe7\x00` não é UTF-8).

O mesmo documento é aceito ou recusado conforme o conteúdo, e a mensagem de recusa fala na codificação errada. Medido
em 2026-09-16 com Python 3.12 (Empresa Milionária, leitura de NFS-e, Task 2).

**Causa raiz:** o expat ainda reconhece o UTF-16 sozinho pelo padrão de NUL (`<\x00` ou `\x00<`) no que recebe, mesmo
vindo de um `str`. A frase "o parser ignora a codificação quando recebe str" vale para a **declaração**, não para essa
autodetecção. Quem decodificou foi o parser, não o módulo que devia decidir pelos bytes. O codec `utf-16` do Python sem
BOM ainda usaria a ordem de bytes da máquina.

**Solução:**

1. Antes de decodificar, recuse o UTF-16 sem BOM nas duas ordens, **com ou sem declaração** (`conteudo[:2] in (b"<\x00",
   b"\x00<")` ou declarado `utf-16` sem BOM). A mensagem deve nomear o BOM que falta, e nunca "UTF-8".
2. No reconhecimento de formato, aceite as duas ordens sem BOM como XML. Assim a recusa cita o BOM e não vira "formato
   desconhecido". A ordem LE já passava por acaso, porque o primeiro byte é `<`; a BE não passava.
3. Teste com conteúdo **só ASCII**. Com acento, a recusa por byte inválido de UTF-8 esconde o defeito e o teste passa pela
   razão errada. Controle antes da asserção: `bytes.decode("utf-8")` não levanta.
4. Sabotagem: tire a recusa e o teste fica vermelho em "DID NOT RAISE" nas quatro variantes; tire o reconhecimento do
   formato e ficam vermelhas só as duas BE.

**Como o revisor viu:** o R11 apontou o risco pelo motivo errado (supôs que o codec `utf-16` seria chamado sem BOM, e que
o efeito seria só uma recusa com motivo impreciso). A medição mostrou que o caso era **aceito**. Leia o achado como
indício e meça o comportamento antes de aplicar a sugestão.

**Complemento (16/09, Task 3 da mesma frente): espaço antes do `<` escapa da checagem de dois bytes.** Olhar só
`conteudo[:2]` pega `<` seguido de NUL e NUL seguido de `<`, mas não LE com espaço antes (espaço, NUL, `<`, NUL) nem BE
(NUL, espaço, NUL, `<`). Esses arquivos caíam em "formato desconhecido", e `decodificarXml` devolvia texto com NUL **sem
recusar**. Conserto: uma expressão por ordem de bytes que pula espaço, tab, CR e LF **na mesma ordem** antes do `<`, com
controles de que ordem misturada e espaço UTF-8 seguido de NUL **não** viram UTF-16. **Limite declarado:** a checagem
olha os primeiros 1024 bytes, então mais de ~510 caracteres de espaço antes do `<` voltam a "formato desconhecido". O
arquivo continua recusado, só que com o motivo genérico.
