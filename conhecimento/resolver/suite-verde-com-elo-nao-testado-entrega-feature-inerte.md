## Suíte verde com o elo não testado entrega feature inerte {#suite-verde-com-elo-nao-testado-entrega-feature-inerte}

`tags: teste de elo, funcao pura, feature inerte, suite verde, integracao, R11, code review, gate, TDD, unidade vs integracao, flag desligada, prop, wiring, dead code, falso verde`

**Contexto:** uma feature foi implementada de ponta a ponta — backend, camada de API, funções puras de
apoio — com **68 testes verdes** e `build` limpo. A tela continuava com a funcionalidade **desligada
por uma única prop** (`intervaloLivre={false}`), sobra da versão anterior em que ela era desabilitada
de propósito. Nada quebrou. O commit teria subido uma feature **inerte** com a suíte inteira verde e
o review de tipos passando.

**Causa raiz:** todos os testes cobriam **unidades puras** — resolução de janela, montagem de query
string, validação de entrada. Nenhum deles perguntava *"a tela liga o controle?"*. O elo entre a
lógica pronta e o consumidor dela era a única coisa não testada, e era exatamente onde estava o
defeito. Remover a mensagem de "recurso indisponível" deu a impressão de que o desligamento tinha
saído junto — mas motivo e flag eram **dois** pontos, e só um foi removido.

**Por que ninguém viu antes:** o sinal que normalmente denuncia isso — teste vermelho, erro de tipo,
build quebrado — **não existe neste caso**. Uma prop com valor válido é código correto; uma constante
que virou órfã é warning de lint, não erro. E a própria abundância de verde (68 testes) funciona como
anestésico: quanto mais completa a cobertura da unidade, mais convincente é a conclusão errada de que
a feature está pronta.

**Como resolver:** para toda feature cuja entrega depende de um **ponto de ligação** (prop, flag,
registro em rota, item de menu, chamada no agendador), escreva um teste que leia **o consumidor
real**, não a unidade. Quando o consumidor é um componente que não vale montar, ler o **fonte** dele
já basta e é barato:

```js
const fonte = await fs.readFile(new URL("../../page.tsx", import.meta.url), "utf-8");
expect(fonte).not.toMatch(/intervaloLivre=\{false\}/);   // não está desligado
expect(fonte).toContain("queryDaJanela(periodo)");        // usa a função nova
expect(fonte).not.toMatch(/\?days=\$\{/);                 // não monta a query à mão
```

Feio, e é o único gate que pega esta classe. **Veja-o reprovando** com o defeito reintroduzido antes
de confiar nele.

**Sinal de alerta:** você terminou uma feature, a suíte está verde, e **você não conseguiria apontar
qual teste falharia se a tela não usasse nada do que você escreveu**. Se a resposta é "nenhum", o elo
está descoberto.

**Generaliza para:** rota nova que não foi registrada no router · job novo que não entrou no
agendador · página que não entrou no menu (alcançável só por URL) · constante compartilhada que um
dos dois lados ainda não importa · feature-flag que ficou `false` no ambiente.

Parente de `mutacao-silenciosa-que-nao-casa-finge-o-gate` (o gate roda, não casa nada, e reporta
sucesso): nos dois casos **o verde vem de um caminho que não tocou o alvo**.
