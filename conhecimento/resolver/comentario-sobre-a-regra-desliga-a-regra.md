## O comentário que documenta a guarda pode desligar a guarda {#comentario-sobre-a-regra-desliga-a-regra}

`tags: guarda estatica, regex, comentario, isencao silenciosa, sabotagem, teste de teste, metaprogramacao textual, falso verde, vacuidade`

**Contexto:** guarda estática que varre arquivos procurando um padrão. Para decidir **quem está
isento**, ela procura no texto um marcador — por exemplo, "o arquivo que DEFINE a regra não é
julgado por ela". A detecção é um `re.search` sobre o arquivo inteiro.

**O que acontece:** o comentário que **explica** a regra contém o marcador. A guarda lê o
comentário, conclui que aquele arquivo é o definidor, e **isenta o arquivo inteiro**.

**Caso medido (2026-08-24):** uma guarda impedia que páginas repetissem o sufixo de marca que o
layout raiz já acrescenta via `title.template`. Ela reconhecia o layout raiz assim:

```python
def _define_o_template(fonte: str) -> bool:
    return re.search(r"template:\s*['\"]%s", fonte) is not None
```

Ao corrigir uma página, escrevi em comentário: *"o layout raiz aplica `template: '%s | Marca'`"* —
para explicar por que o sufixo saía dali. O padrão casou **no comentário**, e a guarda passou a
tratar aquela página como definidora do template, isentando-a. **A documentação da correção
desligou a verificação sobre a página corrigida.**

**Por que é insidioso:** o arquivo fica verde, o comentário parece cuidado extra, e a isenção não
aparece em lugar nenhum — não há warning, não há contagem de arquivos varridos. O sintoma só
aparece quando alguém reintroduz o defeito **naquele arquivo** e ninguém reclama.

**Diagnóstico:** se uma guarda estática fica verde onde você esperava vermelho, teste a **função de
isenção** isoladamente, não a asserção:

```python
print("define o template?", g._define_o_template(fonte_sabotada))   # True == isento
```

Foi o que revelou. A asserção estava correta; quem mentia era o filtro antes dela.

**Fix:** a detecção precisa distinguir **código de prosa**. Ignore linha de comentário:

```python
_COMENTARIO = re.compile(r"^\s*(//|/\*|\*|#)")

def _define_o_template(fonte: str) -> bool:
    return any(
        re.search(PADRAO, linha) and not _COMENTARIO.match(linha)
        for linha in fonte.splitlines()
    )
```

**Sabotagem que prova o fix** — e são duas, não uma:
1. um comentário citando o marcador **não pode** isentar o arquivo;
2. o arquivo que tem esse comentário **ainda fica vermelho** se receber o defeito real.

Sem a segunda, você prova que não quebrou, não que consertou.

⚠️ **A classe é maior que o caso.** Guarda estática lê TEXTO, e texto *sobre* a regra é
indistinguível da regra. Vale para qualquer isenção por marcador — `# noqa` citado em comentário,
`eslint-disable` dentro de string de exemplo, nome de flag numa docstring. **Sempre que a isenção
for textual, exclua comentário e string de exemplo.**

⚠️ **Relacionado, e vale junto:** o guard que lê a linha de comando tem a mesma doença ao contrário
— procurar ou editar o padrão que ele bloqueia dispara o próprio guard. Ali a saída é o inverso:
mover o texto para um arquivo em vez da linha de comando.

Relacionado: [[a-sabotagem-prova-o-que-voce-imaginou]].
