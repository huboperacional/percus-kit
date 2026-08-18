## Feature construída sobre módulo atrás de feature-flag OFF nasce MORTA e verde nos testes {#feature-sobre-flag-off-nasce-morta}

tags: `feature-flag`, `strangler-fig`, `kill-switch`, `teste-verde-feature-morta`, `dual-write`, `migracao-incremental`, `alcancavel-em-producao`

**Sintoma.** A feature nova passa em todos os testes e **nunca dispara para usuário real**. Ninguém percebe por semanas, porque não há erro — há silêncio.

**Causa raiz.** O módulo reusado é uma **migração incremental** (strangler-fig) protegida por flag: `FOO_ENABLED = False` por padrão, e a estrutura de dados que ele mantém (descritor, tabela espelho, índice novo) **só é escrita quando a flag está ligada**. Em produção a flag está OFF, então o `getX()` daquele módulo devolve sempre `None`. Os testes passam porque **eles mesmos semeiam** a estrutura à mão — o teste cria a precondição que produção nunca cria.

**Diagnóstico em 1 comando** (não confie no default do arquivo de config; confira o processo):

    docker exec <container> printenv FOO_ENABLED FOO_WHITELIST
    # vazio => usa o default do codigo. Leia o default: se for False, a estrutura nao existe la.

**Solução.** Antes de construir sobre uma abstração, pergunte **quem escreve o dado dela em produção, hoje**. Se a resposta for "um caminho atrás de flag", use a estrutura **legada** que está viva (frequentemente um dict cru no mesmo registro) e trate a migração como trabalho separado — ligar a flag é mudança de raio, com spec própria.

**Como detectar antes de doer:** no teste, semeie a precondição **pelo caminho de produção** (a função que o app chama), nunca pelo helper de baixo nível. Se produção não consegue criar aquele estado, o teste falha na hora de montar o cenário — que é o momento certo de descobrir.

**Ref:** Família Milionária, 2026-08-17. A reoferta de pendência ia nascer sobre `pending.py` (`__pending__` com `kind`/`payload`/`criadoEm` e registry), mas `PENDING_UNIFIED_ENABLED` é `False` no container: o descritor nunca é escrito em prod. Trocado pelo contexto legado `ctx["resultado"]`.
