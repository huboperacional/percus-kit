## Deploy delta com base defasada REVERTE feature entregue — e o smoke de feature não pega {#deploy-delta-base-defasada}

`tags: deploy delta, imagem base, COPY parcial, feature revertida, bisseccao de imagem, manifesto de hashes, CRLF LF, falso positivo, default silencioso, log por assinatura`

**Sintoma:** features marcadas `[5-T]` com smoke em produção NA ÉPOCA simplesmente não estão mais lá semanas/dias depois. No caso: 5 features (widget de estoque, nav, e 3 da vitrine da loja) mortas em produção por ~23h, incluindo **zero ocorrências na página pública que o cliente final vê**.

**Causa raiz:** deploy delta (`FROM <imagem-base>` + `COPY` só dos arquivos mudados) usando uma base ANTERIOR às features já entregues. Tudo que entrou entre a base e a atual não é apagado — é **nunca copiado**. O serviço sobe, `/health` responde 200, e o smoke da feature nova passa.

**Por que fica invisível:** o consumidor da função sumida chamava dentro de um `_safe(..., [])`. O card mostrava "sem alertas", que é *indistinguível* de "está tudo em estoque". O único sintoma era 1 linha de ERROR por minuto num log que ninguém lia.

**Solução:**
1. **Bissecção nas imagens** acha o instante exato, sem adivinhação:
   `docker run --rm --entrypoint grep <img>:<versao> -c "def minhaFuncao" /app/caminho.py` em cada versão.
2. **Comparar a ÁRVORE INTEIRA**, não a feature: manifesto de hashes do HEAD × árvore da imagem, rodado **entre `docker build` e `docker service update`**. Smoke de feature prova que a NOVA subiu; só o diff de árvore prova que as ANTIGAS sobreviveram.
3. **Normalizar fim de linha antes de hashear.** Sem isso, manifesto gerado no Windows (CRLF) contra imagem via `git archive` (LF) acusa TODO arquivo de texto — 158 falsos positivos na 1ª execução real. Falso positivo em massa MATA a trava: na 2ª vez que grita sem motivo, alguém a remove do processo.
4. Se for usar base rasa/antiga pra evitar `max depth`, o `COPY` tem que levar a árvore inteira, não o diff.

**Regra geral:** `except`/default silencioso transforma bug de deploy em bug invisível. Ao varrer produção atrás de falha engolida, agrupar o log por assinatura (`sed` normalizando ids + `sort | uniq -c`) revela em segundos o que passa despercebido linha a linha.

**Ref:** tiatendo, imagens `0.226.0`→`0.232.0`. Trava: `scripts/verifyImageMatchesHead.py`.
