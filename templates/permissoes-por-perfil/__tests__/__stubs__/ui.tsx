/**
 * Stubs das dependências que resolvem no PROJETO DESTINO, não no canon.
 * Infra de teste — NÃO faz parte do copy-paste.
 */
import * as React from "react";

/** `cn` do shadcn (`@/lib/utils`) — concatena classes ignorando falsy. */
export function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(" ");
}

/** Ícones do lucide-react: só precisam renderizar algo identificável. */
function icone(nome: string) {
  const Icone = (props: React.SVGProps<SVGSVGElement>) => (
    <svg data-icone={nome} aria-hidden {...props} />
  );
  Icone.displayName = nome;
  return Icone;
}

export const ChevronRight = icone("chevron-right");
export const ChevronDown = icone("chevron-down");
export const Search = icone("search");
