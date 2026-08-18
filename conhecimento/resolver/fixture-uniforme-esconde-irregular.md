## Feature vira no-op DETERMINÍSTICO num caso comum e a suíte inteira fica verde {#fixture-uniforme-esconde-irregular}

tags: fixture uniforme, caso irregular, dia fechado, feriado, no-op semanal, cobertura falsa, business hours, lookback curto, folga semanal

**Sintoma:** feature nova, TDD com RED provado em cada teste, ~100 testes verdes incluindo banco real. Em produção ela simplesmente **não roda** — não com erro, sem rodar — num caso que é o MAIS COMUM do domínio. No caso medido: rotina diária que dependia de "achar o último fechamento olhando 1 dia pra trás". No tenant que **fecha na segunda** (o padrão de quase todo restaurante), a terça de manhã não achava fechamento nenhum, a função devolvia `None`, o caller abortava — e a rotina morria **toda semana**, em silêncio.

**Causa raiz:** **todo fixture tinha os 7 dias da semana preenchidos e iguais.** Um fixture uniforme não é "um caso de teste": é uma AFIRMAÇÃO de que a irregularidade do domínio não existe. Com dados regulares o teste prova só o caminho regular — e a sensação de cobertura (100 verdes) impede de procurar mais. Some-se um limiar de busca curto ("olho 1 dia pra trás") calibrado no caso regular, e o resultado é no-op onde ninguém olha.

**Solução:**
1. Antes de dar a feature por coberta, pergunte **"qual é a IRREGULARIDADE deste domínio?"** e escreva um fixture que a contenha: dia da semana vazio, data marcada como exceção/feriado, item sem o campo opcional, tenant sem a config, mês de 28 dias, turno partido.
2. Quando um helper varre "N períodos pra trás", **N tem que cobrir a maior lacuna plausível** (folga semanal + feriado emendado), e a varredura tem que **pular as exceções** (lista de datas fechadas), senão ela inventa um período que nunca existiu.
3. Se a função pode devolver "não achei", **logue WARNING nesse caminho** — um no-op mudo é indistinguível de "não havia nada a fazer".
4. Quem achou isto foi **review cross-provider reproduzindo por execução**, não lendo. Peça ao revisor pra TENTAR QUEBRAR com dados reais do domínio, não pra opinar sobre o código.

**Ref:** tiatendo `0.251.0` / Frente B reset noturno (2026-07-26); `execution/plugins/restaurant/nightlyReset.py::_lastEndedWindow`, `tests/test_nightlyResetWindows.py`. Parente de [#red-nunca-visto-embarca-fossil](red-nunca-visto-embarca-fossil.md) e [#verificar-runtime-nao-estrutura](verificar-runtime-nao-estrutura.md).

---
