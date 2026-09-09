## `Paragraph` do reportlab interpreta markup dentro de texto de usuário {#reportlab-paragraph-interpreta-markup-em-texto-de-usuario}

`tags: reportlab, pdf, paragraph, xml injection, markup, razao social, ValueError, geração de documento, escape`

**Contexto:** gerador de PDF interpola dado de usuário (razão social, nome de cliente, descrição)
direto num `reportlab.platypus.Paragraph(f"... {texto_do_usuario} ...")`. Funciona no teste com
nomes "normais" e quebra em produção com `ValueError: paragraph text '...' caused exception
Parse error: saw </para> instead of expected </b>` pra um cliente específico.

**Causa raiz:** `Paragraph` interpreta um SUBCONJUNTO de markup tipo-XML (`<b>`, `<i>`, `<font>`,
`<br/>`, entidades `&amp;`/`&lt;`) como formatação — não é texto opaco. Um dado de usuário que
contenha algo parecido com uma dessas tags (ex.: razão social digitada errado, campo colado de
outro sistema, nome com `<` sem fechar) faz o parser interno tentar casar abertura/fechamento de
tag e estourar quando não bate.

**Medido empiricamente (não suponha, teste):** um `&` OU `<` SOLTOS, sem formar uma tag
reconhecida, **não quebram** — o parser é tolerante a esses dois casos isolados. O que quebra é
formar uma tag CONHECIDA sem fechamento correspondente (`"ATLAS <B> CIA LTDA"` quebra; `"ATLAS &
CIA LTDA"` não). Isso significa que testar só com `&` no nome NÃO reproduz o bug — é preciso um
caso que pareça uma tag válida.

**Fix:** escapar todo texto de usuário que entra num `Paragraph`, sempre:
```python
from xml.sax.saxutils import escape
Paragraph(f"Pacote — {escape(nome_da_empresa)}", estilo)
```
Custo zero, sem efeito colateral em texto sem markup.

**O que NÃO precisa do mesmo cuidado:** células de `reportlab.platypus.Table` com string pura
(não um objeto `Paragraph` dentro da célula) não passam pelo parser de mini-XML — só `Paragraph`
passa. Se a tabela usa `Paragraph` dentro de célula (comum pra permitir quebra de linha), aplique
o mesmo `escape()` lá também.

**Ref:** Empresa Milionária, `app/modules/relatorios/gerador_pacote_mensal.py` — achado no
review R11, reproduzido e confirmado por teste dedicado (`"ATLAS <B> CIA LTDA"` como razão
social fictícia) antes de aplicar o fix, e sabotado depois pra confirmar que o teste pega a
regressão.
