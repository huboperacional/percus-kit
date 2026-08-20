## Grep com regex em CSS emitido devolve zero e parece prova {#grep-com-regex-em-css-emitido-mente}

`tags: tailwind, css, bundle, grep, escape, medição, falso-negativo, dead code, canon errado`

**Sintoma:** você suspeita que um utilitário CSS "não pinta", grepa o bundle (`dist/assets/*.css`)
procurando a classe, recebe **zero ocorrências**, e conclui que a regra não foi emitida. A conclusão
tem cara de prova — você mediu o artefato, não o fonte, que é justamente a disciplina certa.

**A armadilha:** no CSS emitido, o seletor vem **escapado** — `.bg-muted\/50`, `.hover\:bg-x\/90:hover`,
`.text-\[30px\]`, `.aria-\[invalid\=true\]\:border-danger`. Quase todo grep com regex erra alguma
camada de escape (a do shell, a do regex, a do CSS) e devolve zero **sem erro nenhum**. Zero por
escape errado é indistinguível de zero por regra ausente.

**O que fazer:** busca **literal**, nunca regex:

```bash
grep -o -F 'bg-muted\/50' dist/assets/*.css | wc -l      # -F = fixed string, sem regex
```

E confirme pelo **outro lado**, procurando a sintaxe do valor em vez do nome da classe:

```bash
grep -o "hsl(var(--[a-z-]*) */ *[0-9.]*)" dist/assets/*.css | sort | uniq -c
```

Se a regra existe, ela aparece nas duas medições. Se some nas duas, aí sim é ausência.

🪤 **O caso que gerou este verbete (Micro Investors, 2026-08-18 → 19):** uma sessão mediu "109 classes
de alpha mortas" no bundle e o número virou canon em um dia — entrou num plano como **duas tasks**
para "pagar a dívida", virou comentário de guard, virou memória de projeto e virou uma **decisão do
operador tomada sobre premissa falsa**. As classes nunca estiveram mortas. Executar as tasks teria
**removido transparência que pintava**.

O mecanismo real é mais fino do que "sem `<alpha-value>` não funciona":

| a var guarda | exemplo de config | `bg-x/50` |
|---|---|---|
| tripla HSL | `primary: 'hsl(var(--primary))'` | **PINTA** — o Tailwind reconhece a função e reescreve para `hsl(var(--primary) / .5)` |
| hex cru | `accent2: 'var(--accent2)'` | **descartada em build time** — `var()` não é função de cor, não há onde injetar o canal |

Ou seja: o achado original era verdadeiro para o caso que o disparou (hex) e foi **generalizado sem
testar a outra forma**.

**Regra de processo que fica:** medição que gera task precisa de **segunda via por caminho
independente** daquele que a descobriu. E quando for reverificar, desconfie de repetir o mesmo
instrumento — na reverificação deste caso o primeiro grep, com regex, **confirmou o erro**; só o
`-F` separou os dois mundos.
