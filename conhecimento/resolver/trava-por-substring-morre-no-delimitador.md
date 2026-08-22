## Trava validada por SUBSTRING morre quando a copy ganha negrito {#trava-por-substring-morre-no-delimitador}

`tags: trava, substring, markdown, negrito, asterisco, copy derivada, teste fragil, falso vermelho, smoke, normalizacao, reprova por formatacao`

**Contexto:** travas que afirmam contrato de copy quase sempre casam **substring literal**
(`"com o número" in card`). No dia em que a copy passa a ser **gerada** em vez de escrita à mão, o
gerador costuma aplicar ênfase — e `com o número` vira `com o *número*`. A substring deixa de casar.
A trava reprova **a formatação**, não a promessa, e manda o executor caçar um defeito que não existe.

**O caso medido (2026-08-22):** um rodapé de card passou a sair do módulo comum, que bolda a palavra.
Caíram **três testes de unidade e um caso de smoke ao vivo** na mesma rodada, todos com a mesma causa
e nenhum com defeito real por trás. O smoke foi o mais caro: reprovou depois de um deploy, e o
primeiro reflexo — correto por disciplina — é suspeitar do produto.

**Correção:** normalizar o delimitador **nos dois lados**, junto com o que já se normaliza (acento,
caixa).

```python
def _semAsterisco(t: str) -> str:
    return (t or "").replace("*", "")

# nos smokes, junto com o acento — ambos pelo mesmo motivo
def _semAcento(t: str) -> str:
    t = unicodedata.normalize("NFKD", (t or "").lower()).replace("*", "")
    return "".join(c for c in t if not unicodedata.combining(c))
```

**A regra geral:** trava de copy afirma **promessa**, não **apresentação**. Tudo que é decoração —
acento, caixa, negrito, itálico, emoji de abertura — sai antes de comparar. O que sobra é o que o
usuário precisa entender.

**A exceção que confirma:** quando o delimitador **é** o contrato (uma trava que verifica que um
exemplo está delimitado, para poder localizá-lo depois), aí ele não pode ser removido — mas essa
trava afirma "existe um trecho marcado", não "o texto contém esta frase".

**Sintoma:** o diff não toca a lógica, só a origem da copy, e um punhado de testes cai de uma vez com
mensagens de "não contém" citando um texto que visivelmente contém.

**Ver também:** [[sonda-que-nao-e-o-matcher-mede-outra-coisa]] ·
[[smoke-degradado-vs-errado]]
