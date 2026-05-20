/**
 * Test-only resolution stub for `percus-auth/tenant`.
 *
 * NOT part of the copy-paste template. The real module ships in the
 * `percus-auth` lib (>= 0.4.0) and resolves in the target project.
 * vitest.config.ts aliases the bare `percus-auth/tenant` import here so Vite's
 * import-analysis can resolve it; individual tests override behavior with
 * `vi.mock("percus-auth/tenant", ...)`.
 */
export interface TenantCopy {
  helper_text?: string;
  login_title?: string;
  cta?: string;
}

export interface TenantConfig {
  audience: string;
  product_name: string;
  logo_url?: string;
  support_contact_url?: string;
  copy?: TenantCopy;
}

export interface UseTenantResult {
  status: "loading" | "ready" | "error";
  config: TenantConfig | null;
  error: unknown;
  refresh: () => void;
}

export function useTenant(): UseTenantResult {
  return { status: "loading", config: null, error: null, refresh: () => {} };
}
