## Workers Builds falha em todo push porque o diretório de assets é gerado e está no `.gitignore` {#workers-builds-sem-build-command-nao-acha-out}

`tags: cloudflare workers builds, CI, wrangler, assets directory, gitignore, next export, output export, build command, check-run github, deploy automatico, log inacessivel, 401 builds`

**Sintoma:** o build automático do Cloudflare Workers Builds falha em **todo push**, desde que a
integração foi ligada. O site no ar continua bem (porque alguém publica à mão), então ninguém sente —
e o repositório fica com o código sem publicar sozinho, que é justamente o que faltava para o handoff
ser completo.

**Causa raiz: o Workers Builds clona o repositório e roda `wrangler deploy`. Sem um passo de build,
o diretório apontado por `assets.directory` NÃO EXISTE naquele clone**, porque ele é gerado
(`output: 'export'` do Next escreve em `out/`) e está — corretamente — no `.gitignore`. Não há o que
publicar, e o deploy falha.

Os dois lados estão certos isoladamente, e é por isso que ninguém vê: `out/` **deve** estar no
`.gitignore` (é artefato gerado), e `assets.directory` **deve** apontar para ele. O que falta é o
passo que os liga, e ele não existe em lugar nenhum do repositório.

**⚠️ Não confunda com versão de Node.** Em projeto Next 14 é comum o build quebrar sob Node 24
(`useContext null` no prerender), então a primeira hipótese costuma ser essa. Descarte olhando
`.node-version` e `engines` — se já dizem 20, não é isso.

**Solução (no REPOSITÓRIO, não no dashboard):**

```jsonc
// wrangler.jsonc
"build": {
  "command": "npm run build"
}
```

O `wrangler` roda esse comando antes de publicar — no CI e localmente. 🔑 **Por que no repositório e
não no painel:** configuração de publicação que vive só no dashboard da conta é **invisível para quem
clona** e impossível de auditar; no arquivo, ela viaja com o código. Num projeto que está sendo
entregue a um cliente, essa diferença é o handoff.

**Como provar antes de subir**, no ambiente do CI (não na máquina de dev, que pode ter outro Node):

```bash
rm -rf out                       # o estado de um clone novo
npx wrangler deploy --dry-run --outdir /tmp/dry
ls out/index.html                # reapareceu => o build rodou
```

A saída marca as linhas do build com o prefixo `[custom build]` — é isso que se procura.

**🔑 O log do build parece inacessível e não é preciso:** o token de API costuma dar **401 em
`/accounts/{id}/builds/*`**, e sem o dashboard do cliente parece não haver diagnóstico possível. Mas o
Workers Builds **publica check-run no GitHub**, e ali estão o veredito, o horário e o Build ID:

```bash
gh api repos/<org>/<repo>/commits/<sha>/check-runs
```

Foi de lá que saiu a confirmação de que rodava e falhava em todo commit — e depois, o `success` que
provou o conserto. **Quando um lado fecha a porta, procure o outro lado da integração.**

**⚠️ Consequência que precisa ser dita ao operador:** com o build funcionando, **todo push passa a
publicar em produção, direto a 100%** — o CI roda `wrangler deploy`, sem o passo "sobe versão →
confere no preview → promove". É o objetivo, mas muda o que um push significa. Quem quiser publicar
com conferência precisa continuar usando o fluxo manual (`versions upload` → preview → `versions
deploy`).

**Relacionado:** [#deploy-worker-cloudflare-conta-de-cliente] (deploy no Worker da conta do cliente) ·
[#estado-atual-nao-prova-evento-passado] (procure o evento, não o inventário).

**Ref:** AutoWorx NJ / `website-autoworxnj`, 2026-08-19. Build `ba22a7df` (failure) → `42ddd35e`
(success, o primeiro da integração). R23.
