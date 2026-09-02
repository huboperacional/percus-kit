## Lista cortada por `tail`/`head` vira conclusão "essa é a lista toda" — confira pelo EFEITO, não relendo {#lista-truncada-vira-conclusao-completa}

`tags: diagnostico, truncagem, inventario, erro de ausencia, R23`

**Sintoma:** você enumera recursos (contas, filas, tabelas, serviços), age sobre o que enumerou, e
depois descobre que faltava item — justamente o maior.

**Caso real (2026-09-02).** Listar `customer_client` de uma MCC do Google devolveu 36 contas. A
saída passou por `| tail -40` e as primeiras linhas foram cortadas. Contei **5** contas do cliente,
cadastrei as 2 que faltavam, e declarei a lista completa. Havia **6** — e a sexta era a de maior
volume de campanha do cliente.

**Por que reler não resolve.** O erro não é de leitura, é de **evidência incompleta que parece
completa**: uma lista truncada tem exatamente a mesma forma de uma lista inteira. Reler a mesma
saída confirma o mesmo recorte. Foi assim que a premissa anterior ("essa conta não está no nosso
MCC", escrita 15 dias antes) sobreviveu tanto tempo: ela também nasceu de uma medição real cuja
conclusão nunca foi conferida contra a pergunta direta.

**O que pegou o erro: conferir pelo EFEITO.** Depois de cadastrar as contas, o aviso de "campanhas
que não existem em conta nenhuma" **continuava listando as campanhas campeãs**. Foi essa
discordância — não uma releitura — que revelou a conta faltante. A busca seguinte varreu as 36
contas procurando quem era dona daquelas campanhas, e a sexta apareceu.

**Como aplicar:**

- Ao inventariar, **nunca trunque a saída** (`tail`/`head`/`| head -n`) antes de contar. Se for
  grande, agregue no lado do servidor (`count(*)`, `group by`, filtro por nome) em vez de cortar no
  cliente.
- **Sempre imprima o total ao lado da amostra**: `36 contas, mostrando 10` deixa a truncagem
  visível; 10 linhas soltas, não.
- **Feche o laço por um efeito observável independente** — um aviso que deveria sumir, um contador
  que deveria zerar, uma cobertura que deveria fechar. Se o efeito não mudou como você previu, sua
  enumeração está incompleta, e isso é informação melhor que qualquer releitura.
- Suspeite especialmente quando a conclusão for **negativa** ("não existe", "não temos acesso",
  "não está cadastrado"). Ausência é o que a truncagem fabrica de graça.
