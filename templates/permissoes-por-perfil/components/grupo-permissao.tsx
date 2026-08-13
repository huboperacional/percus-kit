"use client";

import * as React from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

import { Interruptor } from "./interruptor";
import { LinhaPermissao } from "./linha-permissao";
import {
  contarLigadas,
  estadoDoGrupo,
  type GrupoPermissao as Grupo,
  type Permissao,
} from "../lib/modelo-permissoes";

export interface GrupoPermissaoProps {
  /** O grupo INTEIRO — é dele que sai o contador. */
  grupo: Grupo;
  /** As permissões a renderizar agora (a busca pode ter reduzido). */
  visiveis: Permissao[];
  ligadas: string[];
  aberto: boolean;
  onAlternarAbertura: () => void;
  onAlternarPermissao: (permissaoId: string) => void;
  onAlternarGrupo: () => void;
}

export function GrupoPermissao({
  grupo,
  visiveis,
  ligadas,
  aberto,
  onAlternarAbertura,
  onAlternarPermissao,
  onAlternarGrupo,
}: GrupoPermissaoProps) {
  const estado = estadoDoGrupo(grupo, ligadas);
  const Chevron = aberto ? ChevronDown : ChevronRight;
  const ligadasNoGrupo = new Set(ligadas);

  return (
    <div className="border-t border-border/60 first:border-t-0">
      <div className="flex items-center gap-3 py-3 pr-1">
        <button
          type="button"
          aria-expanded={aberto}
          onClick={onAlternarAbertura}
          className={cn(
            "flex min-w-0 flex-1 items-center gap-2 text-left",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
          )}
        >
          <Chevron className="size-4 shrink-0 text-muted-foreground" />
          <span className="truncate text-sm font-semibold text-foreground">
            {grupo.titulo}
          </span>
          <span className="ml-auto pr-3 text-xs tabular-nums text-muted-foreground">
            {contarLigadas(grupo, ligadas)}/{grupo.permissoes.length}
          </span>
        </button>
        <Interruptor
          ligado={estado === "todos"}
          parcial={estado === "parcial"}
          rotulo={`Todas as permissões de ${grupo.titulo}`}
          onClick={onAlternarGrupo}
        />
      </div>

      {aberto && (
        <div className="pb-2">
          {visiveis.map((permissao) => (
            <LinhaPermissao
              key={permissao.id}
              permissao={permissao}
              ligada={ligadasNoGrupo.has(permissao.id)}
              onAlternar={onAlternarPermissao}
            />
          ))}
        </div>
      )}
    </div>
  );
}
