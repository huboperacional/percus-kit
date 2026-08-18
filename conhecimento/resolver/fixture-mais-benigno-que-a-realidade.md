## Fixture mais benigno que a realidade: o teste passa e você precisa PIORAR o fixture para ver o bug {#fixture-mais-benigno-que-a-realidade}

`tags: fixture, teste passa sem aferir, falso verde, quebra de linha final, trailing newline, estado impossivel, repo sem arquivo, reproducao, TDD, RED que nao e RED, caso degenerado`

**Sintoma:** você escreve o teste do bug que o revisor apontou. Ele **passa de primeira**. A tentação é concluir "o revisor errou" ou "já estava consertado". Nos dois casos medidos abaixo, o bug era real e o teste é que não o alcançava.

**Causa raiz:** o fixture modelava um estado **mais bem-comportado do que a realidade** — às vezes um estado que nem existe em produção. Dois casos reais, na mesma sessão:

| Fixture | Por que escondia | Realidade |
|---|---|---|
| Arquivo terminando **com** quebra de linha final | o `split` gera um elemento vazio no fim, e o índice nunca era a última posição do array | o caso degenerado só ocorre **sem** quebra final |
| Repo de teste **sem** o arquivo monolito | a checagem "existe entrada e o destino sumiu" nunca disparava | repo real **sempre** tem o monolito |

O segundo é o mais insidioso: o fixture representava um estado **impossível**, e quatro testes rodavam contra ele havia horas, verdes, aferindo um mundo que não existe.

**Solução — a pergunta que resolve os dois:** *"que propriedade do fixture está impedindo o bug de aparecer?"* Depois **remova essa propriedade**, mesmo que o fixture fique mais feio. Um fixture bonito e benigno mede menos que um feio e realista.

**O sinal de alarme é o RED que não vem.** Em TDD, teste novo que passa de primeira **não é boa notícia** — é a informação de que ele não alcança o alvo. Antes de aceitar, force o defeito de propósito (mutação) e exija ver vermelho. Se não ficar vermelho, o defeito está fora do alcance do fixture, não ausente do código.

**Como escolher o fixture:** copie a forma do artefato **real** — mesma quebra de linha, mesmos arquivos presentes, mesma codificação, mesmo estado de git. Divergência de forma entre fixture e produção é onde o bug se esconde, porque é exatamente a região que nenhum teste cobre.

**Vizinhos, e a diferença entre eles:**
[#fixture-uniforme-esconde-irregular](fixture-uniforme-esconde-irregular.md) — lá o fixture é regular demais e esconde a **irregularidade do domínio**; aqui ele é benigno demais e esconde o **caso degenerado da estrutura**.
[#teste-nasce-verde-vazio-regex-primeiro-match](teste-nasce-verde-vazio-regex-primeiro-match.md) — lá quem não alcança é o **regex de extração**; aqui é o **dado de entrada**.

**Ref:** percus-kit 6.36.6, 2026-08-16 — mesclador da caixa de conhecimento; os dois casos foram apontados pelo review R11 e só reproduziram depois de o fixture ser piorado de propósito.
