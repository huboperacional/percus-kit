"use client";

import * as React from "react";
import { MessageCircle, Mail } from "lucide-react";
import { cn } from "@/lib/utils";

export type LoginMethod = "whatsapp" | "email";

export interface MethodToggleProps {
  value: LoginMethod;
  onChange: (method: LoginMethod) => void;
  className?: string;
}

export function MethodToggle({ value, onChange, className }: MethodToggleProps) {
  return (
    <div
      role="radiogroup"
      aria-label="Canal de login"
      className={cn(
        "grid grid-cols-2 gap-1 p-1 bg-muted rounded-md",
        className
      )}
    >
      <button
        type="button"
        role="radio"
        aria-checked={value === "whatsapp"}
        onClick={() => onChange("whatsapp")}
        className={cn(
          "flex items-center justify-center gap-2 px-4 py-2 rounded text-sm font-medium transition",
          value === "whatsapp" ? "bg-background shadow" : "text-muted-foreground hover:text-foreground"
        )}
      >
        <MessageCircle className="size-4" aria-hidden />
        WhatsApp
      </button>
      <button
        type="button"
        role="radio"
        aria-checked={value === "email"}
        onClick={() => onChange("email")}
        className={cn(
          "flex items-center justify-center gap-2 px-4 py-2 rounded text-sm font-medium transition",
          value === "email" ? "bg-background shadow" : "text-muted-foreground hover:text-foreground"
        )}
      >
        <Mail className="size-4" aria-hidden />
        E-mail
      </button>
    </div>
  );
}
