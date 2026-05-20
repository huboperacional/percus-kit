"use client";

import * as React from "react";
import { useTenant } from "percus-auth/tenant";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { CountryDialPicker, DEFAULT_COUNTRY, type Country } from "./country-dial-picker";
import { MethodToggle, type LoginMethod } from "./method-toggle";
import { SupportLink } from "./support-link";
import { maskPhone, stripPhone } from "../lib/phone-mask";

export interface LoginPayload {
  channel: LoginMethod;
  destination: string;  // E.164 com + (whatsapp) ou email lowercase
  audience: string;
}

export interface LoginCardProps {
  onSubmit: (payload: LoginPayload) => void | Promise<void>;
}

function interpolateCopy(template: string, product_name: string): string {
  return template.replaceAll("{product_name}", product_name);
}

export function LoginCard({ onSubmit }: LoginCardProps) {
  const { config, status } = useTenant();
  const [method, setMethod] = React.useState<LoginMethod>("whatsapp");
  const [country, setCountry] = React.useState<Country>(DEFAULT_COUNTRY);
  const [phoneMasked, setPhoneMasked] = React.useState("");
  const [email, setEmail] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);

  if (status === "loading") {
    return <div className="animate-pulse h-96 bg-muted rounded-xl" />;
  }

  const product_name = config?.product_name ?? "Percus";
  const helperTemplate = config?.copy?.helper_text ?? "Você receberá uma mensagem do {product_name}.";
  const helperText = interpolateCopy(helperTemplate, product_name);
  const titleTemplate = config?.copy?.login_title ?? "Entrar no {product_name}";
  const title = interpolateCopy(titleTemplate, product_name);
  const ctaTemplate = config?.copy?.cta
    ?? (method === "whatsapp" ? "Enviar link pelo WhatsApp" : "Enviar link por e-mail");
  const cta = interpolateCopy(ctaTemplate, product_name);

  const phoneDigits = stripPhone(phoneMasked);
  const canSubmit =
    !submitting &&
    !!config &&
    (method === "whatsapp" ? phoneDigits.length >= 10 : /^[^@]+@[^@]+\.[^@]+$/.test(email));

  async function handleSubmit() {
    if (!config) return;
    setSubmitting(true);
    try {
      const destination =
        method === "whatsapp"
          ? `${country.dialCode}${phoneDigits}`
          : email.trim().toLowerCase();
      await onSubmit({ channel: method, destination, audience: config.audience });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="w-full max-w-md mx-auto p-6 rounded-xl border shadow-sm bg-card space-y-6">
      <div className="text-center space-y-1">
        {config?.logo_url && (
          <img src={config.logo_url} alt="" className="mx-auto h-10" />
        )}
        <h1 className="text-2xl font-semibold">{title}</h1>
        <p className="text-sm text-muted-foreground">
          Receba um link de login. Sem senha — mais rápido e mais seguro.
        </p>
      </div>

      <MethodToggle value={method} onChange={setMethod} />

      {method === "whatsapp" ? (
        <div className="space-y-2">
          <label className="text-sm font-medium">Seu WhatsApp</label>
          <div className="flex">
            <CountryDialPicker value={country} onChange={setCountry} />
            <Input
              type="tel"
              inputMode="numeric"
              autoComplete="tel-national"
              placeholder="(11) 98765-4321"
              className="rounded-l-none"
              value={phoneMasked}
              onChange={(e) => setPhoneMasked(maskPhone(e.target.value))}
            />
          </div>
          <p className="text-xs text-muted-foreground">
            DDD + número (10 ou 11 dígitos). {helperText}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          <label className="text-sm font-medium">Seu e-mail</label>
          <Input
            type="email"
            autoComplete="email"
            placeholder="voce@exemplo.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <p className="text-xs text-muted-foreground">{helperText}</p>
        </div>
      )}

      <Button onClick={handleSubmit} disabled={!canSubmit} className="w-full">
        {cta}
      </Button>

      <p className="text-center text-xs text-muted-foreground">
        Conexão segura · link válido por 15 minutos
      </p>

      <SupportLink />
    </div>
  );
}
