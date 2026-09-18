## `rg` com âncora de fim de linha contou ZERO numa linha que existe — e zero por instrumento é igual a zero por ausência {#rg-com-ancora-de-fim-de-linha-conta-zero-em-linha-que-existe}

`tags: rg, ripgrep, grep, windows, git bash, âncora, regex, CRLF, crlf, autocrlf, sed, xxd, cat -A, fim de linha, medição zero, controle positivo, sabotagem, alvo, busca literal, R23`

> ⚠️ **CORRIGIDO em 18/09/2026.** A primeira versão deste verbete (`2c1ea84`, 17/09) afirmava que a causa **não** era
> CRLF. **Era.** O erro e o instrumento que o produziu estão na seção "Causa" — e são a lição mais útil daqui.

**Sintoma:** você confere se um trecho existe antes de mexer nele — alvo de sabotagem, linha citada por um plano,
ocorrência que uma guarda deveria pegar — com `rg` e um padrão ancorado dos dois lados. A saída vem **vazia**, exit 1.
Você conclui "não existe" e muda de estratégia: troca o alvo, declara a sabotagem impossível, ou "corrige" um plano que
estava certo. Medido em 17/09/2026 (Empresa Milionária, Task 14 da leitura de NFS-e, validando o alvo da sabotagem S3),
Git Bash no Windows:

```
rg -c '^    leitura_id: uuid\.UUID \| None = None$' app/modules/pj/schemas.py   # -> nada, exit 1
rg -c '^    leitura_id: uuid\.UUID \| None = None'  app/modules/pj/schemas.py   # -> 1
grep -F -n '    leitura_id: uuid.UUID | None = None' app/modules/pj/schemas.py  # -> 80: ...
```

A única diferença entre a primeira e a segunda é o `$` final. Trocar `\|` por `[|]` não muda nada: com `$` dá zero,
sem `$` dá um.

**Causa: o arquivo estava em CRLF, e o `$` do `rg` não casa antes do `\r`.** Experimento controlado em 18/09, com o
MESMO conteúdo (o blob do `HEAD`, LF) e uma cópia convertida para CRLF:

```
arquivo LF,   padrão com $        -> 1
arquivo CRLF, padrão com $        -> 0      <- o sintoma
arquivo CRLF, rg --crlf, com $    -> 1
```

O repositório tem `core.autocrlf=true` e o working tree é **misto** (medido em 18/09: `schemas.py` e `titulo.py` em
CRLF, `main.py` e outros em LF) — ferramenta de edição que grava CRLF deixa o arquivo assim, e o `git status` segue
limpo porque o autocrlf normaliza na comparação.

**Por que a primeira versão errou — é a parte que vale guardar.** Em 17/09 "provei" LF puro com `sed -n 80p | xxd`
(linha terminando em `0a`, sem `0d`) e com `sed ... | cat -A` (sem `^M`). **Os dois passam pelo `sed` do Git Bash, que
tira o `\r` na leitura.** No experimento de 18/09, `sed -n Np | xxd` sobre o arquivo CRLF mostra a mesma linha terminando
em `0a`. O instrumento era cego exatamente ao que eu queria medir, e eu tratei a cegueira como prova — e escrevi,
com ênfase, que "a explicação intuitiva seria a errada". Quem lesse a versão antiga aprenderia a NÃO suspeitar de CRLF.
Mesma família de `grep-c-cr-no-git-bash-mente.md`, que já mandava contar bytes por Python.

**Por que é perigoso:** a falha vai na direção ruim. Uma busca que erra para mais deixa você conferindo achado falso —
custa tempo. Esta erra **para menos**, e "saída vazia, exit 1" é exatamente o que uma busca legítima sem resultado
produz. Não há sinal nenhum distinguindo "não existe" de "meu padrão não casou". É a mesma família de
*pipeline quebrado vira medição zero* e de *sabotagem que outra guarda absorve nunca fica vermelha*: o instrumento
devolve o número que confirma a hipótese, e nada acende.

**Solução:**

- Para conferir **existência de trecho literal**, use busca literal: `grep -F` ou `rg -F`. Regex só quando você precisa
  de regex de verdade.
- Precisou de âncora de fim de linha? Use `rg --crlf`, ou rode **a mesma busca sem a âncora como controle positivo**.
  Contagens diferentes acusam o instrumento (ou o fim de linha), não a ausência do trecho.
- **Fim de linha se mede por bytes, em Python:** `open(p, 'rb').read().count(b'\r\n')`. Nunca por `sed`, por `cat -A`
  depois de `sed`, nem por `grep` do Git Bash — todos podem esconder o `\r`. E não presuma: com `core.autocrlf=true` o
  working tree pode ser misto.
- **Antes de afirmar uma CAUSA, faça o experimento que a derrubaria**, não só o que a sustenta. Aqui bastava converter
  uma cópia para CRLF e rodar o mesmo padrão.
- Antes de declarar "o alvo não existe" — em sabotagem, em varredura de guarda, em contagem de ocorrências —
  **confirme com um segundo instrumento**. Um `grep -F -n` custa segundos e devolve a linha, que é prova, não contagem.
- Em script de sabotagem, prefira comparar **bytes** (`conteudo.count(alvo)`) a chamar `rg`: o script já precisa
  do byte exato para substituir, e a mesma comparação serve de conferência de unicidade. **Com alvo de várias linhas,
  converta `\n` para `\r\n` quando o arquivo tiver CRLF** — senão o alvo nunca casa e a sabotagem é recusada como
  impossível (aconteceu na S1 da mesma task, em 18/09, antes do conserto).

**Verbetes relacionados:** `rg-minusculo-r-e-replace-nao-recursivo.md`, `rg-com-barra-inicial-no-git-bash-conta-vazio.md`,
`grep-c-cr-no-git-bash-mente.md`, `sabotagem-que-nao-aplica-reporta-verde.md`.
