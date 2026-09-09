## Secret do Docker Swarm é imutável — trocar uma chave significa reescrever o env inteiro a partir de uma cópia que pode estar velha {#secret-do-swarm-e-imutavel-trocar-uma-chave-reescreve-o-env-inteiro}

`tags: docker swarm, secret, env, deploy, producao, drift, imutabilidade, risco de sobrescrita, R23`

**Sintoma:** pedem uma mudança trivial em produção — trocar o nome de exibição do remetente de
e-mail, ajustar um flag, corrigir um texto que vem do ambiente. Parece um `sed` de trinta segundos.
Mas o valor vive dentro de um secret do Swarm, e **não existe "editar uma chave"**.

**Causa raiz:** secret no Swarm é **imutável por design**. Não há `docker secret update`. O caminho é
sempre: criar um secret **novo**, apontar o serviço para ele e remover o antigo. E o conteúdo do
secret em execução **não pode ser lido de volta** — `docker secret inspect` devolve metadado, não o
valor.

Isso transforma uma edição de uma linha em **reescrever o arquivo de ambiente inteiro**, a partir da
cópia local que alguém tem no repositório. Aí mora o risco real:

> Se qualquer valor foi ajustado direto no servidor desde que a cópia local foi feita — uma senha
> rotacionada, um token de webhook reemitido, uma URL corrigida às pressas —, **reescrever o env a
> partir da cópia silenciosamente reverte esse ajuste**. O serviço sobe, o health check passa, e o
> que quebra é login, webhook ou banco, horas depois, sem relação óbvia com a mudança feita.

**Procedimento seguro, na ordem:**

1. **Ler o que o serviço realmente enxerga hoje** — é a única fonte confiável, porque o secret não
   pode ser lido, mas o processo que o consome pode:
   ```bash
   docker exec $(docker ps -qf name=<servico>) env | sort > /tmp/prod.env
   ```
2. **Comparar com a cópia local** e reconciliar cada divergência antes de tocar em qualquer coisa:
   ```bash
   diff <(sort infra/secrets/<arquivo>.env) /tmp/prod.env
   ```
3. Só então criar o secret novo, atualizar os serviços e remover o antigo.

**Regra:** nunca recrie um secret a partir de uma cópia de repositório **sem antes fazer o diff
contra o ambiente do processo em execução**. A cópia local é um palpite sobre produção, não um
espelho dela. O custo do diff é um comando; o custo de pular é uma reversão silenciosa de
configuração.

**Corolário de estimativa:** "é só trocar um texto no env" é uma estimativa errada em Swarm. O
trabalho não é a edição, é provar que a cópia local está sincronizada com produção.
