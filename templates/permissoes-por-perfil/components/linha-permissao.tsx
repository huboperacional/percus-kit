"use client";

import * as React from "react";
import { Interruptor } from "./interruptor";
import type { Permissao } from "../lib/modelo-permissoes";

export interface LinhaPermissaoProps {
  permissao: Permissao;
  ligada: boolean;
  onAlternar: (permissaoId: string) => void;
}

/**
 * Uma permissão: nome à esquerda, descrição no meio, interruptor à direita.
 * Sem régua separando linhas — o padrão separa por espaço (ver README).
 */
export function LinhaPermissao({ permissao, ligada, onAlternar }: LinhaPermissaoProps) {
  return (
    <div className="flex items-start gap-4 py-2.5 pl-7 pr-1">
      <span className="min-w-0 flex-[0_0_15rem] text-sm font-medium text-foreground">
        {permissao.nome}
      </span>
      <span className="min-w-0 flex-1 text-sm text-muted-foreground">
        {permissao.descricao}
      </span>
      <Interruptor
        ligado={ligada}
        rotulo={permissao.nome}
        onClick={() => onAlternar(permissao.id)}
      />
    </div>
  );
}
