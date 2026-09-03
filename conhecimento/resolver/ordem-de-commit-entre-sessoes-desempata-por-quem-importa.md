## Ordem de commit entre sessões: desempata quem IMPORTA, não quem declara {#ordem-de-commit-entre-sessoes-desempata-por-quem-importa}

`tags: multi-sessao, arvore compartilhada, ordem de commit, ImportError, colecao, pathspec, arquivo untracked, arbitragem`

**Sintoma:** duas sessões na mesma árvore editaram os mesmos arquivos compartilhados, e as duas
têm arquivos novos ainda não commitados. Quem commita primeiro?

**O caso** (Empresa Milionária, 2026-09-02). A árvore tinha `app/core/schema_pj.py` declarando
tabelas das duas sessões, `app/models/__init__.py` **importando** os modelos das duas, e os
arquivos de modelo de ambas ainda **untracked**.

A sessão B arbitrou: *"A commita primeiro, porque `schema_pj.py` declararia a tabela dela sem o
modelo existir"*. **Errado, e no sentido oposto.** A sessão A mediu e mostrou: o `__init__.py` da
árvore já tinha `from app.models.<modelo_de_B> import ...`. Se A commitasse o `__init__.py` sem o
arquivo de B, o pacote importaria módulo inexistente — **ImportError na coleção**, `conftest`
fora, **zero testes rodando**.

**A regra:** `schema_pj.py` **declara**; `__init__.py` **importa de verdade**. Declaração órfã dá
**um teste vermelho**; import órfão **derruba a suíte inteira**. Quem tem o import pendurado
apontando para o seu arquivo commita **primeiro**.

**Como medir antes de arbitrar** (rode da RAIZ — o prefixo do caminho importa):

```bash
git cat-file -e "HEAD:caminho/do/modelo.py" && echo "NO HEAD" || echo "FALTA"
git show HEAD:caminho/__init__.py | rg "import"   # o que o HEAD importa
rg "import" caminho/__init__.py                    # o que a árvore importa
```

A diferença entre os dois `rg` é a resposta.

**O meta-ponto, que vale mais que a regra:** a sessão A não obedeceu à arbitragem errada — foi
medir e refutou. E o que lhe deu o que medir foi B ter escrito **o raciocínio junto da
conclusão**, não só a ordem. *Conclusão errada com raciocínio explícito é checável; conclusão
certa sem porquê não é.* É o melhor argumento para escrever o motivo mesmo quando a decisão
parece óbvia.

Ver também [[commit-com-pathspec-leva-o-disco-nao-o-staged]] — o pathspec vai no `commit`, não só
no `add`, e é o que permite commitar só o seu num índice compartilhado.
