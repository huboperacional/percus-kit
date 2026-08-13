"use client";

import * as React from "react";
import { Search } from "lucide-react";
import { cn } from "@/lib/utils";

import { GrupoPermissao } from "./grupo-permissao";
import {
  alternarGrupo,
  alternarPermissao,
  filtrarPorBusca,
  type GrupoPermissao as Grupo,
  type Perfil,
} from "../lib/modelo-permissoes";

export interface PermissoesPorPerfilProps {
  /** Os perfis do projeto, cada um com as permissões que já tem. */
  perfis: Perfil[];
  /** Os blocos de permissão — iguais para todos os perfis. */
  grupos: Grupo[];
  /** Dispara a cada clique. Quem chama decide se salva na hora ou acumula. */
  onChange: (perfilId: string, permissoes: string[]) => void;
  /** Perfil aberto ao montar. Padrão: o primeiro da lista. */
  perfilInicialId?: string;
  className?: string;
}

/**
 * Editor de permissões por perfil de usuário — o "seletor de acessos" Percus.
 *
 * As permissões são controladas pelo pai (via `perfis`); só a seleção de perfil
 * e a busca são estado interno. O componente não busca, não salva e não sabe o
 * que cada permissão significa.
 */
export function PermissoesPorPerfil({
  perfis,
  grupos,
  onChange,
  perfilInicialId,
  className,
}: PermissoesPorPerfilProps) {
  const [perfilId, setPerfilId] = React.useState(perfilInicialId ?? perfis[0]?.id);
  const [busca, setBusca] = React.useState("");
  const [abertos, setAbertos] = React.useState<string[]>([]);
  const [buscaAplicada, setBuscaAplicada] = React.useState("");

  const perfil = perfis.find((p) => p.id === perfilId) ?? perfis[0];
  const ligadas = perfil?.permissoes ?? [];
  const resultados = filtrarPorBusca(grupos, busca);

  // `abertos` é a ÚNICA fonte de verdade da abertura. A busca não força o grupo
  // a ficar aberto — ela apenas abre, no instante em que o termo muda, os que
  // têm resultado. Sem isso, o clique no cabeçalho não conseguiria fechar nada
  // enquanto houvesse busca ativa (padrão React de ajuste de estado no render).
  if (busca !== buscaAplicada) {
    setBuscaAplicada(busca);
    if (busca.trim() !== "") {
      setAbertos(resultados.map((r) => r.grupo.id));
    }
  }

  function alternarAbertura(grupoId: string) {
    setAbertos((atuais) =>
      atuais.includes(grupoId)
        ? atuais.filter((id) => id !== grupoId)
        : [...atuais, grupoId]
    );
  }

  if (!perfil) return null;

  return (
    <div className={cn("rounded-2xl bg-card p-6 shadow-sm", className)}>
      <label htmlFor="perfil-permissoes" className="sr-only">
        Perfil
      </label>
      <select
        id="perfil-permissoes"
        value={perfil.id}
        onChange={(e) => setPerfilId(e.target.value)}
        className={cn(
          "h-10 w-full max-w-xs rounded-xl border border-input bg-background px-3 text-sm",
          "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
        )}
      >
        {perfis.map((p) => (
          <option key={p.id} value={p.id}>
            {p.nome}
          </option>
        ))}
      </select>

      <p className="mt-3 max-w-[66ch] text-sm text-muted-foreground">
        Defina o que o perfil <strong className="font-medium text-foreground">{perfil.nome}</strong>{" "}
        pode fazer.
      </p>

      <div className="relative mt-4">
        <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <label htmlFor="busca-permissoes" className="sr-only">
          Buscar permissão
        </label>
        <input
          id="busca-permissoes"
          type="search"
          value={busca}
          onChange={(e) => setBusca(e.target.value)}
          placeholder="Buscar permissão…"
          className={cn(
            "h-10 w-full rounded-full border border-input bg-background pl-9 pr-4 text-sm",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
          )}
        />
      </div>

      <div className="mt-4">
        {resultados.length === 0 ? (
          <p className="py-8 text-center text-sm text-muted-foreground">
            Nenhuma permissão encontrada para “{busca.trim()}”.
          </p>
        ) : (
          resultados.map(({ grupo, visiveis }) => (
            <GrupoPermissao
              key={grupo.id}
              grupo={grupo}
              visiveis={visiveis}
              ligadas={ligadas}
              aberto={abertos.includes(grupo.id)}
              onAlternarAbertura={() => alternarAbertura(grupo.id)}
              onAlternarPermissao={(permissaoId) =>
                onChange(perfil.id, alternarPermissao(ligadas, permissaoId))
              }
              onAlternarGrupo={() => onChange(perfil.id, alternarGrupo(grupo, ligadas))}
            />
          ))
        )}
      </div>
    </div>
  );
}
