## Escrita remota multi-linha vinda do Windows chega com CRLF e corrompe crontab/.sh/.env {#stdin-text-mode-crlf-remoto}

`tags: subprocess, text=True, input, CRLF, 
, crontab, ssh, windows, newline translation, vpsx, infra compartilhada, command not found`

**Contexto:** script Python no Windows que escreve arquivo numa VPS Linux por SSH
(`subprocess.run([...ssh...], text=True, input=conteudo)`), inclusive `cat > arquivo` e `crontab -`.

**Sintoma:** o arquivo remoto fica com `
` no fim de TODA linha. Um `.sh` deixa de passar no
`bash -n`; um `.env` vira `CHAVE=valor
` (host/senha errados); um **crontab** vira
`/opt/x/run.sh
`, que o `sh` lê como `run.shr` → *command not found* e o job simplesmente para —
**inclusive os jobs de outros projetos**, se o crontab for compartilhado.

**Causa raiz:** em modo TEXTO (`text=True`), o Python no Windows traduz `
` → `

` **na
escrita** do stdin. Não é o SSH nem o Linux: é a camada de texto do próprio Python.

**Solução:**
1. Mandar stdin em **bytes**: `input=conteudo.encode("utf-8")`, sem `text=True`, decodificando
   `stdout`/`stderr` na mão. Corrige na origem, para todos os chamadores.
2. Defesa em profundidade no destino: `cat > f && sed -i 's/
$//' f`, na MESMA cadeia.
3. Nunca `crontab -` direto: vá por `mktemp`, normalize lá, **confira** (`tr -cd '
' < f | wc -c`)
   e só então instale — relendo depois pra comparar.
4. Detector portável: `tr -cd '
'` ou `grep "$(printf '
')"`. **Não** use `grep $'
'`: é
   sintaxe de bash e passa mudo em `dash`, dando falsa segurança exatamente onde você quer certeza.

**Armadilha:** o script imprime "instalado" e tudo parece certo. A verificação que vale é rodar o
**interpretador** contra o resultado (`bash -n`), olhar **bytes** (`od -c`) e conferir permissão
(`stat -c %a`) — não a própria saída do script.

**Ref:** `D:\Claud Automations\Kommo-Disparo-WhatsApp\libpsx.py` (`sh()`),
`execution/instalar_cron_divergencia.py`, `tests/test_vpsx.py`. Incidente de 2026-08-13.
