## O dump de uma asserção não é a lista de culpados — leia a comparação, não o despejo {#dump-de-assercao-nao-e-lista-de-culpados}

`tags: teste, assertionerror, allowlist, scanner, dump, diagnostico, falso culpado, pytest, regressao, atribuicao errada`

**Contexto:** um teste-scanner compara um dicionário `found` (varrido do repo) com um `_ALLOWLIST`
travado à mão. Ao falhar, ele levanta `AssertionError` **despejando o dicionário inteiro** para você
colar de volta na allowlist. Três arquivos apareceram na saída e foram lidos como "os três que
divergem".

**Causa raiz:** **só um** divergia. Os outros dois estavam no despejo porque o dump é o `found`
completo, não o delta — a asserção imprime tudo sempre que qualquer chave difere.

**Por que ninguém viu antes:** o dump é convincente. Vem logo abaixo da linha `AssertionError`, tem
nome de arquivo e conteúdo, e a mensagem convida a copiá-lo — tudo comunica "isto aqui é o
problema". Ninguém compara chave a chave porque a saída já parece a resposta.

**Como resolver:**
1. Diante de um teste de comparação que falha, **compute o delta você mesmo** antes de agir: rode a
   função de varredura e faça `set(found) ^ set(esperado)`, ou compare chave a chave em script.
2. Cruze cada divergência com `git log --name-only <base>..HEAD`: **se o arquivo não foi tocado pela
   sua branch, não é sua regressão** — e se foi, é, por mais que um doc diga que a falha é antiga.
3. Quando escrever um scanner assim, faça a mensagem imprimir **o delta primeiro** e o dump depois,
   rotulado como "cole isto se a mudança for legítima".

⚠️ **O custo de errar é duplo:** você conserta arquivo que estava certo (e possivelmente quebra
outra coisa), e o culpado real segue solto. No caso original a atribuição errada foi propagada por
escrito para um documento de plano antes de alguém conferir.
