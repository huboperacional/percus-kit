## `set -e` com `[ cond ] && VAR=1` aborta ou não conforme a POSIÇÃO da linha — e o conselho discorda sobre isso {#set-e-com-and-aborta-so-no-ultimo-comando-da-funcao}

`tags: bash, set -e, errexit, pipefail, curto-circuito, && , shell, review, conselho divergente, medir em vez de escolher, .sh`

**Sintoma:** um review aponta `[ "$x" = "y" ] && VAR=1` num script com `set -e` como risco de abortar
quando a condição é falsa. Outro revisor afirma o oposto, "confirmado por teste". Os dois soam
certos e você não sabe em qual acreditar.

**A medição (2026-09-12, bash do Git for Windows) resolve: depende de a linha ser ou não o ÚLTIMO
comando de uma função.**

```bash
set -e; [ 1 = 2 ] && X=1; echo depois        # -> imprime "depois"  (NAO aborta)
set -e; f() { [ 1 = 2 ] && X=1; }; f; echo x # -> ABORTA na chamada de f (exit 1)
```

**Por quê:** o POSIX isenta do `errexit` qualquer comando que seja parte de uma lista `&&`/`||`,
**exceto o último**. No corpo do script a linha é uma lista cujo resultado ninguém consome, e a
execução segue. Dentro de uma função, porém, o status da última linha **vira o status da função** —
e aí o `errexit` dispara na chamada, não na linha. O erro aparece longe de onde nasceu.

**Consequência prática:** a construção é segura *onde está* e passa a ser um bug quando alguém
**move a linha** para o fim de uma função, ou extrai o trecho para uma função (refactor comum). O
defeito nasce de uma mudança que parece inócua e que nenhum teste do trecho original cobre.

**O que fazer:** prefira `if [ cond ]; then VAR=1; fi`. É igualmente legível, tem o mesmo custo, e
**não depende da posição** — que é a propriedade que importa, já que a posição muda sem aviso. `|| true`
também resolve, mas mascara falhas reais do comando à esquerda quando ele não é um simples teste.

**O que este caso ensina além do bash:** duas pernas do conselho deram respostas opostas, ambas com
convicção, e **nenhuma das duas estava errada** — estavam respondendo perguntas diferentes sem
perceber. Divergência entre revisores não é sinal de que um deles é ruim; é sinal de que falta
**discriminante**. O caminho não é escolher a perna mais confiável: é gastar os trinta segundos que a
medição custa e registrar a condição que separa os dois casos.

**Ref:** `plugin/percus-review/scripts/council-orchestrator.sh` (v6.46.0) — duas linhas nesse formato
foram trocadas por `if/fi` mesmo estando em posição segura, porque a segurança não deveria depender
de a linha continuar onde está.
