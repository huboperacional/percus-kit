"use client";

import { useTenant } from "@percus/auth";

export function SupportLink() {
  const { config } = useTenant();
  const url = config?.support_contact_url;

  if (!url) {
    return null;
  }
  return (
    <p className="text-center text-sm text-muted-foreground">
      Problemas com o acesso?{" "}
      <a
        href={url}
        target="_blank"
        rel="noopener noreferrer"
        className="font-medium text-foreground underline"
      >
        Falar com o operador
      </a>
    </p>
  );
}
