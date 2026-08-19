## `.gitignore` não protege o tarball de deploy — sem `.dockerignore`, o `.env` viaja junto {#gitignore-nao-protege-o-tarball-de-deploy}

`tags: dockerignore, gitignore, deploy, segredo, api key, COPY, contexto de build, multi-stage, tarball, vazamento`

**Contexto:** Dockerfile com `COPY . .` e nenhum `.dockerignore`. O deploy empacota o diretório de
trabalho num tarball, sobe pro VPS e builda lá.

**O erro de raciocínio:** "o `.env` está no `.gitignore`, então está protegido". São **listas
diferentes**. O git ignora; o `tar` e o contexto de build **não**. Arquivo ignorado pelo git continua
no disco — e é exatamente ele que viaja.

**Medido uma vez:** `frontend/.env` com `DEEPSEEK_API_KEY` ia em todo deploy de frontend. O
multi-stage salva a **imagem final** (só o `dist` é copiado), mas a chave fica na camada do estágio
de build, no cache do daemon do VPS.

**Gate, e ele roda ANTES do upload:**

```bash
tar tzf pacote.tgz | grep -iE "\.env|\.auth|credential|\.pem|key"
```

Além do `.env`, cace **sessão viva de teste**: `e2e/.auth/*.json` do Playwright guarda access **e**
refresh token do operador.

**Conserto:** criar o `.dockerignore` cobrindo `.env*` (com `!.env.example` se o template for
necessário), `e2e/.auth/`, `node_modules/`, `dist/`, `test-results/`.

**Se já vazou:** rotacionar é decisão do operador, não sua — chave compartilhada entre projetos
derruba ferramenta em todos eles até a nova ser propagada.
