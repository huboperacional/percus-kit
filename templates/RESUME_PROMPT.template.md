# Prompt de Retomada — {Nome do Projeto}

> Gerado pela skill `checkpoint` ao fim de um milestone (ou antes de `/clear`/`/compact`). Cole o **bloco
> abaixo** numa sessão nova para retomar sem perder contexto. Mantém só o essencial — o detalhe completo
> está no `HANDOFF.md` e `docs/PLANO.md`.

---

```
Retomando {Nome do Projeto} — {YYYY-MM-DD HH:MM}.

ESTADO: {1-2 frases do que está funcionando E2E + o que está pela metade}.

ÚLTIMO PASSO CONCLUÍDO: {descrição literal}.

PRÓXIMO PASSO IMEDIATO: {comando exato ou ação específica — sem ambiguidade}.

RELEIA PRIMEIRO (nesta ordem):
1. HANDOFF.md — estado completo e tabela de status
2. docs/PLANO.md — fonte da verdade do tracking [0]→[5-T]
3. {arquivo-chave do próximo passo, ex.: services/api/app/routers/x.py}

BLOQUEIOS / PRECISA DE MIM: {lista, ou "nenhum"}.

REGRAS ATIVAS: canon Percus v{X.Y.Z}; R11 (review antes de commit); gate [S] (spec+analyze antes de
feature não-trivial); R23 (consultar COMO_RESOLVER antes de debugar).
```

---

_Preenchimento: substitua cada `{...}` com o estado real. O "PRÓXIMO PASSO IMEDIATO" precisa ser
executável de cara — se tem "talvez/depende", não está pronto pra retomar (volte e detalhe)._
