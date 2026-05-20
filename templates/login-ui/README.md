# templates/login-ui — Login canônico Percus

Template copy-paste (estilo shadcn) para construir página de login Percus em qualquer projeto Next.js.

## Como usar (manual)

1. **Copy** todo o conteúdo de `templates/login-ui/components/` pra `<projeto>/src/components/auth/`.
2. **Copy** `templates/login-ui/lib/phone-mask.ts` pra `<projeto>/src/lib/`.
3. **Copy** todos os `templates/login-ui/api/*.template` pra `<projeto>/src/app/api/auth/<endpoint>/route.ts` (remover sufixo `.template`).
4. **Copy** `.env.example` content pra `.env.local` e preencher.
5. Em `<projeto>/src/app/login/page.tsx`:

   ```tsx
   "use client";
   import { LoginCard } from "@/components/auth/login-card";
   import { useRouter } from "next/navigation";

   export default function LoginPage() {
     const router = useRouter();
     return (
       <LoginCard
         onSubmit={async (payload) => {
           const res = await fetch("/api/auth/request", {
             method: "POST",
             headers: { "content-type": "application/json" },
             body: JSON.stringify(payload),
           });
           const { challenge_id } = await res.json();
           router.push(`/login/code?cid=${challenge_id}`);
         }}
       />
     );
   }
   ```

6. Em `<projeto>/src/app/layout.tsx`, montar `TenantProvider` da lib `percus-auth >= 0.4.0`:

   ```tsx
   import { TenantProvider } from "percus-auth/tenant";

   export default function RootLayout({ children }) {
     return (
       <html>
         <body>
           <TenantProvider
             authServiceUrl={process.env.NEXT_PUBLIC_AUTH_SERVICE_URL!}
             origin={typeof window !== "undefined" ? window.location.origin : ""}
             fallback={{
               audience: process.env.NEXT_PUBLIC_PERCUS_AUDIENCE_FALLBACK!,
               product_name: process.env.NEXT_PUBLIC_PERCUS_PRODUCT_FALLBACK ?? "Percus",
             }}
           >
             {children}
           </TenantProvider>
         </body>
       </html>
     );
   }
   ```

## Como usar (via scaffold script — Frente C)

```bash
pwsh "$env:PERCUS_CANON_DIR/tools/scaffold-percus-project.ps1" -ProjectPath . -AudienceFallback plexco-coach
```

Script faz steps 1-4 automaticamente.

## Checklist humano após copy

- [ ] Audience registrada no auth-service (`/admin/audiences/new`) com origins corretos (incluindo preview deploys)
- [ ] Branding subido em `/admin/audiences/{slug}/branding` (logo, palette, copy, support_contact_url)
- [ ] Smoke E2E: OTP → validate → /me

## Versionamento

Esta versão alinha-se ao canon Percus v6.8.0. Mudanças breaking em versões futuras serão refletidas em `_Novo_Projeto/CANON_VERSION.md`.
