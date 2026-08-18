## Regex de escrita `\.campo\s*=` casa o primeiro `=` de uma COMPARAÇÃO `==` {#regex-de-escrita-casa-comparacao}

tags: regex atribuicao, casa comparacao, falso positivo em varredura, auditoria de codigo por regex, igual duplo

**Sintoma.** Uma varredura que procura escrita (`\.dataPagamento\s*=`) acusa uma função que só LÊ
(`where(L.dataPagamento == hoje)`), e o inventário nasce com sítio fantasma. Pior que o ruído: o
falso positivo é indistinguível de achado real, então ou alguém "conserta" código correto, ou passa
a ignorar a varredura inteira.

**Fix.** `=(?!=)` em todos os ramos de atribuição:

```python
_ESCRITA_RE = re.compile(
    r"\.status\s*=(?!=)\s*[\"'](pago|recebido)[\"']|"
    r"\.valorPago\s*=(?!=)|\.dataPagamento\s*=(?!=)|"
    r"pagarProximaParcela\(|pagarParcela\("
)
```

**Como saber que pegou.** Um teste que afirma o NEGATIVO com a linha real de leitura:
`assert _ESCRITA_RE.search("select(L).where(L.dataPagamento == hoje)") is None`. Sem ele, a
correção do regex é indistinguível de nunca ter tido o problema.

**Contexto.** Família Milionária, 2026-08-14: o regex sem o lookahead devolvia 10 sítios de escrita;
com ele, 9 — o extra era `_jaPagoHoje`, uma função de leitura pura.
