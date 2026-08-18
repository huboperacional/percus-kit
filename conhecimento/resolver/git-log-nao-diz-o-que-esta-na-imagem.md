## A ordem do `git log` NÃO diz o que está na imagem: quem diz é a HORA do `git archive` {#git-log-nao-diz-o-que-esta-na-imagem}

`tags: deploy delta, git archive, commit fora do ar, ordem do log enganosa, sessao paralela, branch compartilhada, imagem defasada, verificar dentro do artefato`

**Sintoma:** um commit aparece no `git log` **antes** do commit de deploy e mesmo assim **não está
em produção**. A leitura natural do log ("está abaixo, logo entrou") é falsa.

**Causa raiz:** num deploy delta o conteúdo vem de `git archive HEAD` executado num **instante**. Se
outra sessão commitar entre esse instante e o seu commit de deploy, o commit dela fica **cronologia
acima** no log e **fora** do tar. O log ordena por parentesco/tempo do commit, não pelo que foi
empacotado.

**Solução:**
1. **Gere o archive imediatamente antes do build**, e não no começo do procedimento.
2. **Verifique DENTRO do artefato**, nunca no log: `docker exec <cid> test -f /app/<arquivo-novo>` e
   `grep -c <simbolo-novo> /app/<arquivo>`. Arquivo novo é o detector mais barato.
3. A trava de árvore (manifesto de hashes HEAD × imagem, entre `build` e `service update`) pega isto
   **se** o manifesto for gerado no mesmo instante do archive — gerado antes, ela aprova o atraso.
4. Em branch compartilhada, registre no handoff **o commit-base do archive**, não "os N últimos".

**Ref:** tiatendo, deploy `0.308.0` (2026-08-16): `ea645b2` ficou de fora e só apareceu ao testar
`comanda.py` dentro do container. Ver também `#deploy-delta-base-defasada`.
