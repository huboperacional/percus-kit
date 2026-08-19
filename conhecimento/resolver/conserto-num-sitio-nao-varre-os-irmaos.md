## Consertar a classe num sítio e não varrer os irmãos: o defeito reaparece no MESMO arquivo, horas depois {#conserto-num-sitio-nao-varre-os-irmaos}

`tags: review, R11, exit code, smoke, harness, sitio irmao, varredura, reincidencia, licao vira mecanismo, print nao e exit code, gate [5-T], falso verde, mesma sessao`

**Origem:** Família Milionária, 2026-08-19, num smoke `[5-T]` contra produção. Dois rounds de review R11 no mesmo arquivo, com ~1h de intervalo.

**O que aconteceu.** O round 1 achou que o `limparTudo()` do smoke era *best-effort* e o script saía **0** mesmo deixando dado em produção — "o `ATENCAO` é print, não exit code, e ninguém lê print de script que passou". Corrigi bem: nasceu `conferirLimpeza()` fail-closed sobre 9 tabelas, com `SystemExit(1)`, e "não conseguir conferir" passou a contar como resíduo. Escrevi a lição no docstring.

O round 2, no mesmo arquivo, achou **exatamente o mesmo defeito uma função acima**: o bloco do PLACAR imprimia `REPROVADO em [...]` e `INCONCLUSIVO em [...]` e **não setava exit code nenhum**. Embrulhado por qualquer runner, uma rodada reprovada sairia verde e o gate `[5-T]` abriria sem bloqueio.

**Causa raiz — e não é distração.** Eu tratei o achado como *bug daquele sítio*, não como *classe presente no arquivo*. A revisão me deu um caso; eu consertei o caso. O sítio irmão estava a ~30 linhas de distância, na mesma função `main()`, com a mesma forma (`print` de veredito negativo, sem `raise`), e eu **acabara de escrever no docstring do vizinho** por que isso é perigoso.

**Por que passa batido:**
- O sítio consertado fica *muito* bem documentado, o que dá sensação de fechamento.
- Veredito negativo é o caminho que **não** roda no dia bom: o smoke passou 4/4 nas três execuções, então nenhuma delas exercitou o ramo `FALHOU`. Código de veredito negativo é código morto até o dia em que importa.
- Diferente da reincidência clássica (dias/sessões depois, outro autor), aqui é **a mesma sessão, o mesmo arquivo, o mesmo autor, minutos depois** — a heurística de "isso eu já aprendi" mente justamente porque o aprendizado é recente demais.

**Regra:** quando um review devolve um finding, trate-o como **assinatura de classe**, não como coordenada. Antes de commitar, varra o arquivo (e os irmãos óbvios) pela FORMA do defeito — aqui, "veredito negativo que só imprime". Barato: um `grep` por `print(` perto de palavras de reprovação, ou por `return`/fim de função sem `raise`, resolve.

**Teste de fumaça da própria regra:** se o conserto que você acabou de fazer virou comentário explicando o perigo, pergunte de quem mais aquele comentário deveria estar falando.

**Como confirmar que o conserto agora é mecanismo, não lembrança:** o exit code precisa PROPAGAR. Confira que o `try` que envolve o veredito não tem `except` que engula — por AST, não por leitura:

```python
fn = next(n for n in ast.walk(ast.parse(src))
          if isinstance(n, ast.FunctionDef) and n.name == "main")
for tr in (n for n in ast.walk(fn) if isinstance(n, ast.Try)):
    assert not tr.handlers, "except engoliria o SystemExit"
```

(`SystemExit` herda de `BaseException`, então `except Exception` não o pega — mas `except:` pelado pega, e é o caso que a varredura precisa acusar.)

**Relacionado:** [[licao-em-prosa-reincide]] (o primo mais largo — lição em prosa não impede reincidência entre sessões; este aqui é o caso estreito de reincidência **dentro** da mesma edição), [[deploy-pipe-mascara-exit]] (outra forma de exit code mentiroso: o pipeline devolve o código do último comando), [[smoke-verde-pode-nao-ter-exercitado-a-guarda]] (o verde que não prova nada porque o caminho não foi alcançado).
