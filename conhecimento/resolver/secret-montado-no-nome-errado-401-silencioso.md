## Secret datado monta sob o nome errado: consumer toma 401 com serviço `healthy` {#secret-montado-no-nome-errado-401-silencioso}

`tags: docker secret, swarm, target, source, compose, reconcile, deploy, 401, invalid internal auth, pydantic, secrets_dir, rotacao de secret, AAAAMMDD, healthy mas quebrado, falso-verde, auth-service`

**Sintoma:** um consumer novo (ou recém-rotacionado) toma `401` do serviço, mesmo com o Docker Secret
criado, declarado no compose e o deploy tendo passado. `/health` responde `200`, o `docker service ls`
mostra `2/2`, o smoke do deploy passa, e **não há erro em log nenhum** — nem no serviço, nem no
Swarm. Quem olha o secret com `docker secret ls` o vê lá, e conclui que o problema é do consumer.

**Causa raiz:** o secret está montado, mas **com o nome de arquivo errado**. Swarm monta em
`/run/secrets/<target>`; quando o `target` não é passado, ele usa o `source`. O Pydantic
(`secrets_dir="/run/secrets"`) lê pelo **nome do campo** do `Settings`. Então:

```
source: internal_key_x_20260817   target: internal_key_x   -> /run/secrets/internal_key_x        OK
source: internal_key_x_20260817   (sem target)             -> /run/secrets/internal_key_x_20260817  INVISIVEL
```

O campo fica com o default (`""`), a comparação de secret não casa com nada, e o gate devolve `401`
— indistinguível de "chave errada". Isso morde exatamente quem segue o padrão de **rotação**
(`<nome>_<AAAAMMDD>` como source, nome do campo como target), que existe porque secret no Swarm é
imutável.

**O agravante que fez isso passar meses:** o reconcile de secrets do deploy lia só o `source:` do
compose e anexava com `target=$source`, **descartando o `target:` declarado**. Todo caso de teste
usava `source == target`, então a suíte ficava verde. Secrets datados antigos (`auth_database_url_*`,
`auth_redis_url_*`) só não quebraram porque foram anexados à mão, antes do reconcile existir.

**Diagnóstico em 1 comando** — compare declarado × montado, nunca só "o secret existe":

```bash
# o que o Swarm REALMENTE montou (source -> nome do arquivo)
docker service inspect <svc> \
  --format '{{range .Spec.TaskTemplate.ContainerSpec.Secrets}}{{.SecretName}} -> {{.File.Name}}{{"\n"}}{{end}}'
# e dentro do container, o que o app consegue ver:
docker exec <cid> ls /run/secrets/
```

**Solução:**
1. Conserto imediato, **pra frente** (não faça `rollback`: ele reverteria a imagem também, desfazendo
   um deploy legítimo por causa de um mount):
   ```bash
   docker service update --secret-rm <source> \
     --secret-add source=<source>,target=<nome-do-campo> <svc>
   ```
2. Conserto durável: o reconcile tem que **propagar o `target:` do compose**. Ao parsear YAML, use
   **fronteira de item**, não posição: YAML não garante ordem de chave, e `- target:` antes de
   `source:` faz um parser posicional colar o target na entrada anterior e **desaparecer** com a
   atual — sem erro e sem nem disparar "secret declarado mas ausente".
3. Guarda que fecha a classe: **verificação comportamental pós-rollout** que confronta cada `target:`
   declarado com o que o Swarm montou, e barra o deploy se faltar. Ela mede o resultado, não a
   intenção, então pega também sintaxe curta (`- nome`) e qualquer buraco futuro do parser. Prove nos
   **dois sentidos** — que passa no estado bom e que **dispara** quando você simula o mount errado.

**Armadilha ao escrever o lookup do target:** case por igualdade exata no nome, nunca por substring.
`internal_key_tiatendo` é prefixo de `internal_key_tiatendo_investidores`, e um `grep` frouxo casa o
errado — reintroduzindo o mesmo bug pela porta dos fundos.

**Ref:** auth-service, registro da audience `tiatendo-investidores`, 2026-08-17. Bug e conserto em
`dde2ca2` (`deploy/scripts/lib/secret-reconcile.sh` + `auth-service-deploy.sh`), 4 casos de teste
novos. Mesma assinatura "healthy mas quebrado" do P0 de CORS de 2026-07-30 e do incidente de rotação
de credenciais de 2026-07-23.
