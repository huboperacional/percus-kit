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

🔑 **A MESMA doença tem uma segunda direção, e o remédio dela é outro (2026-09-05).** Acima, o
comentário faz a guarda **isentar** quem não devia. Na direção oposta ele faz a guarda **reprovar
quem está certo** — e essa é a que mata a guarda, porque um falso positivo é caro para quem tem
pressa e a saída fácil é desligar o teste.

Caso medido: uma guarda varria `app/` procurando quem importa a porta única de escrita
cross-empresa, para exigir declaração. Ela usava `"escrita_cross_empresa" in arquivo.read_text()`
e **reprovou dois arquivos que apenas CITAM a porta em comentário** — um deles explicando
justamente que a escrita passa por ela. Uma segunda guarda, procurando quem chama
`aplicarContextoDaEmpresa`, reprovou um arquivo cujo único uso do nome era uma menção em
comentário.

**O remédio aqui não é "excluir comentário do regex" — é parar de ler texto.** Em Python, `ast`
separa o que a linguagem entende do que é prosa:

```python
importa = any(
    (isinstance(no, ast.ImportFrom) and "escrita_cross_empresa" in (no.module or ""))
    or (isinstance(no, ast.Import) and any("escrita_cross_empresa" in a.name for a in no.names))
    for no in ast.walk(ast.parse(arquivo.read_text(encoding="utf-8"))))
```

O mesmo vale para chamada (`ast.Call` com `ast.Name`/`ast.Attribute`). **Regra prática: se a
guarda pergunta "este arquivo IMPORTA/CHAMA X?", a resposta está na árvore, não no texto.** Texto
serve quando a pergunta é mesmo sobre texto — copy de interface, marcador de isenção.

⚠️ E a sabotagem por `sed` precisa de **controle positivo próprio**: uma delas deixou o `)` de
fechamento dentro do comentário, o arquivo virou inválido, o pytest não coletou, e a linha do
relatório saiu **vazia** — que ao lado de outras com números se lê como "rodou e não falhou".
Rode `ast.parse` na mesma chamada da sabotagem.

Relacionado: [[a-sabotagem-prova-o-que-voce-imaginou]],
[[quem-restaura-o-estado-nao-pode-ser-o-teste]].
