# Checklist auth setup — {{AUDIENCE}}

Este arquivo foi gerado pelo `scaffold-percus-project.ps1`/`.sh`. Marque os itens conforme completar.

## Audience no auth-service

- [ ] Login em https://auth.huboperacional.com.br/admin (operador admin com TOTP step-up)
- [ ] Criar audience `{{AUDIENCE}}` em `/admin/audiences/new`
  - slug: `{{AUDIENCE}}` (kebab-case obrigatório — R7)
  - `origins`: lista TODAS as origens do projeto (prod, staging, preview deploys do Vercel/Netlify, localhost para dev)

## Branding

- [ ] PUT `/admin/audiences/{{AUDIENCE}}/branding` (via UI ou curl + token step-up):
  - `product_name`: nome exibido (ex: "Plexco Coach")
  - `logo_url`: URL HTTPS do logo (256x256 SVG recomendado)
  - `logo_url_dark` (opcional): variante para dark mode
  - `palette`: `{ "primary": "#XXXXXX", "accent": "#XXXXXX" }` (hex)
  - `copy` (opcional): `{ "helper_text": "Você receberá uma mensagem do {product_name}." }` — pode usar interpolação `{product_name}`
  - `support_contact_url`: WhatsApp ou URL do canal de suporte

## Smoke E2E

- [ ] Dev server up (`npm run dev` ou equivalente)
- [ ] Abrir `/login` no browser — verificar que renderiza com `product_name` correto (não fallback "Percus")
- [ ] Digitar phone/email real do operador, clicar CTA
- [ ] Receber OTP (WhatsApp ou email)
- [ ] Validar OTP → ser redirecionado para dashboard
- [ ] Inspecionar DevTools Application → Cookies → ver `percus_session` com flag httpOnly + Secure + SameSite=Lax

## Regression test

- [ ] Rodar `npm run test` (ou pytest) — todos verdes
- [ ] Rodar `/percus-review:review` antes do primeiro commit

## Marcar projeto como [5-T] (R1)

- [ ] CRUD básico testado E2E com F5 (criar, editar, deletar registro real)
- [ ] HANDOFF.md (se existir) atualizado com este escopo

---

**Versão template:** Canon Percus v6.8.0. Atualizar conforme `CANON_VERSION.md` evolui.
