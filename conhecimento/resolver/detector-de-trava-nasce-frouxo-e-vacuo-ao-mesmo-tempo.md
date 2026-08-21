## O detector de trava escrito no plano nasce FROUXO e VÁCUO ao mesmo tempo, e o inventário "fechado" pode estar pequeno demais {#detector-de-trava-nasce-frouxo-e-vacuo-ao-mesmo-tempo}

`tags: trava, guard, lint caseiro, varredura AST, inventario fechado, shrink-only, falso positivo, vacuo, premissa de plano, detector, ast.walk, f-string, closure, escopo`

**Sintoma:** você escreve no plano a varredura que vai virar trava de build, com o inventário dos
sítios legados listado por extenso. Ao rodar pela primeira vez, ela reprova — e a leitura ingênua
é "o código está sujo". Não está: **a trava erra nos dois sentidos ao mesmo tempo**.

**O caso (Família Milionária, 2026-08-20, Fase 3 Task 2):**

1. **Frouxa: 140 falsos positivos.** O detector reconstruía o texto da f-string embrulhando **todo**
   `ast.FormattedValue` em asteriscos (`f"*{{{p.value.id}}}*"`), então `f"R$ {valor}"` era lido
   como `R$ *{valor}*` e casava. Pior: o regex casava `*{nome}*`, que é **negrito do WhatsApp** —
   o idioma de toda a base de código.
2. **Vácuo: 3 sítios do inventário não eram achados.** Dois deles **não existiam**: eram nomes de
   função SUPOSTOS pelo autor do plano (`_menuDividas`, `_menuMetas`). O sítio real era outro, e
   o menu era *inline* dentro de uma função `async` que já tinha ido ao banco.
3. **O inventário estava pequeno demais:** o "inventário FECHADO dos 7" era, medido, **12** (+1 de
   formato diferente). Os 6 a mais foram abertos e lidos um a um — todos eram defeito da mesma
   classe que a trava existia pra pegar.

**Por que passa despercebido:** cada erro esconde o outro. A enxurrada de falsos positivos faz o
autor mexer no regex até o número cair, e "caiu" parece progresso — enquanto os fantasmas seguem
lá. E a regra defensiva usual, *"se o teste de realidade falhar, conserte o detector, nunca a
lista"*, **pressupõe que a lista foi medida**. Quando ela também é suposição, seguir a regra ao pé
da letra torce o detector até caber numa lista errada: a trava nasce **teatro**, verde e cega.
Ver também `premissa-de-plano-tambem-e-medicao` e `teste-de-contrato-pode-proteger-o-buraco`.

**Como resolver:**

- **Meça os DOIS lados antes de escrever o teste**, num script descartável, não no teste:
  `achados - lista` (falso positivo) e `lista - achados` (fantasma). Reportar só um dá falsa
  confiança.
- **Abra e leia cada "extra"** antes de rotulá-lo falso positivo. No caso acima, **6 dos 7** extras
  eram sítio real que o inventário havia perdido. O extra é a informação mais valiosa da medição.
- **Prefira assinatura ESTRUTURAL a texto reconstruído.** O que funcionou: exigir `*` colado nos
  **dois** lados do índice interpolado de um `enumerate()`, olhando os nós **vizinhos** do
  `ast.JoinedStr`. Resultado: 12 achados, **zero** falso positivo. Regex sobre texto remontado
  casa o idioma inteiro da base.
- **`ast.walk` desce em função aninhada.** Um `for pos, x in enumerate(...)` de uma closure
  registra `pos` como variável da função **externa**, e qualquer f-string de fora que mencione
  `pos` dispara a assinatura. Varra **escopo estrito** (pare em `FunctionDef`/`AsyncFunctionDef`/
  `Lambda`) quando a assinatura depender de nome de variável local.
- **Aceite expressão que MENCIONA o índice, não só o índice puro.** Exigir `ast.Name` deixa
  escapar `f"*{i+1}*"` (`ast.BinOp`), que é o idioma normal de quem usa `enumerate` sem `start=1`.
- **Corrigir um nome SUPOSTO para o nome real NÃO é encolher a trava** — o sítio é o mesmo, o
  rótulo é que estava errado. Isso é permitido. Apagar um sítio pra o teste ficar verde, não.
- **Declare a fronteira no arquivo, com o número.** Se uma família fica de fora (no caso: 28 menus
  de opção fixa, que não são selecionadores de candidato), escreva **quantos são e por quê**. Sem
  isso, o próximo leitor não distingue fronteira de esquecimento — e "amplia" a trava até ela virar
  ruído que alguém desliga.
- **Vácuo por infraestrutura também mata:** pasta que mudou de lugar faz `glob` devolver vazio e a
  trava passa verde sem olhar nada. `raise` nomeado se o diretório não existe, e se algum arquivo
  não parseia.
- **Prove que a trava MORDE por mutação**, e mire a mutação no formato **alternativo** (pontuação,
  nome de variável e construção diferentes dos sítios legados) — não no formato exato deles, senão
  a prova só confirma que ela reconhece o que já está lá. ⚠️ O `testes=` da mutação tem de apontar
  **um node-id**, nunca o arquivo: apontar o arquivo faz o subprocesso re-executar a própria
  mutação, em recursão infinita.
