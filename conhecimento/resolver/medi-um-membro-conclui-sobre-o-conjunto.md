## Medi UM membro e escrevi a conclusão sobre o CONJUNTO {#medi-um-membro-conclui-sobre-o-conjunto}

`tags: escopo da medicao, generalizacao, MEDIDO, docstring que mente, evidencia menor que a afirmacao, conserto no lugar errado, amostra, canon errado`

**Contexto:** você mede uma coisa de verdade, com instrumento certo, e o resultado é verdadeiro.
Aí escreve a conclusão com escopo maior do que a medição alcançou — *"é o **ÚNICO** dos sete"*,
*"**nenhum** módulo faz isso"*, *"**sempre** acontece quando..."* — e marca como **medido**, porque
uma medição de fato aconteceu.

**Por que é pior que afirmação não-medida:** tem evidência real atrás. Quem ler depois vai
confiar, e com razão: o rótulo "medido" é honesto sobre o método e mentiroso sobre o alcance.
Afirmação sem evidência levanta suspeita; esta não.

**O custo, medido (2026-09-04):** a docstring de `preparo_schema.remigrarSchema` dizia
*"Medido: `test_isolamento_fk_postgres.py` é o ÚNICO dos sete módulos `postgres` que zera o schema
no teardown"*. Eram **três** — os outros dois rodavam `downgrade(base)` como sonda e não
remontavam. A medição original tinha olhado **um** módulo. Consequência: o conserto foi aplicado ao
módulo que a frase citava (corretamente, para aquele módulo) e o defeito seguiu vivo nos outros
dois por dias, produzindo uma varredura vermelha que duas sessões diferentes trataram como
"conhecida" sem investigar.

### O teste que separa

Antes de escrever um quantificador (`único`, `todos`, `nenhum`, `sempre`), pergunte:
**quantos membros eu realmente medi?**

- Mediu 1 de 7 → a frase honesta é *"`X` faz isso"*, não *"só `X` faz isso"*.
- Quer mesmo o quantificador? Meça os 7. Se for caro, diga o que custa: *"medido em `X`; os outros
  seis não foram verificados"*. Essa frase é feia e salva meses.

**O caso feliz é barato.** Medir os sete módulos custou **um laço de shell e ~4 minutos** — migração
limpa antes de cada, contagem de tabelas depois. O que tornava caro era o túnel (~11 min por
módulo); de dentro da VPS o mesmo laço virou trivial. Muitas generalizações preguiçosas são, na
verdade, medições que pareciam caras num ambiente que mudou.

**Família:** "afirmar sem medir nada" é o vizinho óbvio; este é o vizinho traiçoeiro, porque passa
pelo ceticismo de quem lê. Ver também [[a-sabotagem-prova-o-que-voce-imaginou]] — mesma raiz, na
direção da cobertura: a sabotagem prova o caso que você lembrou de sabotar, não a classe inteira.
