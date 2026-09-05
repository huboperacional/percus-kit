## Zero só vale como prova depois que o probe acha o positivo num controle {#zero-so-vale-como-prova-com-controle-positivo}

tags: verificacao, prova, teste, e2e, browser, metodo

**Sintoma.** Você precisa provar uma **ausência** — "esta tela não tem drag",
"não vazou pra outro tenant", "não sobrou resíduo", "este código não chama mais a
API". Roda uma busca, dá zero, e registra como prova. O probe estava cego e o zero
não significava nada.

**Por que morde.** Verificação de ausência falha em silêncio e de forma
agradável: um instrumento errado sempre concorda com a sua hipótese. Não há
vermelho pra te avisar — a resposta "não achei nada" é indistinguível entre "não
existe" e "não sei procurar".

**Caso real** (Plexco Tasks, 2026-09-05). Precisava provar que a view da Frente
seguia somente-leitura. Rodei no browser:

```js
document.querySelectorAll('[draggable="true"], [data-dnd-draggable]').length
```

Deu **0**. Ia fechar como prova — mas rodei o MESMO probe na tela irmã, que é
comprovadamente arrastável, e deu **0 também**. O `dnd-kit` não usa o atributo
`draggable` do HTML5. O discriminador real é o que o `useSortable` põe no nó:

```
aria-roledescription="sortable"   role="button"   tabindex="0"   aria-disabled="false"
```

Com o probe certo: alvo **0 sortables**, controle **sortable presente**. Aí o zero
virou prova.

**Procedimento.**

1. Escolha o controle **antes** de medir — um lugar onde a coisa procurada
   comprovadamente EXISTE.
2. Rode o **mesmo** probe, sem alterações, no controle.
3. Controle negativo ⇒ **o probe está errado**, não o mundo. Conserte o probe.
4. Só então o zero no alvo conta como evidência.

**Corolário: coleção vazia não é controle.** Da mesma verificação: pra mostrar que
a tela B não tinha ganhado um recurso da tela A, não bastou abrir B vazia — foi
preciso **semear o mesmo dado nas duas** e comparar lado a lado. Duas telas vazias
"concordam" por motivos diferentes.

**Onde mais isso vale.** Query de auditoria que volta 0 linhas (a tabela existe? o
filtro está certo? há dado de qualquer tipo?); `grep` que não acha chamador (o nome
está certo? há chamada dinâmica?); teste que passa (ele fica vermelho sob mutação?).

Relacionado:
[debito-de-linter-medido-de-um-ponto-de-entrada-so-e-piso](debito-de-linter-medido-de-um-ponto-de-entrada-so-e-piso.md)
— mesma família, no domínio de ferramentas de análise estática.
