## "Cinto de segurança" extra CORTA o caso legítimo — e alargá-lo vira guarda morta {#guarda-redundante-tesoura-ou-morta}

tags: guarda redundante, defensive programming, limiar, teto, janela temporal, codigo morto, falsa protecao, cap

**Sintoma:** você adiciona um limite defensivo "a mais" (teto de tempo, cap de tamanho, janela máxima) além da proteção que já existe. Ele passa a **descartar em silêncio** casos válidos. Ao perceber, o reflexo é alargar o limite — e aí ele nunca mais dispara, virando código que **lê como proteção e não protege nada**.

**Caso medido:** teto de 48h numa janela de "quem convidar de manhã". O tenant que fecha **dois dias seguidos** (dom+seg) reabre com o último fechamento 60h atrás → o teto empurrava o corte pra depois do evento, e aqueles clientes **nunca** eram convidados (o corte só anda pra frente). Alargar pra 8 dias consertou o corte e criou o problema oposto: a busca já era estruturalmente limitada a 8 dias, então o `max()` passou a nunca ativar.

**Causa raiz:** limiar defensivo só vale se você souber **qual é o maior caso legítimo em números**. Abaixo dele é tesoura; acima do limite estrutural que já existe, é decoração. E a falha da tesoura é **silenciosa** — não há erro, só ausência.

**Solução:**
1. Escreva em números o **maior caso legítimo** ("folga de 2 dias = 60h") e o **limite que o sistema já impõe**. Se a guarda nova não fica ESTRITAMENTE entre os dois, não escreva: ela é tesoura ou é morta.
2. Prefira proteção **exata** a proteção **temporal**: no caso medido, o que resolveu de verdade foi um **backfill na migration** carimbando todo o histórico como "já tratado" — sem raio pra errar. Coluna nova nasce `NULL`, e `NULL` costuma significar "elegível": carimbe o passado na própria migration.
3. **Toda guarda precisa de um teste que a veja DISPARAR.** Guarda que nenhum teste consegue ativar é código morto disfarçado — remova ou substitua.

**Ref:** tiatendo `0.251.0` (2026-07-26); `execution/core/backgroundRunner.py::_processTenantMorningQueue`, `execution/database/migrations/105_nightly_reset.sql`.

---
