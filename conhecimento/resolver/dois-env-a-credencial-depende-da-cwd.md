## Repositório com DOIS `.env`: a credencial que vale depende do diretório de onde você sobe a app {#dois-env-a-credencial-depende-da-cwd}

tags: dois env, env_file relativo a cwd, credencial errada, variavel preenchida nas duas leituras, pydantic settings env_file

**Sintoma:** uma credencial "está no `.env`" — o operador confirma, você confirma lendo o arquivo
— e mesmo assim a aplicação se comporta como se ela estivesse errada ou ausente. Ou pior: funciona
na sua máquina, rodando de um diretório, e falha no deploy, rodando de outro. A variável está
preenchida nas duas leituras, então nenhum diagnóstico baseado em "existe/não existe" acha nada.

**Causa raiz:** `pydantic-settings` com `SettingsConfigDict(env_file=".env")` resolve esse caminho
**relativo à CWD do processo**, não ao arquivo que declara o `Settings`. Num monorepo com
`raiz/.env` e `raiz/servico/.env`, subir de `servico/` lê um arquivo e subir da raiz lê o outro.
Se a mesma variável existir nos dois com valores diferentes, você tem duas verdades e nenhuma
mensagem de erro. Vale igual para `dotenv`, `docker compose --env-file` e afins.

**Como confirmar (evidência, ~30s) — compare por HASH, nunca imprimindo o valor:**
```bash
python - <<'PY'
import pathlib, hashlib
ALVO = "MINHA_CHAVE"
for c in ["servico/.env", ".env"]:
    p = pathlib.Path(c)
    if not p.exists(): print(f"{p}: nao existe"); continue
    for n, l in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if l.strip().startswith("#") or "=" not in l: continue
        nome, _, v = l.strip().partition("=")
        if nome.strip() == ALVO:
            v = v.strip().strip('"').strip("'")
            print(f"{p}:{n} len={len(v)} sha256[:12]={hashlib.sha256(v.encode()).hexdigest()[:12]}")
PY
```
Hash diferente entre os dois arquivos = você achou. Compare também com o que o `Settings`
**carrega de fato** — é ele que decide, não o arquivo que você abriu.

**Distinguir "digitação quebrada" de "outro segredo": conte coincidência por POSIÇÃO.** Duas
strings hex aleatórias de 64 chars coincidem em ~4 posições (1/16 × 64). Se der ~4, não é erro de
cópia da outra — é outra credencial, e a pergunta muda de "conserta o typo" para "de onde veio
esta".

**Armadilha que fecha o cerco: endpoint anti-enumeração responde IGUAL para os dois erros.**
Serviços de auth costumam responder `202 Accepted` tanto para "enviei" quanto para "descartei
porque a conta não existe" — de propósito, para não virar oráculo de quem tem conta. Consequência
prática: **chave errada e chave certa produzem o mesmo status HTTP.** Um smoke que valide pelo
código de resposta passa nos dois casos. A prova é o efeito observável do outro lado (a mensagem
chegar, a linha nascer no banco), nunca o status.

**🔴 A armadilha que inverte o diagnóstico: "a chamada funcionou, logo a chave é minha" é FALSO.**
Num serviço multi-consumer, o segredo **é** a identidade de quem chama — o resolver compara o
header contra **todos** os secrets registrados e devolve o consumer que casar. Apresentar a
credencial de OUTRO produto não dá 401: dá **200, atendendo você como aquele produto**. O dado
nasce com a `origin` errada, no lugar errado, sem erro nenhum. Aconteceu de verdade: um teste de
provisionamento devolveu `identity_id`, isso foi lido como "minha chave é válida", e a conclusão
saiu invertida a ponto de quase apagar a credencial certa por "desconhecida".

**Corolário para diagnóstico:** sucesso de credencial bearer prova que **ela** vale, nunca **de
quem** ela é. Só quem guarda os secrets pode dizer de quem é — peça o `sha256[:12]` calculado
dentro do serviço e compare com o seu. É a única forma de casar sem trocar segredo por mensagem.

**Solução:** uma credencial, um dono. Apague a duplicata em vez de sincronizar as duas — variável
sincronizada à mão diverge na primeira rotação, e a divergência é invisível. Se os dois arquivos
precisarem mesmo do valor, faça o segundo derivar do primeiro (symlink, `env_file` explícito e
absoluto, ou Docker Secret único), não copiar.

**Ref:** Empresa Milionária, Task 16, 2026-08-14. O operador salvou a chave no `.env` do projeto
que a GEROU (auth-service) e depois uma segunda, diferente, no `.env` da RAIZ do consumidor — a que
funcionava estava numa terceira posição. Descoberto comparando hashes; nenhuma leitura de arquivo
sozinha teria mostrado.
