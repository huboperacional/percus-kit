---
tipo: contract registry (versionado)
audiência: backend auth-service + frontend consumers + libs `percus-auth`
versão: V1 (2026-05-15)
status: vigente
política-de-evolução: enum open/extensible — reason desconhecido = log warning + `reason=unknown` (nunca 500)
referência: PADRAO_AUTH_SERVICE_INTEGRATION_V2 Seção H
---

# Registry de `?reason=` — redirects pra login page

## Contrato

Quando o user é redirecionado pra página de login, o auth-service (ou o consumer) inclui `?reason=<canonical>` na URL. Frontend renderiza banner contextual a partir do mapa de reasons.

**Validação:** endpoints que constroem redirect com `reason` validam server-side contra o registry abaixo. Reason desconhecido = log warning estruturado + `reason=unknown` (nunca 500 ou 422 — anti-enumeration).

---

## V1 — Lista canônica

| `reason` | Quando dispara | Quem dispara | Mensagem sugerida pt-BR |
|---|---|---|---|
| `session_invalid` | Sessão expirou/invalidada server-side (refresh family rotacionada por theft detection) | auth-service (refresh endpoint) ou consumer (middleware) | "Sua sessão expirou. Entre de novo." |
| `token_expired` | Access token JWT expirou e refresh também falhou (TTL absoluto estourou) | consumer (middleware de validação) | "Sua sessão expirou. Entre de novo." |
| `refresh_failed` | Refresh token rotation falhou — família invalidada por reuse detection (RFC 6749 §10.4) | auth-service | "Sua sessão foi encerrada por segurança. Entre de novo." |
| `audience_not_allowed` | JWT válido mas audience claim não tem permissão pro produto chamado | consumer | "Você não tem acesso a este produto." |
| `logout` | User clicou logout — explicit sign-out | consumer ou auth-service `/auth/logout` | "Você saiu da conta." |
| `magic_consumed` | Magic-link já foi usado (single-use) | auth-service `/w/{code}` | "Este link já foi usado. Peça um novo." |
| `magic_expired` | Magic-link estourou TTL (default 24h email / 10min whatsapp) | auth-service `/w/{code}` | "Este link expirou. Peça um novo." |
| `magic_context_mismatch` | Device fingerprint divergente (IP/16 ou UA hash mudou entre emit e consume) | auth-service `/w/{code}` | "Por segurança, abra o link no mesmo dispositivo onde solicitou." |
| `magic_invalidated` | Magic-link foi invalidado server-side (user fez logout antes de clicar) | auth-service `/w/{code}` | "Este link foi cancelado. Peça um novo." |
| `unknown` | Fallback obrigatório que clientes DEVEM tratar pra resilience | qualquer | "Você foi desconectado. Entre de novo." |

---

## Política de evolução

| Mudança | Procedimento |
|---|---|
| Adicionar `reason` novo | PR no `huboperacional/percus-kit` neste arquivo + PR no auth-service repo se houver dispatcher. Aprovação: 1 owner percus-kit + 1 auth-service team. |
| Renomear | 60d window + manter alias antigo nesse período + announcement Slack/email |
| Remover | 60d window + `Deprecation` header no redirect |

---

## Frontend pattern (Next.js / React)

```tsx
// app/login/page.tsx (Plexco Tasks como referência)
const REASON_MESSAGES: Record<string, { type: 'info'|'warning'|'error', text: string }> = {
  session_invalid: { type: 'warning', text: 'Sua sessão expirou. Entre de novo.' },
  token_expired: { type: 'warning', text: 'Sua sessão expirou. Entre de novo.' },
  refresh_failed: { type: 'error', text: 'Sua sessão foi encerrada por segurança. Entre de novo.' },
  audience_not_allowed: { type: 'error', text: 'Você não tem acesso a este produto.' },
  logout: { type: 'info', text: 'Você saiu da conta.' },
  magic_consumed: { type: 'warning', text: 'Este link já foi usado. Peça um novo.' },
  magic_expired: { type: 'warning', text: 'Este link expirou. Peça um novo.' },
  magic_context_mismatch: { type: 'error', text: 'Por segurança, abra o link no mesmo dispositivo onde solicitou.' },
  magic_invalidated: { type: 'warning', text: 'Este link foi cancelado. Peça um novo.' },
  unknown: { type: 'info', text: 'Você foi desconectado. Entre de novo.' },
}

const reason = searchParams.get('reason') ?? ''
const banner = REASON_MESSAGES[reason] ?? REASON_MESSAGES.unknown
```

---

**Mantenedor:** auth-service team.
**Última atualização:** 2026-05-15 (V1 cravado).
