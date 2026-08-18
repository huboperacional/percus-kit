## Deploy sobe código VELHO com tag NOVA: diretório de build compartilhado entre serviços {#build-dir-compartilhado-tag-nova}

tags: deploy, build on vps, docker, tag unica, git archive, diretorio compartilhado, codigo velho, rollout falso, frontend backend

**Sintoma:** você commita o fix, roda o deploy, a tag é nova, o `service update` converge, o
container fica `Running` — e **o defeito continua na tela**. Nada no output indica erro.

**Causa raiz:** o diretório de build na máquina remota (`/opt/<projeto>-build`) é **compartilhado
pelos deploys de todos os serviços** e fica na revisão de **quem arquivou por último**. O script de
um serviço fazia `git archive origin/master` antes de buildar; o do outro só entrava no diretório e
buildava. Deployar o segundo depois de um commit novo empacota a árvore ANTIGA com uma tag NOVA —
todos os sinais de sucesso presentes, conteúdo errado.

**Solução:** **re-arquivar dentro de cada script de deploy**, sem exceção, e **imprimir a revisão
empacotada** (`git rev-parse --short origin/master`) pra ela aparecer no log ao lado da tag. Tag
única não protege disto: ela prova que a IMAGEM é nova, não que o CÓDIGO é. Ao verificar um deploy,
compare o que está na tela com o COMMIT, não com a tag.

**Ref:** Plexco Tasks s150 (2026-07-26) — o frontend saiu 2x no commit errado antes de eu perceber.
Parente de [#verificar-runtime-nao-estrutura](verificar-runtime-nao-estrutura.md).

---
