# Mock Audit — {Nome do Projeto}

_Atualizado em: {YYYY-MM-DD}_
_Atualizar a cada sessão que envolva frontend (R3 do `01_REGRAS_INEGOCIAVEIS.md`)._

---

## Legenda

| Status | Significado |
|---|---|
| ✅ real | Persiste no banco via endpoint real. Sem mock-data. |
| ⚠️ mock | Tem componente, mas usa dado local (Zustand/localStorage) — banner MODO DEMO obrigatório |
| ❌ só UI | Tem layout, mas zero estado/lógica — placeholder visual |

---

## Tabela de telas

| Tela / Feature | Status | O que falta para conectar ao backend | Esforço estimado |
|----------------|--------|---------------------------------------|------------------|
| {Tela A} | ✅ real | — | — |
| {Tela B} | ⚠️ mock | Endpoint POST + hook | 2h |
| {Tela C} | ❌ só UI | Schema + endpoint + hook + state mgmt | 1 dia |

---

## Toasts mentirosos detectados

> Anti-padrão R3: `toast.success("Salvo!")` quando o dado não foi ao servidor. Listar aqui qualquer ocorrência ainda não corrigida.

| Arquivo | Linha | Toast atual | Correção sugerida |
|---|---|---|---|
| {ex: `src/pages/produtos.tsx`} | {123} | `toast.success("Salvo!")` | `toast("Salvo localmente — backend não conectado", { icon: "⚠️" })` |

---

## Comandos para auditoria automática (rode antes de atualizar este arquivo)

```bash
# Encontrar uses de mock no frontend
grep -rln "mock-data\|mockData\|MOCK_\|fakeData" src --include="*.ts" --include="*.tsx" 2>/dev/null

# Encontrar toasts mentirosos
grep -rn "toast\.\(success\|info\)" src --include="*.ts" --include="*.tsx" 2>/dev/null \
  | grep -iE "salvo|saved|sucesso|criado|atualizado|deletado"

# Encontrar arrays hardcoded suspeitos (top 20)
grep -rn "const.*= \[" src --include="*.tsx" 2>/dev/null | head -20
```

---

## Histórico

- **{YYYY-MM-DD}** — Auditoria inicial: X telas reais, Y mocks, Z só-UI.
- **{YYYY-MM-DD}** — {Tela X} migrada de ⚠️ mock para ✅ real.
- **{YYYY-MM-DD}** — Adicionado banner MODO DEMO em {Tela Y}.
