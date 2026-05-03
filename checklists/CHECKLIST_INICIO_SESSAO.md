---
tipo: checklist-imperativo
quando-usar: SEMPRE ao abrir sessão em qualquer projeto Percus (existente ou novo)
leitura: 1 min
ultima-atualizacao: 2026-04-25
---

# CHECKLIST — Início de Sessão

> **Execute literalmente os 5 passos abaixo ANTES de qualquer outra ação.**
> Não é diretriz, é script. Se não conseguir executar um passo, **pare e informe o usuário**.

---

## Passo 1 — Ler `HANDOFF.md` do projeto

Se não existir: o projeto não foi iniciado pelo padrão Percus. Ofereça rodar `comandos/REORGANIZAR_PROJETO.md`.

Após ler, declare em voz alta ao usuário:
> "Li o HANDOFF. Última sessão terminou com: {resumo em 1 linha}. Próximo passo previsto: {citação literal do HANDOFF}."

## Passo 2 — Ler `docs/PLANO.md` do projeto

Se não existir: ofereça rodar `comandos/REORGANIZAR_PROJETO.md`.

Conte os status:
> "Plano tem X features em [5-T], Y em [4-C], Z em [2-E] ou abaixo, W em [0]."

## Passo 3 — Ler `docs/mock-audit.md` (se projeto tem frontend)

Se não existir e o projeto tem frontend: criar agora vazio com cabeçalho. Não pular.

Declare:
> "Mock audit lista: X telas reais, Y mocks, Z só-UI."

## Passo 4 — Verificar se HANDOFF e PLANO estão alinhados

Se divergem (ex: HANDOFF diz `[5-T]` e PLANO diz `[4-C]`), o **PLANO prevalece**. Atualize o HANDOFF antes de qualquer outra ação.

## Passo 5 — Propor próximo passo

Antes de fazer qualquer coisa nova, escreva ao usuário:
> "Pelo HANDOFF e PLANO, o próximo passo é {X}. Confirma que quero seguir por aí, ou tem algo diferente em mente?"

**Não comece a codar nem planejar antes da confirmação.**

---

## Pré-flight DeepSeek (opcional)

Se essa sessão pode envolver delegação de implementação mecânica ao DeepSeek (R13), faça essas 2 verificações **antes do Passo 5**:

1. **`DEEPSEEK_API_KEY` no `.env` do projeto?**
   ```
   Select-String -Path .env -Pattern '^DEEPSEEK_API_KEY=' -Quiet
   ```
   Se ausente, avise o usuário — sem a chave o wrapper não roda. Aponte pra `comandos/SETUP_DEEPSEEK.md` para configurar.

2. **`AGENTS.md` do projeto reflete R13?** (Codex precisa saber das regras de routing antes de revisar saída do DeepSeek)
   ```
   Select-String -Path AGENTS.md -Pattern 'R13|MODEL_ROUTING' -Quiet
   ```
   Se ausente, ofereça rodar `comandos/UPGRADE_PROJETO_FASE2.md`.

Para escopo e critérios de delegação, leitura sob demanda em `04_MODEL_ROUTING.md` (não obrigatório no início — só quando aparecer task elegível).

---

## Exceções permitidas

- Usuário fez pedido explícito que **substitui** o próximo passo do HANDOFF (ex: "esquece o que estava planejado, hoje eu quero X"). Nesse caso siga o pedido, mas **atualize HANDOFF.md no fim** refletindo a nova direção.
- Bug urgente reportado pelo usuário que precisa parar tudo. Tratar com `superpowers:systematic-debugging`.

---

## Anti-padrões

- ❌ "Já li tudo, vou direto pro código." — você não leu se não declarou em voz alta os resumos.
- ❌ "Vou começar pequeno e ver no que dá." — começar sem alinhamento gera retrabalho.
- ❌ Marcar passo como executado quando o arquivo nem existe — diga que não existe e ofereça criar.
