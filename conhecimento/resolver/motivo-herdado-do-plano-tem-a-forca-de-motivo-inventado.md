## Motivo herdado de um plano aprovado tem a mesma força de motivo inventado — e é mais perigoso {#motivo-herdado-do-plano-tem-a-forca-de-motivo-inventado}

tags: plano, spec, justificativa herdada, motivo nao medido, relaxar assinatura, chamador que nao existe, documento aprovado, autoridade do artefato, medir antes de executar

**Contexto:** o plano da task diz o que fazer **e por quê**. Você executa e, ao documentar,
copia a justificativa dele — para o comentário do código, para a mensagem do commit, para o
ledger. É o comportamento que o processo pede: a decisão fica rastreável até onde foi tomada.

O problema é quando a justificativa descreve um **caminho que não existe**.

**Caso real.** O plano mandava relaxar uma assinatura pública — tornar um parâmetro
`autorId` opcional — com o motivo escrito:

> *"há chamador legítimo sem autor humano — o fluxo ESPELHADO, em que ninguém na empresa par
> assinou nada"*

Executei, e repeti o argumento no docstring, no teste e no rastreamento. O review pediu para
medir. **O fluxo espelhado não passa por aquele caso de uso**: ele grava direto, num método
próprio, e o módulo do espelho **não menciona o parâmetro em lugar nenhum** — as citações ao caso
de uso ali eram comentários.

Sem chamador que precisasse, a mudança só ampliava a superfície de erro: qualquer chamador futuro
que esquecesse o parâmetro gravaria o registro **sem o evento de auditoria e sem erro** — a
omissão silenciosa que a retenção de cinco anos existe para impedir, introduzida por uma linha
que se justificava com auditoria.

**Causa raiz:** um plano aprovado carrega autoridade de artefato — foi revisado, foi decidido,
está versionado. Isso desliga a pergunta *"isto é verdade hoje?"*, que é diferente de *"isto foi
decidido?"*. E planos envelhecem entre a escrita e a execução: outra task muda o desenho, um
caminho é movido, uma classe nasce em outro módulo.

### O teste, e ele custa segundos

**Toda justificativa do plano que afirme a existência de um chamador, caminho ou arquivo é
hipótese até o `rg`.**

```bash
# o plano diz que ESTE caso de uso e chamado pelo fluxo X?
rg -n 'NomeDoCasoDeUso' app/ | grep -v '^app/casos_uso/nome_do_caso_de_uso.py'
# so comentarios? entao o chamador nao existe
```

Se a varredura não achar o chamador que o motivo afirma, **a mudança não tem justificativa** —
independentemente de o plano estar aprovado. Não é desobedecer ao plano: é descobrir que ele
descreve um estado que mudou, e reportar isso.

### Por que é pior que motivo inventado

Motivo que você mesmo escreveu você desconfia. Motivo herdado de documento aprovado você
**propaga** — e a propagação é o dano: ele vai para o comentário do código, para o commit e para
o ledger, e ali ganha ainda mais autoridade. Quem ler depois encontra a mesma afirmação em três
lugares independentes e conclui que foi verificada três vezes.

⚠️ **A mesma coisa acontece na citação.** Um documento correto pode virar afirmação falsa quando
alguém o cita e acrescenta a metade que ele não dizia — um hash registrado corretamente, citado
com um dono que o registro nunca atribuiu. Quem lê a citação herda o erro sem conseguir
rastreá-lo até o arquivo, porque no arquivo ele não está.

### Como registrar quando o motivo cai

Não apague o motivo antigo em silêncio. Escreva que ele **era falso e por quê** — a próxima
pessoa que ler o plano vai encontrar a mesma frase lá, e precisa saber que ela já foi medida e
derrubada. Ver [[conselho-acerta-a-conclusao-e-erra-a-premissa]], que é a mesma falha vista do lado de quem
RECEBE o argumento.
