## Teste de gate passa VERDE com o bug presente porque a dependência morre antes de chegar no gate {#teste-verde-dependencia-morre-antes-do-gate}

tags: teste-decorativo, mutation-test, harness, gate-inalcancavel, fallback-mascara-teste,
api-key-ausente, engine-de-teste-diferente, best-effort-engole-erro, vacuous-pass

**Sintoma:** você escreve um teste (transcript, e2e, integração) para um bug recém-corrigido, ele
passa, e você marca a cobertura como feita. Ao mutation-testar — revertendo o fix — **ele continua
verde**.

**Causa raiz (duas variantes vistas no mesmo dia):**
1. **Dependência externa ausente muda a rota.** Sem `OPENAI_API_KEY`, o classificador levanta e o
   pipeline cai num fallback (`intencao=lancamento`). O gate sob teste só roda em `consulta`, então
   ele **nunca é alcançado** — nem com bug, nem sem. O teste não testa nada.
2. **Escrita best-effort aponta pra outro engine.** A função usa sessão própria
   (`AsyncSessionLocal`), que no ambiente de teste é um engine diferente do das fixtures. O insert
   falha sempre, o `except` engole, e a asserção posterior lê uma tabela que nunca recebeu nada.

**Solução:** (1) **mutation-test é obrigatório** em todo teste de guard — reverta o fix e confirme
o vermelho, senão você tem cobertura imaginária; (2) para o caso 1, dê ao harness um hook que fixe
a dependência (`meta.stub_intent` fixando a saída do classificador) — isso destrava a classe
inteira de cenários, não só o bug da vez; (3) para o caso 2, aponte a factory global pro engine de
teste via `monkeypatch`, e afirme que houve o que medir (`len(rows) == N`) antes de afirmar o
conteúdo.

**Regra geral:** teste que só afirma ausência (`assert x not in saida`, `assert segunda == []`)
passa por vazio. Sempre asserte também que a PRIMEIRA metade aconteceu.

**Ref:** Família Milionária, `c931f3f` e `042fb61` (2026-08-11). O transcript de Camada 1 passava
com o bug original de volta; o hook `stub_intent` foi o que o tornou efetivo. R23.
