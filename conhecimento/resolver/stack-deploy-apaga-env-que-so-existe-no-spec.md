## `docker stack deploy` apaga toda env que existe só no spec do serviço — e a pior perda é a que não derruba nada {#stack-deploy-apaga-env-que-so-existe-no-spec}

`tags: docker, swarm, stack deploy, service update, env, variavel de ambiente, compose, env_file, credencial, whatsapp, falha muda, load_dotenv, deploy que quebra prod, interpolacao`

**Sintoma:** não há sintoma — é o problema. O serviço roda há meses, sobrevive a dezenas de deploys,
e um dia alguém roda `docker stack deploy` (ou o `deploy.sh` do projeto, ou o "rollback de flag" que
o próprio compose manda fazer num comentário) e a aplicação cai — **ou pior, não cai**.

**Causa:** `docker stack deploy` **reconcilia o serviço contra o arquivo compose**. Toda variável de
ambiente que está no spec do serviço e **não** está no compose é **removida**. Já
`docker service update --image` **preserva** a env existente — e é por isso que a divergência
sobrevive indefinidamente sem dar sinal: o caminho de deploy praticado não a exercita.

Medido no tIAtendo em 2026-09-08: o serviço tinha **15** chaves de env, o compose declarava **7**.
As 8 órfãs tinham chegado ali por `--env-add` manual ou por um `stack deploy` de um compose antigo,
e **sobreviveram a 26 deploys** por `service update --image`.

### O que torna isto caro: as perdas MUDAS

Separe as 8 por como falham, porque só metade avisa:

| perda | como se manifesta |
|---|---|
| `DATABASE_URL` | container cai no boot — **barulhenta**, alguém percebe em minutos |
| credencial de mensageria (`GOWA_BASIC_AUTH`, `GOWA_WEBHOOK_SECRET`) | 🔴 **app fica de pé, `/health` responde 200, e as mensagens param** |
| flags de negócio (`LEDGER_*`) | comportamento muda sem erro nenhum |

🔑 **Consertar só a barulhenta é pior que não consertar.** Ela é a que dá o alarme; matá-la sozinha
produz a sensação de que o risco foi resolvido e deixa as mudas de pé. Se for consertar, conserte a
classe inteira ou declare em voz alta o que ficou.

🔑 **`/health` não é smoke suficiente aqui.** O único discriminante para a perda muda é um **turno
real de ponta a ponta** pelo canal afetado.

### As duas saídas, e a que parece melhor não é

1. **Sincronizar o arquivo `.env`** que o container monta (o app o lê por `load_dotenv`, que **não
   sobrescreve** variável já presente no ambiente). Ataca o sintoma.
2. **Declarar as chaves no compose.** Ataca a causa.

🪤 **`env_file:` parece a resposta óbvia da opção 2, e tem um custo escondido:** ele é
**tudo-ou-nada**. Injeta **todas** as chaves do arquivo no spec do serviço — no caso medido, 68,
incluindo senha de root do servidor, token de git e chave secreta de gateway de pagamento. Elas
saem de um arquivo montado e passam a aparecer em `docker service inspect` e a ficar no raft do
Swarm.

**A alternativa cirúrgica:** declarar **só as que faltam** com interpolação obrigatória —
`- MINHA_CHAVE=${MINHA_CHAVE:?mensagem dizendo qual falta}`. Injeta apenas o necessário, **não põe
valor nenhum no arquivo rastreado pelo git**, e **falha alto** quando a chave não existe, coisa que
`env_file` não faz. Para flag booleana não-secreta, `${FLAG:-1}` preserva o comportamento atual sem
bloquear o deploy.

### 🚨 A armadilha que só aparece depois: consertar a causa DEPENDE do sintoma

No momento em que o compose passa a declarar as chaves, **o arquivo `.env` vira a FONTE delas** (é
de lá que a interpolação lê). Se esse arquivo tiver valores **velhos** — e ele costuma ter, porque
ninguém o mantinha —, o `stack deploy` passa a **injetar a credencial errada com toda a
fidelidade**. Trocar *"apaga a variável"* por *"escreve a variável errada"* não é melhora.

**Portanto: sincronizar o arquivo é PRÉ-REQUISITO da correção de causa, não alternativa a ela.**
Descobrir isso depois de considerar as duas como opções excludentes custa um deploy quebrado.

### Como medir, sem imprimir segredo

Compare **por hash**, nunca por valor:

1. chaves do serviço: `docker service inspect <svc> --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}' | cut -d= -f1 | sort`
2. chaves do compose: extraia os nomes do bloco `environment:`
3. a diferença é o que o `stack deploy` apagaria
4. para cada chave em comum, compare `sha256(valor)[:8]` do spec × do arquivo, e **imprima só o
   hash e o comprimento** — nunca o valor

⚠️ E confira se o arquivo tem **aspas** em volta dos valores: o `--env-file` do Docker **não as
remove**, então uma aspa no arquivo vira aspa dentro da senha.

⚠️ **Um corolário que vale sozinho:** se o app usa `load_dotenv`, o arquivo `.env` montado **não é**
necessariamente o que o processo usa — variável já presente no ambiente vence. Um container one-shot
que monte só o arquivo pode falhar com credencial inválida enquanto o serviço vivo funciona
perfeitamente, e a diferença **não** aparece em `docker exec <cid> env` de forma óbvia.
