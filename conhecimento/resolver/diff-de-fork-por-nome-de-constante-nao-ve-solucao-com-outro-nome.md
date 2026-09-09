## Diff de fork por NOME de constante acha o bug herdado e inventa um que não existe {#diff-de-fork-por-nome-de-constante-nao-ve-solucao-com-outro-nome}

`tags: fork, constantes de comportamento, TTL, comparacao por comportamento, ausencia de evidencia, grupo de estudos, Familia Milionaria, Empresa Milionaria`

**Sintoma:** um projeto nascido por fork continua com um valor que o projeto de origem **abandonou por
bug observado em uso real**, e nada quebra: a sessão expira, o usuário responde no vazio, vira "o bot não
entendeu". Medido em 2026-09-06: a Empresa Milionária tinha `SESSION_TTL_MINUTES = 30` e
`PENDING_TTL_MINUTES = 30`; a Família Milionária (origem) tinha esticado os dois para 24h em 25/08
depois de um teste ao vivo em que a sessão expirou entre o card e a resposta. O fork copiou o número no
dia D e a correção do dia D+n nunca voltou.

**Causa raiz:** fork copia código, não aprendizado. A constante viaja; o motivo dela, não. E o sintoma é
o pior possível: sem exceção, sem log de erro, sem teste vermelho.

**Solução que funcionou (barata, mecânica):** script que extrai as constantes de módulo de nível
superior com valor literal (`^[A-Z][A-Z0-9_]*\s*(:[^=]+)?=\s*<literal>`) dos dois repositórios e diffa
por `(arquivo, nome)`. Resultado: **26 constantes em comum, exatamente 2 divergentes**, e as duas eram
os TTLs que a origem mudou por bug. 🔑 **O contraste é o que vale, não a lista**: se metade divergisse
seria ruído de dois projetos evoluindo; divergir só nas duas que a origem mudou por incidente transforma a
comparação em sinal. Rode por trimestre em qualquer par origem/fork.

⚠️ **E o mesmo exercício produziu um falso positivo que quase entrou em dois documentos.** A varredura
achou `MSG_SESSAO_EXPIROU` só na origem e a conclusão escrita foi "o fork herdou o TTL curto E o silêncio
quando ele estoura". **Falso**: o fork tinha o aviso ("Sua sessão expirou...") como string inline mais um
guard de elegibilidade (`_wasExpired`) que impede o debounce de engolir a mensagem, e o fix era
**anterior** ao da origem. A busca por nome devolve vazio nos dois casos, em que a implementação existe com
outro nome e em que não existe: **ausência de evidência virou evidência de ausência** dentro de um método
que no resto funcionou muito bem.

**Regra prática:** use o diff por nome só para **encontrar candidatos**. A conclusão é por
**comportamento** (existe aviso ao usuário quando a sessão expira? o que acontece com a mensagem que
chega durante a expiração?), medida no fork com a pergunta específica, nunca inferida do grep.

Relacionado: [codigo-morto-plausivel-com-teste-verde-parece-vivo](codigo-morto-plausivel-com-teste-verde-parece-vivo.md)
(a mesma pergunta "isto está em uso?" que uma documentação em voz alta força e uma rotina de
desenvolvimento não faz).
