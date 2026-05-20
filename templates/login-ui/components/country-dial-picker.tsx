"use client";

import * as React from "react";
import { ChevronDown } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

/**
 * Países suportados pela máscara de telefone canônica Percus.
 * Adicionar país aqui exige adicionar máscara correspondente em phone-mask.ts.
 */
export interface Country {
  code: string;       // ISO 3166-1 alpha-2
  dialCode: string;   // ex: "+55"
  name: string;
  flag: React.ReactNode;
}

const FlagBR = () => (
  <svg viewBox="0 0 24 16" width="24" height="16" aria-hidden>
    <rect width="24" height="16" fill="#009C3B" />
    <polygon points="12,2 22,8 12,14 2,8" fill="#FFDF00" />
    <circle cx="12" cy="8" r="3" fill="#002776" />
  </svg>
);
const FlagUS = () => (
  <svg viewBox="0 0 24 16" width="24" height="16" aria-hidden>
    <rect width="24" height="16" fill="#FFFFFF" />
    {[0,2,4,6,8,10,12,14].map(y => (
      <rect key={y} y={y} width="24" height="1" fill="#B22234" />
    ))}
    <rect width="10" height="8" fill="#3C3B6E" />
  </svg>
);
const FlagPT = () => (
  <svg viewBox="0 0 24 16" width="24" height="16" aria-hidden>
    <rect width="24" height="16" fill="#FF0000" />
    <rect width="9" height="16" fill="#006600" />
    <circle cx="9" cy="8" r="2.5" fill="#FFDF00" />
  </svg>
);
const FlagAR = () => (
  <svg viewBox="0 0 24 16" width="24" height="16" aria-hidden>
    <rect width="24" height="16" fill="#FFFFFF" />
    <rect width="24" height="5" fill="#74ACDF" />
    <rect width="24" height="5" y="11" fill="#74ACDF" />
    <circle cx="12" cy="8" r="1.5" fill="#FFB000" />
  </svg>
);

export const COUNTRIES: Country[] = [
  { code: "BR", dialCode: "+55", name: "Brasil", flag: <FlagBR /> },
  { code: "US", dialCode: "+1",  name: "EUA",    flag: <FlagUS /> },
  { code: "PT", dialCode: "+351", name: "Portugal", flag: <FlagPT /> },
  { code: "AR", dialCode: "+54", name: "Argentina", flag: <FlagAR /> },
];

export interface CountryDialPickerProps {
  value: Country;
  onChange: (country: Country) => void;
}

export function CountryDialPicker({ value, onChange }: CountryDialPickerProps) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="flex items-center gap-1 px-2 py-1 rounded-l-md border border-r-0 border-input bg-background">
        {value.flag}
        <span className="text-sm">{value.dialCode}</span>
        <ChevronDown className="size-3 opacity-60" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        {COUNTRIES.map(c => (
          <DropdownMenuItem key={c.code} onSelect={() => onChange(c)} className="gap-2">
            {c.flag}
            <span>{c.dialCode}</span>
            <span className="text-muted-foreground text-xs">{c.name}</span>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

export const DEFAULT_COUNTRY = COUNTRIES[0]; // BR
