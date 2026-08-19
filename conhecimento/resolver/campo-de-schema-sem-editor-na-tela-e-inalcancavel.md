## Campo novo no schema sem editor na tela é inalcançável — e a frente morre calada {#campo-de-schema-sem-editor-na-tela-e-inalcancavel}

`tags: schema, pydantic, extra forbid, config jsonb, formulario, editor ausente, feature morta, pre-mortem, destinos, recorte`

**Contexto:** um plano acrescentava duas chaves ao `config` JSONB de um destino (uma flag de recorte
e a moeda da conta), com validação no Pydantic e testes verdes. O passo de produção dizia
"marcar na tela de destinos".

**Causa raiz:** **a tela não tinha esses campos.** O form daquele destino expunha só o picker de
Customer ID — o editor do mapa de conversões tinha migrado para outra aba numa fatia anterior, e
sobrou ali apenas a *identidade* do destino. As duas chaves existiriam no schema, com teste, sem
nenhum caminho para o operador preenchê-las.

**Por que ninguém viu antes:** o schema aceitar a chave **parece** a feature pronta — o teste de
contrato passa, o `PATCH` funciona no curl, e o plano lê como completo. O elo que falta não está em
nenhum dos dois lados que a task olhou: está no **formulário**, que ninguém listou porque a task era
"de backend". Pior, o modo de falha é mudo: com a flag ausente, o recorte fica fechado e todo evento
é recusado pelo motivo genérico de sempre — sintoma idêntico ao de um bug de código.

**Como resolver:**
1. Ao acrescentar campo de configuração, **enumere os editores** antes de escrever a task:
   `grep` pelo campo irmão que já existe (aqui, `client_side_enabled`) e veja **quem escreve** —
   form, API, migration, seed. Se o campo irmão tem editor e o novo não, falta uma task.
2. Trate "quem preenche isto, pela mão de quem?" como pergunta de **plano**, não de deploy.
3. No passo de produção, **prove em banco** que a chave gravou (`SELECT config->>'campo'`) em vez de
   confiar no clique na tela — configuração marcada e não persistida tem o mesmo sintoma.
4. Se a decisão for deliberadamente *não* expor na tela, diga **quem grava então** (SQL, script,
   migration) e registre — senão vira estado invisível que ninguém sabe mudar.

**Sinal de que você está neste caso:** o plano manda "configurar na tela X" e nenhuma task do plano
tocou o componente daquela tela.
