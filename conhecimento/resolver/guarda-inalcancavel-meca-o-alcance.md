## Guarda nova pode ser INALCANÇÁVEL pela frase que reproduz o defeito — meça o ALCANCE, não o veredito {#guarda-inalcancavel-meca-o-alcance}

`tags: guarda, cadeia, defer, llm, smoke, medicao, alcance, falso-positivo, evidencia`

**Sintoma.** Você mede o defeito offline (reproduz 3/3), a sua função devolve o veredito certo,
você sobe pra produção e manda a frase. **O sistema responde CERTO.** Parece prova. Não é: a sua
guarda nunca rodou — um elo ANTERIOR da cadeia interceptou o turno e o desfecho correto veio do
caminho de fallback.

**Medido em 2026-08-12 (tiatendo, frente E1).** A guarda de variante subiu em produção. A frase
medida devolveu o total certo (R$ 125,00 em vez de R$ 175,00) e **zero eventos** no banco; o log
dizia `ask_variant → fluxo determinístico`. O extrator emitia `perguntar_tamanho` **junto** com as
linhas erradas, e o elo `ask_variant` retorna antes de qualquer guarda posterior. A medição offline
olhava só o campo que a minha função consome e **não olhava os campos que os elos anteriores
consomem** — media um caminho que a cadeia real não alcança.

**Why.** Numa cadeia de guardas com `return` antecipado, "o defeito reproduz" e "o defeito chega na
minha guarda" são perguntas DIFERENTES, e a segunda é a que importa. É a irmã de
[#gatilho-llm-envelhece-mecanismo-fica], e um degrau acima dele: lá o erro é confiar na FRASE; aqui
o gatilho está certo, a função está certa, e mesmo assim o turno desvia antes.

**How to apply.** Antes de gastar um teste caro (smoke real, bateria em produção), rode o produtor
N× e classifique cada saída por **onde o turno PARA na ordem real da cadeia** — não pelo veredito da
sua função:

```python
if saida.campoDoElo1:            onde = "elo 1 (retorna antes)"
elif saida.campoDoElo2:          onde = "elo 2 (retorna antes)"
elif vereditoDoElo3 == "falha":  onde = "elo 3"
elif meuVeredito == "dispara":   onde = "🎯 a MINHA guarda"
else:                            onde = "segue o caminho normal"
```

Frases equivalentes divergem muito: no caso medido, a variante com preço colado caía no elo
anterior 3/3 e a variante com verbo alcançava a guarda 3/3. **Escolha a frase do teste pelo ALCANCE
medido, não pelo defeito reproduzido.**

E o corolário para a evidência de "pronto": a prova tem que ser o **evento da sua guarda cruzado
com o log dela**. O resultado correto na resposta ao usuário não distingue "a minha guarda agiu" de
"outro elo desviou o turno".
