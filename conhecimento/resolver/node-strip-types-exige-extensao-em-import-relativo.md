## `node --experimental-strip-types` exige extensão no import relativo, e pôr `.ts` quebra o `tsc` {#node-strip-types-exige-extensao-em-import-relativo}

`tags: node, experimental-strip-types, typescript, ERR_MODULE_NOT_FOUND, esm, import relativo, tsx, docker exec, script de manutencao, runbook, R23`

**Sintoma:** um script TypeScript de manutenção roda na sua máquina e falha dentro do contêiner com

```
Error [ERR_MODULE_NOT_FOUND]: … url: 'file:///app/lib/insumos-iniciais'
```

O arquivo **existe** (`/app/lib/insumos-iniciais.ts`, confirmado por `ls`), e mesmo assim o Node não
o encontra.

**Por quê:** `--experimental-strip-types` só remove os tipos; ele não resolve módulo como o
TypeScript resolve. A resolução é a do ESM do Node, que **não completa extensão** em import
relativo. `import … from "../lib/insumos-iniciais"` procura um arquivo com esse nome exato e
desiste.

**A saída óbvia é uma armadilha.** Escrever `from "../lib/insumos-iniciais.ts"` faz o Node achar —
e quebra o `tsc --noEmit` do projeto:

> An import path can only end with a '.ts' extension when 'allowImportingTsExtensions' is enabled.

Ligar essa flag para acomodar um script de manutenção contamina a configuração do projeto inteiro.

### O conserto: use o runner que já está na imagem

Se o Dockerfile roda `npm ci` (e roda, porque precisa das devDependencies para buildar), o `tsx`
está lá. Ele resolve extensão como o TypeScript e não pede nada do projeto:

```bash
CID=$(docker ps -q --filter name=<servico> | head -1)
docker exec "$CID" sh -c 'set -a; . /run/secrets/<secret>; set +a; \
  ./node_modules/.bin/tsx prisma/backfill-insumos.ts'
```

Confirme antes, em vez de supor:

```bash
docker exec "$CID" sh -c 'ls node_modules/.bin | grep -x tsx || echo SEM-TSX'
```

Chame por caminho (`./node_modules/.bin/tsx`) e não por `npx` — `npx` pode tentar baixar da rede num
contêiner que não deveria ter saída.

🔑 **Não duplique o dado para fugir do import.** A tentação, ao ver `ERR_MODULE_NOT_FOUND`, é copiar
a constante para dentro do script e seguir a vida. Isso recria exatamente a duplicação que o script
provavelmente existe para consertar.

### O que isto ensina sobre runbook

O comando estava escrito no documento **antes de alguém rodá-lo**, e por isso estava errado. Runbook
que não foi executado é hipótese com aparência de instrução: custa a descoberta duas vezes — uma
para quem escreveu, outra para quem confiou. Ao registrar um comando novo, ou rode e cole a saída,
ou marque explicitamente que ainda não foi testado.

### Verbetes relacionados

- [[dado-inicial-que-so-o-seed-cria-nunca-chega-em-conta-real]]
