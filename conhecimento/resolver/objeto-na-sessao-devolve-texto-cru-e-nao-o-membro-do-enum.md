## Objeto que ainda está na sessão devolve o TEXTO cru, não o membro do enum — `.value` estoura só no teste, e a explicação "o hash é do nome" é falsa {#objeto-na-sessao-devolve-texto-cru-e-nao-o-membro-do-enum}

`tags: sqlalchemy, enum, native_enum, identity map, mapa de identidade, .value, AttributeError, fixture, teste, orm, justificativa inventada, R23`

**Sintoma:** um caso de uso lê `linha.situacao.value` de um objeto obtido por `select()` e estoura
`AttributeError: 'str' object has no attribute 'value'` — **só nos testes**. Em produção o mesmo caminho funciona,
porque lá a linha vem do banco.

**Causa raiz:** `Enum(..., native_enum=False)` converte para o membro **ao carregar do banco**. O objeto que a própria
sessão criou (a fixture que fez `Modelo(situacao="nenhuma")`) continua no **mapa de identidade**, e um `select()` na
mesma sessão devolve esse objeto, com o texto que você passou. Quem grava membro do enum na fixture nunca vê o defeito;
quem grava string, vê.

**Fix:** normalize pelo construtor do enum na entrada do caso de uso (`Situacao(valor) if valor is not None else None`)
— resolve os dois caminhos e não depende de como a fixture foi montada. Alternativas piores: `expire()`/`refresh()` no
teste (esconde o problema no código de produção) ou fixture obrigada a usar o membro (regra que ninguém lembra).

🔴 **A explicação que parece certa e é FALSA, medida em 15/09 (Python 3.12):** *"enum com mixin `str` não casa com o
texto porque o hash do membro é o do NOME"*. Falso: para `class S(str, Enum)`, `'nenhuma' in {S.NENHUMA}` é **True**,
`'nenhuma' == S.NENHUMA` é **True** e `hash('nenhuma') == hash(S.NENHUMA)`. A comparação por `in`/`==` **funciona**; o
que quebra é só o `.value`. A frase errada apareceu como justificativa num relato de subagente, ao lado do conserto
certo — e justificativa errada é pior que ausente, porque a próxima pessoa a usa para decidir onde mais normalizar.
**Meça a afirmação, não só o conserto:** um `python -c` de 10 segundos separa as duas, e a sabotagem (tirar o
construtor) mostra a mensagem real (`AttributeError`), não a inventada.

**Ref:** Empresa Milionária, `empresa-api/app/casos_uso/ler_boleto.py` (2026-09-15, Task 7 da leitura de boleto).
