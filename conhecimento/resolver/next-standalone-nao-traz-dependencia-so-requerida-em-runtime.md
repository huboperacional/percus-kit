## O `output: 'standalone'` do Next monta a imagem por SUPOSIÇÃO — e o pacote que falta só falha quando um cliente executa a linha {#next-standalone-nao-traz-dependencia-so-requerida-em-runtime}

`tags: next, nextjs, standalone, outputFileTracing, docker, imagem de producao, MODULE_NOT_FOUND, nodemailer, dependencia ausente, turbopack, require externo, defeito latente, erro que mente sobre a causa`

**Sintoma:** o `package.json` declara a dependência, `npm ci` a instala, o build passa, a imagem
sobe, o health check responde 200 — e **o pacote não está na imagem**. O bundle do servidor saiu com
`require("pacote")` (externo, não embutido) e o rastreamento do Next não copiou o diretório para
`.next/standalone/node_modules`.

Como `require` de módulo ausente só é avaliado quando aquela linha executa, o defeito fica latente
até alguém percorrer o caminho. No caso real, o caminho era "mandar o código de confirmação do
contrato": **falhava exatamente com o cliente esperando na tela**.

**Por que engana o diagnóstico:** o erro é `MODULE_NOT_FOUND`, que não se parece nada com o problema
que se está investigando. O caso real tinha **dois defeitos empilhados** — credencial de SMTP
recusada pelo Google (`535-5.7.8`) e o pacote ausente. O de cima escondia o de baixo, e as medições
anteriores tinham sido feitas em contêiner avulso com `npm i`, não pela imagem que servia o site. A
medição não estava errada; estava no caminho errado.

**Como confirmar em 10 segundos**, no contêiner que está servindo:

```bash
C=$(docker ps --format '{{.Names}}' --filter label=com.docker.swarm.service.name=<servico>)
docker exec "$C" node -e "require('<pacote>')" && echo OK
```

E dentro da imagem, para ver o tamanho do buraco:

```bash
docker run --rm --entrypoint sh <imagem>:latest -c "grep -rl <pacote> /app | head; ls node_modules | wc -l"
```

Se o `grep` acha o nome nos chunks de `.next/server/` e o `ls node_modules` não acha o diretório, é
exatamente este defeito.

**Solução, e a parte que importa é a segunda:**

1. Copiar o pacote no `Dockerfile`, do estágio que tem `node_modules` completo:
   `COPY --from=deps /app/node_modules/<pacote> ./node_modules/<pacote>`
   (confira as dependências transitivas do pacote — no caso real o `nodemailer` 9 tem zero, o que
   torna a cópia de um diretório suficiente).
2. **Provar no build que a imagem resolve o que vai precisar:**
   ```dockerfile
   RUN node -e "for (const m of ['<pacote>','pg']) { require.resolve(m); console.log('resolve ok:', m) }"
   ```

🔑 **A lição é maior que o Next: o standalone é uma LISTA DE SUPOSIÇÕES sobre o que a aplicação usa.**
Suposição não se confere lendo o `package.json` nem o log do build — se confere **resolvendo, no
runtime da própria imagem**. Sem essa linha, o próximo pacote que o rastreamento perder volta a ser
descoberto por um cliente, meses depois. Vale igual para bundler que externaliza (`serverExternalPackages`),
para `pnpm deploy`, e para qualquer imagem "enxuta" montada por análise estática.

**Parente:** [#defeito-latente-aceito](defeito-latente-aceito.md),
[#credencial-valida-e-canal-morto-nao-sao-a-mesma-falha](credencial-valida-e-canal-morto-nao-sao-a-mesma-falha.md).

**Ref:** Salas Flex, 2026-08-21. `Dockerfile` e `docs/mock-audit.md` do projeto.
