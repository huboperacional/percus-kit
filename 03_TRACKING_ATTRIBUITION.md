---
tipo: spec-tecnica
prevalece-sobre: []
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, CLAUDE.md do projeto]
quando-usar: ao adicionar formulário de signup/lead/checkout em qualquer projeto
leitura: 8 min
ultima-atualizacao: 2026-04-25
---

# 03 — Tracking & Atribuição de Paid Media

> **Source of truth técnico:** projeto `D:\Claud Automations\Paid Midia Tracking\` (PMT).
> Este documento é a spec prática pra **outros projetos** capturarem atribuição corretamente
> e (opcionalmente) enviarem ao PMT pra fan-out CAPI/MP.

---

## 1. Por que isto importa

Marketing paga por clique nas plataformas (Meta, Google, TikTok, Microsoft). Pra atribuir conversão de volta ao anúncio, precisamos preservar **identificadores de clique** + **UTMs** desde o landing até o evento de conversão (signup, compra, lead).

**Regra zero:** se um formulário do nosso ecossistema **não** capturar estes campos, a conversão **será atribuída como organic** mesmo tendo vindo de Meta/Google. Reporting fica errado, otimização do leilão sofre.

**Gate de verificação:** rode o script da Seção 9 ao final da implementação. Sem rodar, a feature não está em `[5-T]`.

---

## 2. Os 15 campos canônicos

Use **exatamente** estes nomes (snake_case). Mesma convenção do PMT.

### 2.1. Click IDs (6 campos)

| Campo | Origem | Quando aparece |
|---|---|---|
| `fbclid` | Meta Ads | Sempre que click vem de fb/ig com Pixel/CAPI |
| `gclid` | Google Ads | Click padrão Google Ads (web/desktop, Android) |
| `gbraid` | Google Ads | iOS app campaigns post-ATT (substitui `gclid`) |
| `wbraid` | Google Ads | iOS web campaigns post-ATT |
| `msclkid` | Microsoft / Bing Ads | Click Bing Ads |
| `ttclid` | TikTok Ads | Click TikTok (com Pixel/CAPI ativo) |

### 2.2. Meta Pixel cookies (2 campos)

Set pelo Meta Pixel browser-side. Propagados pra CAPI server-side.

| Campo | Notas |
|---|---|
| `fbp` | Browser ID do Meta Pixel (cookie `_fbp`) |
| `fbc` | Click cookie do Meta (cookie `_fbc`, derivado do `fbclid`) |

### 2.3. UTMs padrão (5 campos)

| Campo | Exemplo |
|---|---|
| `utm_source` | `facebook`, `google`, `tiktok`, `newsletter` |
| `utm_medium` | `cpc`, `cpm`, `email`, `organic` |
| `utm_campaign` | `trial14_dec2026`, `blackfriday_v2` |
| `utm_content` | `creative_a_video`, `headline_2` |
| `utm_term` | palavra-chave ou audiência |

### 2.4. Page context (2 campos)

| Campo | Como capturar |
|---|---|
| `referrer` | `document.referrer` no momento do load |
| `landing_url` | `window.location.href` no primeiro page-view do funil |

---

## 3. Captura no frontend

### 3.1. Helper canônico (TS/JS)

Salvar em `lib/tracking-attribution.ts`:

```ts
export type Attribution = {
  fbclid?: string; gclid?: string; gbraid?: string; wbraid?: string;
  msclkid?: string; ttclid?: string;
  fbp?: string; fbc?: string;
  utm_source?: string; utm_medium?: string; utm_campaign?: string;
  utm_content?: string; utm_term?: string;
  referrer?: string; landing_url?: string;
};

const STORAGE_KEY = "attr_v1";
const TTL_DAYS = 90;

function getCookie(name: string): string | undefined {
  const m = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
  return m ? decodeURIComponent(m[1]) : undefined;
}

/** Captura no PRIMEIRO landing. Persiste em localStorage com TTL.
 *  Chame em layout.tsx / _app.tsx no client side. */
export function captureAttribution(): Attribution {
  if (typeof window === "undefined") return {};
  const url = new URL(window.location.href);
  const q = url.searchParams;

  const fresh: Attribution = {
    fbclid: q.get("fbclid") || undefined,
    gclid: q.get("gclid") || undefined,
    gbraid: q.get("gbraid") || undefined,
    wbraid: q.get("wbraid") || undefined,
    msclkid: q.get("msclkid") || undefined,
    ttclid: q.get("ttclid") || undefined,
    fbp: getCookie("_fbp"),
    fbc: getCookie("_fbc"),
    utm_source: q.get("utm_source") || undefined,
    utm_medium: q.get("utm_medium") || undefined,
    utm_campaign: q.get("utm_campaign") || undefined,
    utm_content: q.get("utm_content") || undefined,
    utm_term: q.get("utm_term") || undefined,
    referrer: document.referrer || undefined,
    landing_url: window.location.href,
  };

  // Merge com o que já temos: novos valores ganham, mas não apaga campos
  // que vieram numa visita anterior.
  const stored = loadAttribution();
  const merged: Attribution = { ...stored, ...stripUndefined(fresh) };

  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({ at: Date.now(), data: merged }),
  );
  return merged;
}

export function loadAttribution(): Attribution {
  if (typeof window === "undefined") return {};
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const { at, data } = JSON.parse(raw);
    if (Date.now() - at > TTL_DAYS * 24 * 60 * 60 * 1000) {
      localStorage.removeItem(STORAGE_KEY);
      return {};
    }
    return data || {};
  } catch {
    return {};
  }
}

function stripUndefined<T extends object>(obj: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(obj).filter(([, v]) => v !== undefined),
  ) as Partial<T>;
}
```

### 3.2. Casos comuns de uso

#### A) Signup simples (1 form, 1 página)

```tsx
"use client";
import { useEffect } from "react";
import { captureAttribution, loadAttribution } from "@/lib/tracking-attribution";

export default function SignupPage() {
  useEffect(() => { captureAttribution(); }, []); // grava no primeiro load

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    await fetch("/api/signup", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: fd.get("email"),
        full_name: fd.get("full_name"),
        attribution: loadAttribution(),
      }),
    });
  }

  return (
    <form onSubmit={onSubmit}>
      <input name="email" type="email" required />
      <input name="full_name" required />
      <button>Criar conta</button>
    </form>
  );
}
```

#### B) Form de lead (newsletter, opt-in)

Idêntico ao signup, mas endpoint `/api/leads`. **Sempre incluir `attribution: loadAttribution()`** mesmo se o form tem só email.

#### C) Checkout (compra)

```tsx
async function handleCheckout(items: CartItem[]) {
  await fetch("/api/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      items,
      total_cents: total,
      attribution: loadAttribution(), // <-- crítico para CAPI Purchase event
    }),
  });
}
```

#### D) Form multi-step (wizard)

Capturar **uma vez** no início do wizard, anexar no submit final:

```tsx
"use client";
import { useEffect, useState } from "react";
import { captureAttribution, loadAttribution } from "@/lib/tracking-attribution";

export default function WizardPage() {
  useEffect(() => { captureAttribution(); }, []);
  const [step, setStep] = useState(1);
  const [data, setData] = useState({});

  async function onFinalSubmit() {
    await fetch("/api/wizard-submit", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        ...data,
        attribution: loadAttribution(), // recupera o que foi capturado lá no step 1
      }),
    });
  }
  // ... renderiza etapa atual ...
}
```

### 3.3. Anti-padrão proibido

**NÃO use `<input type="hidden">` por campo.** São 15 campos — sujaria o DOM. Backend recebe o objeto inteiro num campo `attribution` na body do JSON.

---

## 4. Schema backend (Pydantic / FastAPI)

```python
from pydantic import BaseModel, EmailStr

class SignupAttribution(BaseModel):
    # Click IDs
    fbclid: str | None = None
    gclid: str | None = None
    gbraid: str | None = None
    wbraid: str | None = None
    msclkid: str | None = None
    ttclid: str | None = None
    # Meta cookies
    fbp: str | None = None
    fbc: str | None = None
    # UTMs
    utm_source: str | None = None
    utm_medium: str | None = None
    utm_campaign: str | None = None
    utm_content: str | None = None
    utm_term: str | None = None
    # Context
    referrer: str | None = None
    landing_url: str | None = None


class SignupRequest(BaseModel):
    email: EmailStr
    full_name: str
    # ... outros campos ...
    attribution: SignupAttribution | None = None
```

### 4.1. Captura server-side (não confiar no client pra IP/UA)

```python
async def signup(body: SignupRequest, request: Request, db: DbSession):
    # Reverse-proxy aware (Traefik, nginx, Cloudflare)
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        client_ip = fwd.split(",")[0].strip()
    else:
        client_ip = request.headers.get("x-real-ip") or (
            request.client.host if request.client else None
        )
    user_agent = request.headers.get("user-agent")

    # Persiste tudo
    metadata = {}
    if body.attribution:
        metadata["attribution"] = body.attribution.model_dump(exclude_none=True)
    if client_ip or user_agent:
        metadata["request"] = {
            k: v for k, v in
            {"ip": client_ip, "user_agent": user_agent}.items() if v
        }
    # ... persiste em JSONB no DB ...
```

### 4.2. Onde persistir

**Default:** coluna `metadata JSONB` na tabela do recurso criado (subscription, lead, order):

```json
{
  "source": "coach_landing_v1",
  "attribution": { "utm_source": "facebook", "fbclid": "...", "..." : "..." },
  "request": { "ip": "189.45.x.x", "user_agent": "Mozilla/5.0 ..." }
}
```

**Quando virar tabela própria:** se precisar dashboards de marketing com `GROUP BY utm_source ORDER BY conversions DESC`, materializar via view ou migrar pra tabela `tracking_attribution` com colunas dedicadas. **Não faça isso preventivamente** — JSONB resolve até ~100k rows com índice GIN se precisar.

---

## 5. Forwarder pro PMT (opcional)

Após persistir local, dispare evento ao PMT pra ele fazer fan-out pra Meta CAPI / GA4 MP / Google Ads / TikTok:

```python
import httpx, uuid
async def forward_to_pmt(event_name: str, attr: dict, user_email: str):
    if not settings.PMT_TENANT_SLUG:
        return  # pulado em dev
    async with httpx.AsyncClient(timeout=5.0) as c:
        await c.post(
            f"{settings.PMT_BASE_URL}/tracker?t={settings.PMT_TENANT_SLUG}",
            json={
                "event_name": event_name,        # "Lead", "Purchase", etc
                "event_id": str(uuid.uuid4()),
                "user_data": {"email": user_email},
                **attr,
            },
        )
```

Coordene com o operador do PMT pra cadastrar o tenant + slugs de webhook. Documentação interna do PMT vive em `D:\Claud Automations\Paid Midia Tracking\INTEGRATION_BRIEF.md`.

---

## 6. Pegadinhas conhecidas

### 6.1. IP atrás de reverse proxy
`request.client.host` retorna o IP do **proxy** (Traefik, nginx, Cloudflare), não do client real. Sempre prefira `X-Forwarded-For[0]` com fallback `X-Real-IP`. Cloudflare também envia `CF-Connecting-IP`.

### 6.2. Cookies first-party em domínios separados
`_fbp` e `_fbc` são por domínio. Se landing em `landing.exemplo.com` e signup em `app.exemplo.com`, cookies **não** vazam — use `Domain=.exemplo.com` ao setar manualmente, ou capture no landing e propague via `localStorage` (que funciona por subdomínio só com Service Worker; default é por subdomínio).

**Mais simples:** capture todos os params + cookies no **landing** e propague até o signup via querystring (`?attr=base64(...)`) ou backend session.

### 6.3. ITP / Adblock
Safari ITP limita cookies first-party JS-set a 7 dias. Adblockers removem `_fbp/_fbc`. Server-side dispatch (PMT) compensa parcialmente porque envia `client_ip_address` + `client_user_agent` pro Meta fazer fingerprint match. **Sempre capture server-side** o IP/UA.

### 6.4. `gbraid` / `wbraid` substituem `gclid` no iOS
A partir do iOS 14.5 (ATT), Google passou a mandar `gbraid` (apps) e `wbraid` (web) no lugar do `gclid`. **Não esqueça os dois** — esquecer = atribuição zerada do tráfego iOS-pago.

### 6.5. TikTok requer Events API v1.3
`ttclid` só é útil se você tem TikTok Pixel + Events API configurados. PMT já suporta v1.3.

### 6.6. Não validar/normalizar
Salve **literal** o que veio. UTM `Facebook` ≠ `facebook` ≠ `FB` — problema do dashboard, não do coletor. Forçar lowercase no coletor quebra atribuição quando alguma campanha usa case-sensitive matching no Meta.

---

## 7. Checklist pra adaptar projeto novo

- [ ] Criar `lib/tracking-attribution.ts` com helpers (§3.1)
- [ ] Chamar `captureAttribution()` no layout/_app client-side
- [ ] Adicionar `attribution: loadAttribution()` em todo POST de form (signup, lead, contato, checkout)
- [ ] Adicionar `SignupAttribution` Pydantic model no backend (§4)
- [ ] Capturar `ip_address` via `X-Forwarded-For` (§4.1)
- [ ] Persistir em `metadata JSONB` da tabela do recurso
- [ ] **Rodar script de verificação (Seção 9)** — sem isso a feature não está em `[5-T]`
- [ ] (Opcional) Forward pro PMT pra dispatch CAPI/MP

---

## 8. Casos especiais

### 8.1. Form sem JavaScript (server-rendered puro)
Capture os UTMs no servidor lendo a query string da request HTTP. `_fbp` e `_fbc` ficam só com Pixel JS — perde-se nesse cenário.

### 8.2. Form em iframe (third-party)
Iframe não enxerga query string da página pai — precisa o pai injetar via `postMessage` ou querystring no `src` do iframe.

### 8.3. Mobile app (sem browser)
Click IDs vêm via deep link / install referrer (Android) ou ASA / SKAdNetwork (iOS). PMT não cobre esse caso hoje — precisa SDK específico (Adjust, AppsFlyer, ou implementação manual).

---

## 9. Script de verificação (rode antes de marcar [5-T])

Salvar em `scripts/verify-attribution.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "▶ Verificando captura de atribuição..."

# 1. Helper existe
if [[ ! -f "lib/tracking-attribution.ts" && ! -f "src/lib/tracking-attribution.ts" ]]; then
  echo "❌ FALHOU: lib/tracking-attribution.ts (ou src/lib/) não existe"
  exit 1
fi
echo "✅ Helper existe"

# 2. Forms enviam attribution
form_files=$(grep -rl "fetch.*method.*POST" --include="*.tsx" --include="*.ts" src 2>/dev/null || true)
if [[ -z "$form_files" ]]; then
  echo "⚠️  Nenhum form POST encontrado em src/ (talvez OK se backend-only)"
else
  missing=()
  for f in $form_files; do
    if ! grep -q "loadAttribution\|captureAttribution" "$f"; then
      missing+=("$f")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ FALHOU: forms sem attribution:"
    printf '   - %s\n' "${missing[@]}"
    exit 1
  fi
  echo "✅ Todos os forms POST chamam loadAttribution()"
fi

# 3. Backend tem schema
if ! grep -rq "SignupAttribution\|class.*Attribution.*BaseModel" backend services 2>/dev/null; then
  echo "❌ FALHOU: schema Pydantic Attribution não encontrado no backend"
  exit 1
fi
echo "✅ Schema backend presente"

# 4. Endpoint persiste em metadata JSONB
if ! grep -rq "metadata.*attribution\|attribution.*model_dump" backend services 2>/dev/null; then
  echo "⚠️  Não confirmei persistência em metadata JSONB — verifique manualmente"
fi

echo ""
echo "▶ Teste manual obrigatório:"
echo "   1. Acesse /signup?utm_source=test&fbclid=abc123"
echo "   2. Submeta o form"
echo "   3. SELECT metadata FROM <tabela> ORDER BY id DESC LIMIT 1;"
echo "   4. Confirme que utm_source e fbclid aparecem"
echo ""
echo "✅ Verificação automática OK. Faça o teste manual antes de marcar [5-T]."
```

Tornar executável: `chmod +x scripts/verify-attribution.sh`.

---

## 10. Referências

- **PMT canônico:** `D:\Claud Automations\Paid Midia Tracking\` — começar pelo `INTEGRATION_BRIEF.md` se for integrar diretamente.
- **Plexco V2** (referência de implementação):
  - `backend/app/api/v1/internal.py` — `SignupAttribution` model
  - `backend/tests/test_internal_attribution.py` — cobertura
  - Spec: `docs/admin-integration.md` v0.4
- **Meta CAPI:** https://developers.facebook.com/docs/marketing-api/conversions-api
- **Google Ads enhanced conversions:** https://support.google.com/google-ads/answer/13262500
- **TikTok Events API v1.3:** https://business-api.tiktok.com/portal/docs?id=1771101303285761

---

## 11. Quando atualizar este doc

Bumpar versão sempre que:
- Surgir click ID novo de plataforma (ex: Pinterest, Snapchat, Reddit)
- PMT alterar contrato de tracker/webhook
- Aparecer pegadinha nova (deploy bug, regression, gotcha)

Mantenha changelog informal no fim deste arquivo se crescer.
