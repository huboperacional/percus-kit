import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

/**
 * Vitest config para os testes do template login-ui.
 * jsdom é necessário para o render test de login-card.test.tsx.
 *
 * Os arquivos do template importam `@/components/ui/*`, `@/lib/utils`,
 * `lucide-react` e `@percus/auth` — esses resolvem no projeto destino,
 * NÃO no canon. Para o render test rodar isolado, as importações abaixo são
 * apontadas para stubs de teste (__tests__/__stubs__/ui.tsx). `@percus/auth`
 * é mockado via `vi.mock` dentro do próprio teste.
 *
 * IMPORTANTE: os stubs são infra de teste — NÃO fazem parte do copy-paste.
 */
const stub = (p: string) => fileURLToPath(new URL(p, import.meta.url));

export default defineConfig({
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./vitest.setup.ts"],
    include: ["__tests__/**/*.test.{ts,tsx}"],
    exclude: ["**/node_modules/**", "__tests__/__stubs__/**"],
  },
  resolve: {
    alias: {
      "@/components/ui/button": stub("./__tests__/__stubs__/ui.tsx"),
      "@/components/ui/input": stub("./__tests__/__stubs__/ui.tsx"),
      "@/components/ui/dropdown-menu": stub("./__tests__/__stubs__/ui.tsx"),
      "@/lib/utils": stub("./__tests__/__stubs__/ui.tsx"),
      "lucide-react": stub("./__tests__/__stubs__/ui.tsx"),
      "@percus/auth": stub("./__tests__/__stubs__/tenant.ts"),
    },
  },
});
