## Arquivo VAZIO escapa de toda checagem feita em `awk`: sem registros, `FNR==1` nunca dispara {#arquivo-vazio-escapa-de-checagem-por-awk}

`tags: awk, FNR, arquivo vazio, zero bytes, gate, guarda cega, escrito e invisivel, validacao por arquivo, xargs, shell, test -s`

**Sintoma:** uma checagem que valida arquivos um a um aprova um arquivo que **não tem nada dentro**.
O arquivo existe, está no lugar certo, não tem título, não tem conteúdo — e nenhuma violação é
emitida. Exit 0.

**Causa raiz:** `awk` processa **registros**, e um arquivo de zero bytes não tem nenhum. Toda a
lógica pendurada em `FNR == 1` (resetar estado, marcar "arquivo atual", carregar o nome) **nunca
executa** para esse arquivo. Ele nunca vira o `atual`, nunca é finalizado, e portanto nunca é
avaliado. Não é bug do `awk`: é a semântica dele. Quem valida por arquivo numa passada única precisa
saber que a passada só visita arquivos com pelo menos uma linha.

**Agravante:** a checagem costuma vir acompanhada de outra que compara o conjunto de arquivos com um
índice/manifesto. Se o arquivo vazio **estiver** listado lá, essa segunda checagem também aprova — e
as duas juntas dão a impressão de cobertura dupla.

**Como reproduzir em 10 segundos:**

```sh
mkdir -p t/area && printf '## Ok {#ok}\ntags: a\n' > t/area/ok.md && : > t/area/vazio.md
cd t && sh <caminho-do-gate>        # exit 0, vazio.md passa
```

**Solução:** aferir o tamanho no shell, **antes** de montar a lista que vai pro `awk` — e acusar ali
mesmo, não tentar resolver dentro do `awk`:

```sh
if [ ! -s "$_f" ]; then
  violacao "$_f -- arquivo vazio"
  continue
fi
```

⚠️ **A classe é maior que `awk`.** Qualquer validador orientado a conteúdo (parser de YAML, leitor de
JSON com `|| true`, linter que só reporta o que encontra) aprova o vazio por omissão. **A pergunta de
teste é sempre a mesma: "o que este validador faz com um arquivo de zero bytes?"** — e ela merece um
caso de teste próprio, porque o vazio nunca aparece nos fixtures que a gente escreve à mão.

**Relacionado:** [erro-de-ferramenta-engolido-por-redirecionamento](erro-de-ferramenta-engolido-por-redirecionamento.md)
— outra forma de guarda que sai 0 sem ter verificado nada.

**Ref:** percus-kit 6.38.0, 2026-08-18. Achado pelo review R11 e **confirmado empiricamente antes do
conserto**: plantado um `vazio.md` num repo de teste, o gate saiu 0. Bloco 2 do
`v2/gates/percus-gate.sh`.
