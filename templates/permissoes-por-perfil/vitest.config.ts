import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

/**
 * Vitest config para os testes do template permissoes-por-perfil.
 * jsdom é necessário para os render tests dos componentes.
 *
 * Os arquivos do template importam `@/components/ui/*`, `@/lib/utils` e
 * `lucide-react` — esses resolvem no projeto destino, NÃO no canon. Para os
 * testes rodarem isolados aqui, as importações abaixo apontam para stubs.
 *
 * IMPORTANTE: os stubs são infra de teste — NÃO fazem parte do copy-paste.
 */
const stub = (p: string) => fileURLToPath(new URL(p, import.meta.url));

export default defineConfig({
  // Sem isto o esbuild usa o transform clássico e exige React no escopo.
  esbuild: { jsx: "automatic" },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./vitest.setup.ts"],
    include: ["__tests__/**/*.test.{ts,tsx}"],
    exclude: ["**/node_modules/**", "__tests__/__stubs__/**"],
  },
  resolve: {
    alias: {
      "@/lib/utils": stub("./__tests__/__stubs__/ui.tsx"),
      "lucide-react": stub("./__tests__/__stubs__/ui.tsx"),
    },
  },
});
