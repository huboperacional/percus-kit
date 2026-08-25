## Detector AST que casa o identificador por TEXTO nasce com três buracos {#detector-que-casa-identificador-por-texto}

`tags: AST, trava mecanica, detector, falso negativo, falso positivo, alias de import, select sem colunas, isinstance, rglob, deteccao estatica, seguranca`

**Contexto:** trava mecânica que varre a AST e reprova qualquer função que consulte um modelo
(`Lancamento`, `User`, `Order`…) sem passar pelo contrato canônico. O detector procura o **nome** do
modelo nos nós da árvore.

**O erro:** procurar `Modelo.<attr>` (um `ast.Attribute` cujo `value` é `ast.Name`) e concluir que
isso é "estritamente mais abrangente" que procurar `select(Modelo)`. **Falso.** O R11 achou três
portas em três rodadas seguidas — uma por rodada:

1. **`select(Modelo)` sem colunas** — o caso **mais perigoso**, porque devolve a tabela inteira — não
   gera `Attribute` nenhum, só um `ast.Name`. A query que a trava existe para impedir passava batido.
2. **Alias de módulo:** `import app.models.pedido as mod` → `mod.Modelo.campo`. O `.value` é
   `Attribute`, não `Name`.
3. **Import renomeado:** `from ... import Modelo as M` → `select(M).where(M.campo == x)`. Gera só um
   `ast.alias`; **nenhum nó da função contém o texto do modelo**.

**A lição não é "tapar as três":** é que **casar por TEXTO do identificador é frágil por natureza**. O
conserto que fecha a classe inteira é **resolver o nome local a partir dos imports do arquivo**
(`ImportFrom` com `asname`) e comparar contra esse conjunto.

**O contrapeso importa tanto quanto.** Ao ampliar, o detector passou a acusar coisas que não
consultam nada — um formatador puro (`-> str`) entrou como falso positivo por causa de
`isinstance(x, Modelo)`. **Detector que acusa tudo é tão inútil quanto o que não acusa nada.** Excluir:

- subárvores de **anotação de tipo** (`arg.annotation`, `AnnAssign.annotation`, `FunctionDef.returns`);
- o **2º argumento de `isinstance`** — é teste de tipo, mesma natureza de anotação.

**Escolha declarada, e vale escrever no código:** ao decidir para que lado errar, **erre para o lado
que GRITA**. Falso positivo é build vermelho, alguém olha. Falso negativo numa trava de segurança é
silencioso — e silêncio é o modo de falha que a trava existia para impedir.

⚠️ **`glob("*.py")` cega a trava para subpacote futuro.** Use `rglob` e chaveie o inventário pelo
caminho relativo, senão uma pasta nova nasce fora da varredura sem ninguém notar.

⚠️ **O módulo que DEFINE a regra tem de ficar fora da varredura** — ele referencia o modelo por
construção e não pode declarar-se a si mesmo. Contrapartida real, que deve ficar escrita: query
escondida lá dentro não é vista. Mantenha-o pequeno o bastante para caber numa leitura.

**Como provar que o detector funciona:** dois testes por porta, sempre em par — um que ele **pega** a
forma ruim e um que ele **não acusa** a forma boa. Sem o par, o detector pode estar verde por
vacuidade (retornando `True` ou `False` para tudo).

Ver também: [trava de cobertura no fim confirma, no início revela](trava-de-cobertura-no-fim-confirma-no-inicio-revela.md).
