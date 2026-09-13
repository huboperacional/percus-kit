## Escrita atômica (temporário + `os.replace`) leva o MODO do temporário: `mkstemp` cria `0600` e o destino herda {#escrita-atomica-tmp-rename-leva-o-modo-do-temporario}

`tags: escrita atomica, tempfile, mkstemp, os.replace, permissao, chmod, umask, threads, to_thread, race, bind mount, R23`

**Sintoma:** depois de trocar `open(path, "w")` por escrita atômica (temporário no mesmo
diretório + `os.replace`), o arquivo passa a ter modo `0600` — ou, se é arquivo **novo**, nasce
`0600` em vez do `0644` que o processo criava antes. Outro usuário, container ou processo que lia
o arquivo perde a leitura, e a falha aparece longe de quem escreveu.

**Reprodução real** (tiatendo, 2026-09-13, frente de lock do YAML de tenant): a review R11
apontou, a partir do contrato documentado do `tempfile.mkstemp` ("readable and writable only by
the creating user ID"), que o `_replaceAtomic` novo promoveria `0600` a todo YAML de tenant num
bind mount compartilhado. Corrigido **antes** do deploy — não houve arquivo `0600` em produção.
A correção precisou de **três** rodadas, e as duas últimas são o que torna este verbete útil:
1. copiar o modo do destino antes do rename — que só cobre **sobrescrita**;
2. arquivo **novo** continuava `0600` (não há destino de onde copiar);
3. o conserto óbvio do item 2, `u = os.umask(0); os.umask(u)` na hora da escrita, é **race**:
   `umask` é estado GLOBAL do processo, e as escritas tinham acabado de ir para
   `asyncio.to_thread`. Duas threads no meio do par deixam o processo inteiro com umask `0`
   (arquivos world-writable) — a correção anterior criou a condição para a race.

**Causa raiz:** `os.replace`/`rename` troca a entrada de diretório pelo **inode do temporário**,
que carrega o próprio modo e dono. `mkstemp` cria esse inode com `0600` de propósito (evita que
outro usuário leia o temporário). O `open(path, "w")` antigo criava pelo umask e, na
sobrescrita, preservava o inode (e o modo) do destino — a troca de técnica muda as duas coisas.

**Solução:**
```python
import os, stat
_UMASK = os.umask(0); os.umask(_UMASK)   # UMA vez, no import, antes de existir thread

def _replaceAtomic(path, escrever):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", suffix=".partial")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            escrever(f); f.flush(); os.fsync(f.fileno())
        if os.path.exists(path):
            st = os.stat(path)
            os.chmod(tmp, stat.S_IMODE(st.st_mode))      # S_IMODE: sem os bits de TIPO
            # como root, preserve o dono também: os.chown(tmp, st.st_uid, st.st_gid)
        else:
            os.chmod(tmp, 0o666 & ~_UMASK)               # o que o open(w) antigo fazia
        os.replace(tmp, path)
    except BaseException:
        try: os.unlink(tmp)
        except OSError: pass
        raise
```

**Contra-regra:**
- Arquivo que **deve** ser `0600` (`.env`, chave) já é `0600` no destino — copiar o modo do destino
  preserva isso. Não "conserte" forçando `0644`.
- A captura do umask no import só é segura se o módulo é importado **antes** de qualquer thread.
  Import tardio (dentro de função chamada por `to_thread`) reabre a janela — escreva no comentário
  qual importador garante a ordem, porque nada no código a garante.
- Relacionado: [[bind-mount-de-arquivo-prende-o-inode-e-o-replace-nao-chega-no-container]] — o
  outro efeito colateral da mesma técnica, visto do lado do container.
