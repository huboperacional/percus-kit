## O repo pode não ser a fonte do que roda em prod — compare md5 antes de copiar {#o-repo-pode-nao-ser-a-fonte-do-que-roda-em-prod}

`tags: drift, ops, watchdog, deploy, fonte da verdade, md5sum, canonico multi-projeto, copia obsoleta, /opt, regressao silenciosa, PROBES`

**Contexto:** uma task de deploy começava com o passo mais inocente possível — *"copie
`ops/watchdog/watchdog.sh` do repo para `/opt/<projeto>-watchdog/` no host"*. O arquivo estava
versionado, o teste dele passava, o repo era o do produto. Nada sugeria perigo.

**O que a medição achou:** o arquivo do host tinha **14.739 bytes** e o do repo **10.477**. E o
backup `watchdog.sh.bak-20260730-190404` no próprio host tinha **exatamente 10.477** — ou seja, o
repo era a versão que o host tinha **substituído um mês antes**. Copiar teria apagado quatro semanas
de watchdog vivo: três sondas (`check_api`, `check_home`, `check_cors_watch`), uma guarda contra
`REALERT_6H=0` (*"daria division by 0 e desligaria em silêncio o re-alerta perpétuo"*) e um `main`
multi-projeto que itera `$PROBES` em vez de uma lista fixa.

**Causa raiz:** o script era **canônico e multi-projeto** — o mesmo arquivo rodando em `/opt` em
quatro produtos, com md5 idêntico nos quatro. A fonte morava num quinto repo (`Melhoria na VPS`),
que declara no próprio cabeçalho *"NÃO editar na VPS"*. O repo do produto carregava uma **cópia**
de antes da convergência, e nada no repo dizia que era cópia. Havia quatro delas: `watchdog.sh`,
`alert_lib.sh`, `test_watchdog.sh` e `alert.env.example` — todas menores que a fonte.

**Por que passa despercebido:** um arquivo versionado dentro do repo do produto *parece* ser a
fonte. O teste dele passa (ele testa a cópia). O `git log` mostra história (a da cópia). E o
comando de deploy é `cp`, que não compara nada. O drift não aparece em `git status`, porque as duas
pontas estão limpas — cada uma na sua versão.

**O agravante que fecha o ciclo:** os testes escritos contra a cópia **mediram um dublê**. Ao
apontá-los para a fonte real, dois reprovaram na hora — a função que eles exercitavam nem existia
lá. Verde contra cópia obsoleta é a mesma família de `SKIPPED` lido como `PASSED`.

**Diagnóstico (dois comandos, antes de qualquer `cp`):**
1. `md5sum <arquivo-do-repo>` e `ssh host "md5sum /opt/.../<arquivo>"`. Iguais → siga.
2. Diferentes → **pare** e descubra quem está à frente. `ls -la /opt/...` costuma resolver: um
   `.bak-<data>` com o tamanho do seu arquivo é a prova de que o host já o substituiu.
3. Se o mesmo arquivo roda em mais de um host, compare os md5 **entre hosts** também. Idênticos
   entre si e diferentes do repo = canônico compartilhado, e o repo é consumidor, não dono.

**Correção:** apagar as cópias do repo do produto e deixar um README apontando para a fonte, com a
tabela de tamanhos medidos para ninguém recriá-las. O que é específico do produto fica; o que é
canônico sai. Testes locais resolvem a fonte por variável de ambiente e, se não a acharem, **pulam
se declarando** — nunca fingem PASS.

**Sinal de que o repo é consumidor e não dono:**
- o mesmo arquivo existe em vários `/opt/*` com md5 idêntico;
- o cabeçalho do arquivo diz onde ele é versionado (leia o cabeçalho antes de copiar);
- existe um deployer dedicado (`*_deploy.py`) com `--verify` que compara host × repo;
- o repo do produto não tem histórico das mudanças recentes que o host tem.

**Não confundir com:** [carimbo_existe_mas_nao_anda] (o dado existe e não anda) nem com worktree
atrasado. Aqui os dois lados estão íntegros e versionados — o que falta é saber **qual dos dois é
a fonte**, e essa pergunta não se responde por inspeção do repo sozinho.

Relacionados: [[a-sabotagem-prova-o-que-voce-imaginou]]
