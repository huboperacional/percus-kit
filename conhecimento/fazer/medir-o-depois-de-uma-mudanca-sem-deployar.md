## Medir o "depois" de uma mudança em produção SEM deployar {#medir-o-depois-de-uma-mudanca-sem-deployar}

`tags: gate, dry-run, deploy, docker, container, producao, medicao, PYTHONPATH, APP_PATH, nao-regressao, R20, R23`

**Quando usar:** você tem um gate de não-regressão que compara ANTES × DEPOIS contra dados reais de
produção (dry-run de perda, diff de atribuição, mudança de fórmula). O "antes" você captura fácil. O
"depois" exige o código novo rodando — e a tentação é deployar primeiro e medir depois. **Isso é
medir o risco depois de tê-lo corrido**: se o gate reprovar, produção já está com a regressão.

**Pré-requisitos:** um serviço containerizado cujo código seja interpretado (Python, Node) e um
segredo que só existe no ambiente do serviço (chave-mestra, DSN) — que é justamente o motivo de você
não conseguir rodar a medição na sua máquina.

**Procedimento:**

1. **Confirme que a imagem em produção é o seu ponto de partida.** Sem isso você mede
   "produção + suas mudanças + mudanças de outra pessoa" e atribui tudo a você:

   ```bash
   git diff --stat <commit-da-imagem> <seu-commit-base> -- <caminho/do/servico>
   # vazio = a imagem tem exatamente o codigo de onde voce partiu
   ```

2. **Copie o app para um diretório temporário DENTRO do container** e sobrescreva só os arquivos
   mudados. O serviço não é tocado — ele já importou os módulos dele na subida:

   ```bash
   docker exec $CID sh -c 'rm -rf /tmp/appnew && cp -r /app /tmp/appnew'
   # ... escreve os arquivos novos em /tmp/appnew/...
   ```

3. **Transfira arquivo grande em PEDAÇOS.** `base64` de um módulo de 120 KB estoura o limite de
   argv do SSH (`Argument list too long`). Fatie em ~24 KB, `printf %s <pedaco> >> /tmp/x.b64` por
   pedaço, e `base64 -d` no fim. Confira a sintaxe no Python **da imagem** (`ast.parse`) antes de
   rodar — a versão dela pode ser mais velha que a sua.
4. **Faça o script de medição honrar um caminho configurável**, e **valide-o**:

   ```python
   _APP = os.environ.get("APP_PATH") or "/app"
   if not os.path.isfile(os.path.join(_APP, "<pacote>/<modulo-marco>.py")):
       raise SystemExit(f"APP_PATH invalido: {_APP!r}")
   print(f"[codigo] medindo contra {_APP}", file=sys.stderr)
   sys.path.insert(0, _APP)
   ```

5. **Rode chamando o orquestrador REAL**, nunca uma reimplementação do pipeline: uma cópia pode
   divergir dele exatamente no ponto que o gate deveria vigiar.
6. **Prove que mediu o código novo por uma marca que só o código novo produz** — um valor de enum
   novo na saída, um campo novo, uma contagem impossível antes. Não confie na variável de ambiente
   ter funcionado.
7. **Limpe** (`rm -rf /tmp/appnew /tmp/b64`) e só então deploye.

**Saída do dado:** imprima o resultado legível em `stderr` e o dado em **uma linha base64** em
`stdout` (`MARCA:<base64>`) — terminal com codepage errado corrompe acento e quebra o JSON. E se o
resultado carregar dado de cliente, ele vai para um diretório **ignorado pelo git**; o commit leva o
**script**, nunca o resultado.

Validado em 2026-08-30 (Paid Media Automation, gate G1 da frente de Lead Ads). Requer janela **R20**
aberta — é leitura de produção. Ver também
[[gate-que-coage-tipo-aprova-a-regressao-que-deveria-barrar]].
