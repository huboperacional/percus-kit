## Guarda que proíbe LER um campo é cega para o serializer genérico — meça também o contrato publicado {#guarda-por-nome-e-cega-ao-serializer-generico}

`tags: guarda, teste estatico, AST, varredura de fonte, serializer, OpenAPI, contrato, fecho transitivo, campo dormente, vazamento, falso verde, R23`

**Contexto:** existe uma classe recorrente de requisito — *"este campo existe no cadastro e
NINGUÉM o lê fora daqui"*. Campo dormente à espera de uma versão futura, coluna que só a
migração pode tocar, dado sensível que só uma rota pode devolver. A guarda natural é uma
varredura de fonte: percorra `app/**/*.py` por AST e acuse quem citar o nome do campo fora
da lista fechada de arquivos autorizados. Ela funciona, e pega o caso comum:
`produto.estoqueMinimo` num relatório, `Produto.estoque_minimo` num `select`, o nome dentro
de SQL escrito à mão, o `getattr` com literal — e, se você fechar o contorno, o nome montado
por f-string ou concatenação.

**O buraco, e ele é estrutural:** a varredura procura o NOME. Um *serializer* genérico nunca
escreve o nome.

```python
def paraJson(linha):
    return {c.name: getattr(linha, c.name) for c in linha.__table__.columns}
```

Isso devolve o campo dormente para o mundo inteiro sem citá-lo uma única vez. A guarda
estática fica **verde**, e o requisito está quebrado exatamente do lado que o usuário vê. A
mesma cegueira vale para herança de schema: um relatório que responde
`list[ProdutoResposta]` publica todo campo que `ProdutoResposta` publica, sem uma linha de
código sobre o assunto.

**A segunda medição:** em vez de perguntar *"quem cita o campo?"*, pergunte **"em que rotas o
campo aparece no contrato que a aplicação publica?"**. Num projeto FastAPI isso é o
`app.openapi()` — e sai de graça, porque o contrato já é gerado.

1. Ache os schemas que declaram o campo entre as `properties` (os diretos).
2. **Feche transitivamente pelos `$ref`**: um schema que referencia um schema contaminado
   também publica o campo. Sem esse passo a guarda passa verde justamente no caso em que
   seria necessária — o relatório que embrulha o schema do cadastro.
3. Para cada `path`/método fora do recorte autorizado, colete os `$ref` da operação e cruze
   com o conjunto contaminado. Interseção não vazia é vazamento, com rota e schema nomeados.

**Caso medido (Empresa Milionária, 2026-08-30, FR-135):** quatro campos de estoque nasceram
no cadastro de produto para dormir até a versão do estoque ativo. A guarda estática por AST
foi provada dos dois lados (leitor plantado → vermelho; removido → verde) e estava correta.
A perna cross-claude do conselho apontou o serializer genérico como o caminho que ela não
podia ver de jeito nenhum. As duas camadas entraram no mesmo commit; a de contrato tem
prova sintética própria (um OpenAPI fabricado com `Relatorio → Linha → ProdutoResposta`,
provando que o fecho sobe a cadeia inteira).

**A regra prática:** guarda de "ninguém lê" precisa de **duas** medições, porque elas falham
por caminhos diferentes:
- a **estática** responde *"quem cita o campo no código?"* — pega o uso deliberado;
- a **de contrato** responde *"quem entrega o campo para fora?"* — pega o uso acidental, que
  é o mais provável dos dois.

**O que continua fora, e declare em voz alta em vez de fingir cobertura:** o nome montado a
partir de entrada externa em tempo de execução (`getattr(obj, request.query["campo"])`) não
está no fonte nem no contrato; e carregar a linha inteira num `select` não é "ler" no sentido
do requisito — o proibido é USAR ou PUBLICAR, e os dois exigem nomear ou expor. Guarda que
promete mais do que mede é pior que guarda estreita: alguém confia nela.

⚠️ **Anti-vácuo obrigatório na guarda de contrato:** asserte primeiro que o conjunto
contaminado NÃO é vazio. Se o cadastro parar de expor o campo (ou se o nome mudar), a guarda
não encontra nada, não acusa ninguém e fica verde para sempre descrevendo uma história falsa.

Relacionado: [[a-sabotagem-prova-o-que-voce-imaginou]],
[[guarda-com-parser-de-fonte-le-o-formato-nao-o-codigo]],
[[comentario-sobre-a-regra-desliga-a-regra]].
