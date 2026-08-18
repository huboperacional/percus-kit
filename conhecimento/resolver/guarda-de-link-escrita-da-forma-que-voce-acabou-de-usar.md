## Guarda escrita a partir da forma que VOCÊ acabou de usar nasce cega à forma majoritária {#guarda-de-link-escrita-da-forma-que-voce-acabou-de-usar}

`tags: guarda, gate, validacao de link, notacao, levantamento, cobertura parcial, falsa sensacao de cobertura, migracao, cross-ref, markdown, ancora, wiki link, review em rodadas`

**Sintoma:** você escreve uma guarda para uma classe de defeito ("link morto", "import proibido",
"segredo em claro"), ela passa em todos os testes que você escreveu, e mesmo assim a classe continua
passando em produção. Nas rodadas de review seguintes, a mesma guarda é acusada de novo — e a cada
vez por uma **forma diferente** do mesmo defeito.

**Causa raiz:** a guarda foi escrita a partir da notação que você tinha acabado de usar no código, e
não de um **levantamento das notações em uso na base**. Você valida o que estava na sua frente.

**O caso (percus-kit 6.38.0, 2026-08-18):** ao migrar a base de conhecimento de um monólito para
um-arquivo-por-verbete, entrou um bloco de gate para "link para verbete inexistente". Ele validava
`](arquivo.md)` — a forma que eu tinha acabado de escrever nos arquivos novos. Três rodadas de
review, três descobertas:

| Rodada | Forma que escapava | Impacto |
|---|---|---|
| 2 | `](#slug)` | **50 links mortos** — era a forma DOMINANTE |
| 3 | `[[slug]]` | 23 links mortos |
| 3 | `](arquivo.md#secao)` | passava calado |

🔑 **O dado que teria evitado tudo já estava medido, no meu próprio plano:** *"114 cross-refs em 4
notações: `](#slug)` 50 · `[[slug]]` 29 · `` `#slug` `` 32 · `#slug` solto 3"*. Eu medi as quatro
formas ao planejar e escrevi a guarda pensando em uma. **Medir e não usar a medição é pior que não
medir: dá a sensação de que a decisão foi informada.**

⚠️ **Por que isso é pior que não ter guarda nenhuma.** Sem guarda, todo mundo sabe que a classe não
é verificada. Com uma guarda que cobre a forma minoritária, o time lê "link morto é barrado no
commit" e para de conferir — e a forma majoritária passa a ter **menos** escrutínio do que tinha
antes. Cobertura parcial anunciada como cobertura é uma regressão de confiança.

**Solução:**
1. **Antes de escrever a guarda, levante as formas em uso** — um `grep -c` por notação candidata na
   base real, não na sua cabeça. O resultado costuma surpreender: aqui, a forma que eu ia validar
   era a **quarta** em volume.
2. **Escreva o teste positivo de cada forma**, uma por uma. Se você não consegue nomear as formas,
   ainda não pode escrever a guarda.
3. **Declare no código o conjunto coberto.** Um comentário listando "cobre A, B, C; NÃO cobre D"
   transforma o buraco em decisão registrada, e a próxima pessoa não precisa redescobrir por review.
4. **Ao migrar formato, a guarda tem de cobrir a notação ANTIGA também** — é justamente ela que
   acabou de virar link morto em massa.

**Regra que sai daqui, e generaliza para além de link:** *"valida X" só é verdade se a guarda
enumerar todas as sintaxes com que X é escrito na base.* Vale para segredo (`--token`, `TOKEN=`,
`Authorization:`), para import proibido (`import`, `require`, `from … import`), para mock
(`mock`, `fake`, `stub`, `TODO`). **A pergunta certa não é "minha regex casa o meu exemplo?", é
"quantas formas existem, e quantas eu cubro?"**

**Relacionado:** [regra-escrita-em-n-lugares-e-enforcada-em-nenhum](regra-escrita-em-n-lugares-e-enforcada-em-nenhum.md)
— lá a regra existia e nenhum gate a via; aqui o gate existe e vê só um pedaço.

**Ref:** percus-kit 6.38.0, 2026-08-18. Migração de `COMO_RESOLVER.md` (1040 KB, 398 verbetes) para
`conhecimento/resolver/<slug>.md`. As três rodadas estão no changelog da versão.
