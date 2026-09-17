## Teto de bytes do upload NÃO limita o texto extraído dele — varredura linear sobre texto de PDF vira minutos {#teto-de-bytes-do-arquivo-nao-limita-o-texto-extraido}

`tags: pdf, pypdf, extract_text, teto, limite, upload, dos, custo, varredura, regex, redos, compressao, flate, texto extraido, boleto, R23`

**Sintoma:** o endpoint de upload recusa arquivo acima de 5 MB e acima de N páginas, a varredura do texto é linear
(sem quantificador aninhado, sem ReDoS) e mesmo assim uma leitura pode levar dezenas de segundos ou minutos. Nada
estoura: a requisição só demora, segura um worker e, repetida, vira negação de serviço barata.

**Reprodução real** (Empresa Milionária, linha digitável no texto do PDF, 2026-09-15): a busca por candidatos de 47/48
dígitos anda por grupos de dígitos e valida o dígito verificador de cada candidato. Medido com texto adversarial:
100 mil caracteres de dígitos soltos (`"1 1 1 …"` ou dígitos distintos) custam **1,5–3 s**; 1 milhão, **17 s**
(repetitivo) a **31 s** (distintos). Linear — 10× a entrada, 10× o tempo — e ainda assim inaceitável.

**Causa raiz:** o teto foi posto na grandeza errada. O stream de conteúdo do PDF é comprimido (Flate); `"1 1 1 …"`
comprime quase a zero, então 5 MB de arquivo cabem **muitos** megabytes de texto extraído. O custo da varredura é
função do texto, não do arquivo. É a mesma família da bomba de descompressão, só que o dano é CPU, não memória.

**Fix:**
1. **Teto na grandeza que o algoritmo paga:** caracteres por página extraída, checado **antes** de varrer (e antes de
   qualquer regex). Dimensione pelo documento real — uma página de boleto tem poucos milhares de caracteres — e decida
   explicitamente se o excesso recusa com motivo nomeado ou só não varre.
2. **Cache do passo caro por candidato** (`lru_cache` na validação) ajuda só texto repetitivo — no caso real cortou
   pela metade; dígitos distintos continuam lineares. É complemento, não correção.
3. **Meça com entrada adversarial em três tamanhos** (10 mil, 100 mil, 1 milhão) e com as duas formas — repetitiva e
   distinta. Medir só "não é exponencial" aprova o caso que derruba o worker.

**Ref:** Empresa Milionária, `empresa-api/app/casos_uso/leitura_boleto_texto.py` (2026-09-15) e plano
`2026-09-15-leitura-de-boleto-entrega-1.md` (teto de caracteres por página na Task 8). Irmão:
[mascara-de-segredo-por-regex-vira-caca-a-separador](mascara-de-segredo-por-regex-vira-caca-a-separador.md) (ReDoS e
teto de entrada em máscara de log).
