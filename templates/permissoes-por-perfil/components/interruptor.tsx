"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

export interface InterruptorProps {
  ligado: boolean;
  /** Só o mestre de grupo usa: algumas ligadas, não todas. */
  parcial?: boolean;
  /** Nome acessível — é por ele que o leitor de tela identifica a linha. */
  rotulo: string;
  onClick: () => void;
  className?: string;
}

/**
 * Interruptor pill do padrão Percus.
 *
 * `aria-checked` fica em true/false porque a especificação de `switch` não
 * aceita `mixed`; o estado parcial é comunicado pelo desenho e pelo contador
 * ao lado, que diz exatamente quantas estão ligadas.
 */
export function Interruptor({
  ligado,
  parcial = false,
  rotulo,
  onClick,
  className,
}: InterruptorProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={ligado}
      aria-label={rotulo}
      onClick={onClick}
      className={cn(
        "relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring",
        ligado ? "bg-primary" : parcial ? "bg-primary/40" : "bg-muted",
        className
      )}
    >
      <span
        className={cn(
          "block size-4 rounded-full bg-background shadow transition-transform",
          ligado ? "translate-x-[18px]" : parcial ? "translate-x-[9px]" : "translate-x-[2px]"
        )}
      />
    </button>
  );
}
