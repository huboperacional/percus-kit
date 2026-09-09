## Harness de teste remoto que empacota a árvore pode deixar o âncora de config para trás — e as guardas somem em silêncio {#harness-remoto-empacota-sem-o-ancora-de-rootdir}

`tags: harness remoto, pytest, rootdir, conftest, confcutdir, pytest.ini, tar, empacotamento, guarda ausente, 2>/dev/null, falso verde, banco efemero, R23`

**Sintoma:** a suíte remota fica **verde**, com o mesmo número de testes, e mesmo assim roda com um
conjunto de guardas **diferente** do local. Nada falha; nada avisa.

**Causa raiz medida (tiatendo, 2026-08-31).** O script que empacota a árvore pro VPS fazia:

```bash
tar czf pacote.tgz --null -T lista.txt conftest.py pytest.ini 2>/dev/null \
  || tar czf pacote.tgz --null -T lista.txt          # <- fallback SEM os extras
```

Não existia `conftest.py` na raiz do repo. O `tar` inteiro falhava por causa do arquivo ausente, o
`2>/dev/null` **engolia o motivo**, e o fallback empacotava **sem o `pytest.ini`** — que era o
**único âncora de rootdir** do projeto. Sem ele, o `rootdir` remoto vira a pasta dos alvos, o
`confcutdir` vai junto, e o `conftest.py` de `tests/` fica **acima do corte**: some o gate da camada
paga, some a trava de banco e some o mock autouse de rede.

**Duas classes num achado só:**

1. **`A || B` com `2>/dev/null` transforma "faltou um arquivo" em "rode sem ele".** O fallback tem
   que empacotar o que EXISTE, não desistir de todos os extras:
   ```bash
   EXTRAS=""; for f in conftest.py pytest.ini; do [ -f "$f" ] && EXTRAS="$EXTRAS $f"; done
   echo "extras: ${EXTRAS:- (nenhum)}"      # <- imprime o que foi
   tar czf pacote.tgz --null -T lista.txt $EXTRAS
   ```
2. **Guarda que mora em conftest é função de ONDE o pytest acha o rootdir.** Se o único âncora do
   repo não viaja, o ambiente remoto não é o ambiente local, por mais idêntico que o código esteja.

**Como detectar sem confiar em prosa:** compare o **número de testes** do focal local com o do
remoto para os MESMOS alvos. Divergiu → o rootdir divergiu. (No caso medido, depois do conserto os
dois passaram a dar exatamente `147 passed`.)

**Ref:** tiatendo, 2026-08-31, commit `4665bd2`. Irmãos:
[#nome-fixo-de-container-faz-uma-rodada-destruir-a-outra]. R23.
