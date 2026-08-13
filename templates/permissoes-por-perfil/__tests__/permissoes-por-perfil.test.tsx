/**
 * ATENÇÃO — estes testes NÃO exercitam as dependências reais.
 *
 * `vitest.config.ts` aponta `@/lib/utils` e `lucide-react` para
 * `__tests__/__stubs__/ui.tsx`, porque as duas só existem no projeto destino.
 * Consequência: o `cn` aqui é um `join` simples, sem `clsx`/`tailwind-merge` —
 * conflito de classe Tailwind NÃO é coberto por nenhum teste deste arquivo.
 * O que se testa aqui é comportamento (abrir, filtrar, contar, alternar).
 */
import { describe, expect, test, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { PermissoesPorPerfil } from "../components/permissoes-por-perfil";
import type { GrupoPermissao, Perfil } from "../lib/modelo-permissoes";

const grupos: GrupoPermissao[] = [
  {
    id: "usuarios",
    titulo: "Usuários",
    permissoes: [
      { id: "usuarios.ler", nome: "Ver usuários", descricao: "Lista quem tem acesso." },
      { id: "usuarios.criar", nome: "Criar usuário", descricao: "Cria e envia convite." },
      { id: "usuarios.excluir", nome: "Excluir usuário" },
    ],
  },
  {
    id: "financeiro",
    titulo: "Financeiro",
    permissoes: [
      { id: "financeiro.ler", nome: "Ver lançamentos" },
      { id: "financeiro.baixar", nome: "Dar baixa" },
    ],
  },
];

const perfis: Perfil[] = [
  { id: "admin", nome: "Administrador", permissoes: ["usuarios.ler", "usuarios.criar"] },
  { id: "vendedor", nome: "Vendedor", permissoes: ["financeiro.ler"] },
];

function montar(onChange = vi.fn()) {
  render(<PermissoesPorPerfil perfis={perfis} grupos={grupos} onChange={onChange} />);
  return { onChange, usuario: userEvent.setup() };
}

describe("PermissoesPorPerfil", () => {
  test("começa com os grupos fechados", () => {
    montar();

    expect(screen.queryByText("Ver usuários")).not.toBeInTheDocument();
  });

  test("clicar no grupo revela as permissões dele", async () => {
    const { usuario } = montar();

    await usuario.click(screen.getByRole("button", { name: /Usuários/ }));

    expect(screen.getByText("Ver usuários")).toBeInTheDocument();
  });

  test("o contador mostra ligadas sobre o total do grupo no perfil atual", () => {
    montar();

    expect(screen.getByRole("button", { name: /Usuários/ })).toHaveTextContent("2/3");
  });

  test("ligar uma permissão avisa o perfil e a lista nova", async () => {
    const { onChange, usuario } = montar();

    await usuario.click(screen.getByRole("button", { name: /Usuários/ }));
    await usuario.click(screen.getByRole("switch", { name: "Excluir usuário" }));

    expect(onChange).toHaveBeenCalledWith("admin", [
      "usuarios.ler",
      "usuarios.criar",
      "usuarios.excluir",
    ]);
  });

  test("desligar uma permissão avisa a lista sem ela", async () => {
    const { onChange, usuario } = montar();

    await usuario.click(screen.getByRole("button", { name: /Usuários/ }));
    await usuario.click(screen.getByRole("switch", { name: "Ver usuários" }));

    expect(onChange).toHaveBeenCalledWith("admin", ["usuarios.criar"]);
  });

  test("o mestre parcial liga todas as permissões do grupo", async () => {
    const { onChange, usuario } = montar();

    await usuario.click(
      screen.getByRole("switch", { name: "Todas as permissões de Usuários" })
    );

    expect(onChange).toHaveBeenCalledWith("admin", [
      "usuarios.ler",
      "usuarios.criar",
      "usuarios.excluir",
    ]);
  });

  test("trocar de perfil mostra as permissões do outro perfil", async () => {
    const { usuario } = montar();

    await usuario.selectOptions(screen.getByLabelText("Perfil"), "vendedor");

    expect(screen.getByRole("button", { name: /Financeiro/ })).toHaveTextContent("1/2");
    expect(screen.getByRole("button", { name: /Usuários/ })).toHaveTextContent("0/3");
  });

  test("buscar abre o grupo com resultado e some com os demais", async () => {
    const { usuario } = montar();

    await usuario.type(screen.getByLabelText("Buscar permissão"), "baixa");

    expect(screen.getByText("Dar baixa")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Usuários/ })).not.toBeInTheDocument();
  });

  test("o contador não acompanha a busca", async () => {
    const { usuario } = montar();

    await usuario.type(screen.getByLabelText("Buscar permissão"), "criar");

    // só "Criar usuário" aparece, mas o contador segue falando do grupo inteiro
    expect(screen.getByRole("button", { name: /Usuários/ })).toHaveTextContent("2/3");
  });

  test("com busca ativa, clicar no cabeçalho fecha o grupo", async () => {
    const { usuario } = montar();

    await usuario.type(screen.getByLabelText("Buscar permissão"), "criar");
    expect(screen.getByText("Criar usuário")).toBeInTheDocument();

    await usuario.click(screen.getByRole("button", { name: /Usuários/ }));

    expect(screen.queryByText("Criar usuário")).not.toBeInTheDocument();
  });

  test("grupo fechado durante a busca não reaparece aberto ao limpar a busca", async () => {
    const { usuario } = montar();
    const campoBusca = screen.getByLabelText("Buscar permissão");

    await usuario.type(campoBusca, "criar");
    await usuario.click(screen.getByRole("button", { name: /Usuários/ }));
    await usuario.clear(campoBusca);

    expect(screen.queryByText("Ver usuários")).not.toBeInTheDocument();
  });

  test("busca sem resultado avisa em vez de mostrar lista vazia", async () => {
    const { usuario } = montar();

    await usuario.type(screen.getByLabelText("Buscar permissão"), "zzz");

    expect(screen.getByText(/nenhuma permissão/i)).toBeInTheDocument();
  });
});
