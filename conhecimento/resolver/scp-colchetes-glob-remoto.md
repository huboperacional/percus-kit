## scp pra caminho remoto com colchetes (`[id]` de rota Next) falha por glob no lado remoto {#scp-colchetes-glob-remoto}

`tags: scp, ssh, glob, colchetes, [id], next.js app router, upload vps, cat redirect, wc -c`

**Sintoma:** subir `src/app/batch/[id]/page.tsx` por `scp` falha ("no match") ou o arquivo não
chega onde deveria.

**Causa raiz:** o lado remoto do scp passa o caminho pelo shell — `[id]` vira classe de
caracteres de glob e o alvo deixa de ser literal.

**Solução:** `ssh host "cat > '/caminho/batch/[id]/page.tsx'"` com o conteúdo no **stdin**
(aspas simples no remoto; alvo de redirection não sofre glob). Conferir depois com `wc -c`
local × remoto. Foi a receita do deploy da FM sob uplink degradado (subir só os alterados,
NOVO antes do MODIFICADO, + `deploy_*_v2.py --quick`).

**Ref:** FM 2026-07-28 (deploy do frontend `20260728-004439`).
