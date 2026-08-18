## O próximo número de migration NÃO é `max(main)+1` — são TRÊS fontes, e a terceira é o índice {#proximo-numero-de-migration-nao-e-max-da-main}

tags: migration, git, sessao-paralela, indice-compartilhado, numeracao

**Sintoma:** `ls execution/database/migrations/` mostra `115` como maior número, você cria a `116`, e
ela colide com uma `116` que já existe — numa branch não mergeada, ou pior, **staged no índice por
outra sessão, sem commit nenhum**.

**Por que o instinto erra:** `ls` na `main` só enxerga o que pousou. Numeração de migration é um
**namespace global do repositório**, não da branch; e ele é reservado no momento em que alguém
escreve o arquivo, não no momento em que commita.

**As três fontes, e a que quase todo mundo esquece é a 3ª:**

1. **Histórico commitado, `main` ∪ branches** — `git log --all`
2. **Índice compartilhado** — arquivo `git add`-ado por outra sessão e **ainda sem commit**. Não
   aparece em `git log --all` (não existe commit), mas o número **já está tomado**.
3. **Árvore de trabalho** — arquivo criado e nem stageado ainda.

**O comando que cobre as três:**

```bash
{ git log --all --diff-filter=A --name-only --format= -- execution/database/migrations/
  git ls-files execution/database/migrations/
  ls execution/database/migrations/ | sed 's|^|x/|'
} | grep -oE "[0-9]{3}" | sort -un | tail -1
```

**Medido no tiatendo, 2026-08-18** — os três degraus deram números diferentes no mesmo instante:
`ls` na main → **115** (a 116 vivia numa branch) · `git log --all` → **116** · `git ls-files` →
**117** (a 117 estava **staged por outra sessão**, sem commit). O próximo livre era **118**, e só a
3ª fonte revelava isso. Duas frentes tinham escrito "migration 116" no plano, e um alarme de colisão
que eu levantei estava certo no fato e errado no número.

🔑 **A classe é maior que migration:** todo recurso numerado sequencialmente e reservado por escrita
(porta, índice de ordem, id de fixture) tem o mesmo problema quando há sessão paralela. Pergunte
sempre *"quem mais pode ter reservado isso sem ter commitado?"*.

**Ref:** tiatendo 2026-08-18, frente G6/sonda de dependências; correção do operador sobre a
numeração 116/117/118.
