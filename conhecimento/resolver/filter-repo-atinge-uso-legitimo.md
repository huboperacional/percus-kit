## Reescrever histórico para tirar segredo: o `--replace-text` também acerta onde a string era legítima {#filter-repo-atinge-uso-legitimo}

tags: git filter-repo, replace-text, BFG, reescrita de historico, segredo no historico, credencial vazada, rotacionar senha, path-rename, detector de segredo, bundle, backup, secret scanning

**Contexto:** o repositório carrega uma credencial (ou dado pessoal) em commits antigos, e você
roda `git filter-repo --replace-text` para removê-la de todo o histórico. A operação funciona —
e produz três efeitos colaterais que ninguém antecipa, porque a substituição atinge **todos os
blobs**, inclusive aqueles em que a string existia por um bom motivo.

**Os três efeitos, em ordem de gravidade:**

1. **O detector de segredo é desarmado.** Se você tinha um teste que falha quando a credencial
   reaparece (`re.compile(r"mi_user|SENHA_X")`), a reescrita troca a string **dentro do
   detector**. Ele continua verde e não detecta mais nada. Um guard silenciosamente morto é pior
   que guard nenhum.
   **Solução:** escreva o padrão de forma que case sem conter a literal — `r"mi[_]user"` casa
   `mi_user`, mas uma busca literal por `mi_user` não encontra o arquivo. Assim o detector
   sobrevive à própria reescrita.

2. **Fixture de teste que usava a credencial vira lixo.** Achamos um caso de teste com a senha
   real de produção dentro de uma URL de exemplo. Depois da reescrita virou
   `redis://:<CREDENCIAL-REMOVIDA>@host` — sintaticamente válido, semanticamente sem sentido.
   Troque por valor obviamente fictício.

3. **A documentação que descrevia o vazamento fica sem sentido** — e, antes disso, ela **era**
   parte do vazamento. Ao registrar a pendência de segurança, é tentador colar a credencial para
   deixar claro do que se trata. Não faça: documentar um vazamento reproduzindo o segredo cria um
   segundo vazamento, num arquivo que ninguém trata como sensível. Descreva sem citar.

**Procedimento que funcionou:**

```bash
# 1. Backup COMPLETO antes — a operação é irreversível e reescreve todas as refs.
git bundle create ../backup-antes-da-reescrita.bundle --all
git bundle verify ../backup-antes-da-reescrita.bundle    # confirme "complete history"

# 2. Arquivo de substituições (literal==>substituto), do mais específico ao mais genérico.
#    "Nome Completo==>Pseudonimo" ANTES de "Nome==>Pseudonimo", senão o sobrenome sobra.

# 3. Rodar (o repo precisa estar limpo). --path-rename tira o nome também do CAMINHO:
#    --replace-text só mexe no CONTEÚDO dos blobs, nunca no nome do arquivo.
python -m git_filter_repo --replace-text repl.txt \
  --path-rename caminho/antigo.py:caminho/novo.py --force

# 4. Verificação que vale: ler TODOS os blobs, não só `git log -S`.
git rev-list --objects --all \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' \
  | awk '$1=="blob"{print $2}' \
  | while read b; do git cat-file blob "$b" | grep -q "SEGREDO" && echo "AINDA EM $b"; done
```

⚠️ `git log -S` responde rápido e **não é prova suficiente**: ele encontra commits onde a
contagem da string mudou, não todo blob que a contém. A varredura por blob é a que fecha a
questão.

**O que a reescrita NÃO faz, e é o mais importante:**

> **Reescrever histórico não invalida credencial.** A senha continua válida no serviço, e
> continuou existindo em qualquer clone, fork, backup ou pipeline que copiou o repositório antes
> da limpeza. A reescrita é higiene do repositório; **a rotação é a correção de segurança**.
> Entregar "histórico limpo" como se o incidente estivesse resolvido é relatório falso.

Consequência operacional: **todos os hashes de commit mudam**. Referências a commits antigos em
documentos, mensagens de commit e issues deixam de resolver. Se houver remoto, todo mundo precisa
reclonar — por isso o custo é baixíssimo antes do primeiro push e alto depois.

**Ref:** Empresa Milionária, 2026-08-12. 18 commits, 868 blobs, credencial de produção herdada
por fork mais nome de cliente real. Irmão: [#sed-identidade-falsifica-historico] — a mesma classe
de erro (substituição em massa que acerta o alvo errado), agora no histórico em vez da árvore.
