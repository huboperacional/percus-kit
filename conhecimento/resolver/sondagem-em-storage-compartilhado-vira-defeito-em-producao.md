## Sondagem de escrita em storage compartilhado vira defeito em produção quando a versão é promovida {#sondagem-em-storage-compartilhado-vira-defeito-em-producao}

`tags: cloudflare kv, r2, s3, preview url, binding compartilhado, artefato de teste, arquivo de sondagem, imagem quebrada, naturalWidth, varredura por status code, kv key list, limpeza pos-probe`

**Sintoma:** o site em produção serve um asset **quebrado** (imagem que não decodifica, arquivo minúsculo) num slot onde deveria estar o arquivo real. Nenhuma verificação acusou: as páginas respondem **200**, o asset responde **200**, e a suíte passa.

**Causa raiz — a sondagem foi feita numa URL de *preview*, e isso pareceu seguro.** Preview e produção rodam **códigos** diferentes, mas os **bindings de dados são os mesmos**: o mesmo namespace KV, o mesmo bucket. O isolamento da preview é de *versão*, não de *dado*. O arquivo de teste escrito "na preview" já estava, desde o primeiro segundo, no armazenamento de produção — só não era lido enquanto a produção rodava um código que não consultava aquele caminho. **Promover a versão nova é o instante em que o lixo antigo começa a ser servido.**

Caso medido em 2026-08-18: uma sondagem provou isolamento por slot subindo um WebP sintético de **112 bytes**, e o plano registrou o ETag `05ddea0e…` **como evidência de sucesso**. A chave nunca foi apagada. Quando a versão que lê o KV foi promovida, o apex passou a servir 112 bytes onde havia uma foto de 67.682 — em **3 pontos da home** e 1 do `/about` do site de um cliente, por ~3h30.

🔑 **Duas armadilhas que se somam, e a segunda é a que engana:**
1. **Documentar o artefato não é limpar o artefato.** O ETag do arquivo de teste estava escrito no plano; escrito como *prova*, não como *pendência*. Um valor registrado como resultado de medição não parece lixo.
2. **Varredura por status code é cega para isto.** `15/15 → 200` e "todos os assets 200" continuam verdadeiros: o arquivo quebrado **existe** e é servido com `200 image/webp`. O que enxerga é o **decodificador**: no navegador, `img.complete && img.naturalWidth === 0`. Contagem de página e código HTTP nunca acham asset corrompido.

**Solução:**
1. **Encerrar toda sondagem de escrita listando o armazenamento**, não confiando no delete da própria sondagem: `wrangler kv key list --namespace-id <id>` (ou `aws s3 ls`). Um namespace que deveria estar vazio e tem 1 chave responde a pergunta em um comando.
2. **Antes de promover qualquer versão que passe a LER um storage compartilhado, inventariar esse storage.** O estado de dados que a versão nova vai expor não é o que a versão velha expunha.
3. **Incluir uma varredura de asset decodificável** na verificação pós-deploy — navegador headless, `naturalWidth === 0` em todo `<img>`, em todas as páginas. É o único gate que separa "servido" de "renderiza".

⚠️ **Corolário para planos e specs:** ao registrar o hash/ETag de um arquivo de sondagem como evidência, registre **na mesma linha** que a chave precisa ser apagada — ou apague antes de escrever a linha. Evidência e pendência ficam idênticas no papel depois de algumas horas.

Relacionado: [verificacao-pos-deploy-mente-por-cache-de-borda](verificacao-pos-deploy-mente-por-cache-de-borda.md) · [deploy-worker-cloudflare-conta-de-cliente](deploy-worker-cloudflare-conta-de-cliente.md)
