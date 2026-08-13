/**
 * Modelo puro do editor de permissões por perfil.
 *
 * Nenhuma função aqui toca React, rede ou armazenamento — só recebe dados e
 * devolve dados. É o que permite testar a regra sem renderizar nada.
 */

export interface Permissao {
  id: string;
  nome: string;
  descricao?: string;
}

export interface GrupoPermissao {
  id: string;
  titulo: string;
  permissoes: Permissao[];
}

export interface Perfil {
  id: string;
  nome: string;
  permissoes: string[];
}

/** Estado do interruptor-mestre de um grupo. */
export type EstadoGrupo = "nenhum" | "parcial" | "todos";

/**
 * Quantas permissões DESTE grupo o perfil tem ligadas.
 * Sempre sobre o grupo inteiro — a busca não muda esta conta (ver README).
 */
export function contarLigadas(grupo: GrupoPermissao, ligadas: string[]): number {
  const conjunto = new Set(ligadas);
  return grupo.permissoes.filter((p) => conjunto.has(p.id)).length;
}

export function estadoDoGrupo(grupo: GrupoPermissao, ligadas: string[]): EstadoGrupo {
  const total = grupo.permissoes.length;
  const ligadasNoGrupo = contarLigadas(grupo, ligadas);

  // Grupo vazio é "nenhum": um `every` sobre lista vazia devolveria "todos",
  // que acenderia o mestre de um grupo sem nada dentro.
  if (ligadasNoGrupo === 0) return "nenhum";
  return ligadasNoGrupo === total ? "todos" : "parcial";
}

/** Liga ou desliga uma permissão. Devolve uma lista nova — nunca muta a recebida. */
export function alternarPermissao(ligadas: string[], permissaoId: string): string[] {
  return ligadas.includes(permissaoId)
    ? ligadas.filter((id) => id !== permissaoId)
    : [...ligadas, permissaoId];
}

/**
 * Interruptor-mestre do grupo: cheio desliga tudo, nenhum/parcial liga tudo.
 *
 * Age sobre o grupo INTEIRO, mesmo com busca ativa filtrando linhas na tela —
 * é o mesmo recorte que o contador mostra, então o mestre e o número nunca
 * discordam.
 */
export function alternarGrupo(grupo: GrupoPermissao, ligadas: string[]): string[] {
  const idsDoGrupo = grupo.permissoes.map((p) => p.id);

  if (estadoDoGrupo(grupo, ligadas) === "todos") {
    const doGrupo = new Set(idsDoGrupo);
    return ligadas.filter((id) => !doGrupo.has(id));
  }

  const jaLigadas = new Set(ligadas);
  return [...ligadas, ...idsDoGrupo.filter((id) => !jaLigadas.has(id))];
}

/** Um grupo e as permissões dele que sobreviveram à busca. */
export interface ResultadoBusca {
  /** O grupo ORIGINAL, inteiro — é dele que o contador tira o total. */
  grupo: GrupoPermissao;
  /** Só as permissões a renderizar agora. Com busca vazia, todas. */
  visiveis: Permissao[];
}

/** Tira acento e caixa, pra "usuario" encontrar "Ver usuários". */
function normalizar(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase();
}

/**
 * Filtra as permissões pelo nome. Grupo sem nenhuma correspondência some da
 * lista; grupo com correspondência devolve só as linhas que casam — mas o
 * `grupo` devolvido continua inteiro, para o contador não seguir a busca.
 */
export function filtrarPorBusca(
  grupos: GrupoPermissao[],
  termo: string
): ResultadoBusca[] {
  const busca = normalizar(termo.trim());

  if (busca === "") {
    return grupos.map((grupo) => ({ grupo, visiveis: grupo.permissoes }));
  }

  return grupos
    .map((grupo) => ({
      grupo,
      visiveis: grupo.permissoes.filter((p) => normalizar(p.nome).includes(busca)),
    }))
    .filter((resultado) => resultado.visiveis.length > 0);
}
