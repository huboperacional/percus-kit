## O wrapper de review diz "Sem findings críticos" por cima de uma chamada que FALHOU {#review-diz-sem-findings-por-cima-de-chamada-que-falhou}

`tags: review, R11, deepseek, percus-review-auto, 401, falso verde, gate, fact-check, INFUNDADO, jsonl cru, commit`

**Sintoma:** você roda a review obrigatória antes do commit e lê, no output principal:

```
## Findings DeepSeek (cross-provider review)

Sem findings críticos.
```

Verde. Você commita. **Mas a review não aconteceu.**

**Causa raiz:** quando o provider devolve erro de autenticação/saldo (`401`), o wrapper **não
propaga a falha para o output principal**. O erro vira um "finding" cujo arquivo é do **próprio
reviewer** (`deepseek_reviewer/providers/openai_compat.py:55`), o fact-check não consegue verificar
esse caminho — porque ele não existe no repositório revisado — e o classifica como **INFUNDADO**,
filtrando-o. Sobra a frase de sucesso.

Medido em 2026-08-24: a mesma review, repetida um minuto depois, passou. O `401` era transitório —
o que não muda nada: **a rodada falha e a rodada verde são indistinguíveis no output principal.**

**Como distinguir — o número que não mente:** leia o JSONL cru e olhe `reasoning_tokens`.

```bash
python -c "
import json,glob,os
f=max(glob.glob('.deepseek/reviews/*.jsonl'), key=os.path.getmtime)
d=json.loads(open(f,encoding='utf-8').read().strip().split(chr(10))[-1])
print('reasoning:', d.get('usage',{}).get('completion_tokens_details',{}).get('reasoning_tokens'),
      '| diff_lines:', d.get('diff_lines'))
print(d.get('findings'))
"
```

| leitura | veredito |
|---|---|
| `findings` menciona `providers/openai_compat.py` ou `status 401` | 🔴 **a review NÃO rodou** — repita, não commite |
| `reasoning_tokens` na casa das centenas/milhares, proporcional ao `diff_lines` | 🟢 a perna raciocinou de verdade |
| `reasoning_tokens` baixíssimo **e** `INFUNDADO` no Audit | 🔴 suspeite antes de aceitar o verde |

**Regra:** *o gate é a evidência de que a chamada ocorreu, nunca a ausência de vermelho.* É a mesma
classe do runner de teste que sai com `0` sem rodar nada — e vale mais aqui, porque a review é o
que autoriza o commit.

**Armadilha irmã, no mesmo output:** o fact-check filtra achados legítimos como `INFUNDADO` quando
não consegue verificar o caminho. Já custou os **melhores** achados de uma rodada. **Leia sempre o
`.deepseek/reviews/*.jsonl` cru**, não só o bloco principal — o aviso de `N finding(s) INFUNDADO(s)
filtrado(s)` é o convite pra abrir.

**Ref:** R11; [[fixture-que-mente-faz-a-mutacao-mentir-junto]] (mesma família: o instrumento mente
e o verde é do instrumento, não do sistema).
