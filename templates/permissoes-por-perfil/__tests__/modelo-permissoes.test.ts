import { describe, expect, test } from "vitest";
import {
  alternarGrupo,
  alternarPermissao,
  contarLigadas,
  estadoDoGrupo,
  filtrarPorBusca,
  type GrupoPermissao,
} from "../lib/modelo-permissoes";

const usuarios: GrupoPermissao = {
  id: "usuarios",
  titulo: "Usuários",
  permissoes: [
    { id: "usuarios.ler", nome: "Ver usuários" },
    { id: "usuarios.criar", nome: "Criar usuário" },
    { id: "usuarios.excluir", nome: "Excluir usuário" },
  ],
};

describe("contarLigadas", () => {
  test("conta apenas as permissões do grupo que estão ligadas no perfil", () => {
    const ligadas = ["usuarios.ler", "usuarios.criar", "financeiro.ler"];

    expect(contarLigadas(usuarios, ligadas)).toBe(2);
  });

  test("ignora permissão ligada que não pertence a nenhum grupo conhecido", () => {
    expect(contarLigadas(usuarios, ["permissao.fantasma"])).toBe(0);
  });
});

describe("estadoDoGrupo", () => {
  test("é 'nenhum' quando o perfil não tem permissão alguma do grupo", () => {
    expect(estadoDoGrupo(usuarios, [])).toBe("nenhum");
  });

  test("é 'parcial' quando o perfil tem algumas, mas não todas", () => {
    expect(estadoDoGrupo(usuarios, ["usuarios.ler"])).toBe("parcial");
  });

  test("é 'todos' quando o perfil tem todas as permissões do grupo", () => {
    const todas = usuarios.permissoes.map((p) => p.id);

    expect(estadoDoGrupo(usuarios, todas)).toBe("todos");
  });

  test("grupo sem permissões é 'nenhum', não 'todos'", () => {
    const vazio: GrupoPermissao = { id: "vazio", titulo: "Vazio", permissoes: [] };

    expect(estadoDoGrupo(vazio, [])).toBe("nenhum");
  });
});

describe("alternarPermissao", () => {
  test("liga a permissão que estava desligada", () => {
    expect(alternarPermissao([], "usuarios.ler")).toEqual(["usuarios.ler"]);
  });

  test("desliga a permissão que estava ligada", () => {
    expect(alternarPermissao(["usuarios.ler", "usuarios.criar"], "usuarios.ler")).toEqual([
      "usuarios.criar",
    ]);
  });

  test("não muta o array recebido", () => {
    const original = ["usuarios.ler"];

    alternarPermissao(original, "usuarios.criar");

    expect(original).toEqual(["usuarios.ler"]);
  });
});

describe("alternarGrupo", () => {
  test("liga todas as permissões do grupo quando estava parcial", () => {
    const resultado = alternarGrupo(usuarios, ["usuarios.ler"]);

    expect(resultado.sort()).toEqual(
      ["usuarios.ler", "usuarios.criar", "usuarios.excluir"].sort()
    );
  });

  test("liga todas quando não havia nenhuma", () => {
    expect(alternarGrupo(usuarios, []).sort()).toEqual(
      ["usuarios.ler", "usuarios.criar", "usuarios.excluir"].sort()
    );
  });

  test("desliga todas quando o grupo estava cheio", () => {
    const todas = usuarios.permissoes.map((p) => p.id);

    expect(alternarGrupo(usuarios, todas)).toEqual([]);
  });

  test("preserva permissões de outros grupos ao ligar", () => {
    const resultado = alternarGrupo(usuarios, ["financeiro.ler"]);

    expect(resultado).toContain("financeiro.ler");
  });

  test("preserva permissões de outros grupos ao desligar", () => {
    const todas = usuarios.permissoes.map((p) => p.id);

    const resultado = alternarGrupo(usuarios, [...todas, "financeiro.ler"]);

    expect(resultado).toEqual(["financeiro.ler"]);
  });

  test("não duplica permissão já ligada ao ligar o grupo", () => {
    const resultado = alternarGrupo(usuarios, ["usuarios.ler"]);

    expect(resultado.filter((id) => id === "usuarios.ler")).toHaveLength(1);
  });
});

const financeiro: GrupoPermissao = {
  id: "financeiro",
  titulo: "Financeiro",
  permissoes: [
    { id: "financeiro.ler", nome: "Ver lançamentos" },
    { id: "financeiro.baixar", nome: "Dar baixa" },
  ],
};

const grupos = [usuarios, financeiro];

describe("filtrarPorBusca", () => {
  test("busca vazia devolve todos os grupos com todas as permissões visíveis", () => {
    const resultado = filtrarPorBusca(grupos, "");

    expect(resultado).toHaveLength(2);
    expect(resultado[0].visiveis).toHaveLength(3);
    expect(resultado[1].visiveis).toHaveLength(2);
  });

  test("some com o grupo que não tem nenhuma permissão correspondente", () => {
    const resultado = filtrarPorBusca(grupos, "baixa");

    expect(resultado).toHaveLength(1);
    expect(resultado[0].grupo.id).toBe("financeiro");
  });

  test("mostra só as permissões que correspondem, dentro do grupo", () => {
    const resultado = filtrarPorBusca(grupos, "criar");

    expect(resultado[0].visiveis.map((p) => p.id)).toEqual(["usuarios.criar"]);
  });

  test("ignora maiúsculas e minúsculas", () => {
    expect(filtrarPorBusca(grupos, "CRIAR")[0].visiveis).toHaveLength(1);
  });

  test("ignora acento — 'usuario' encontra 'Ver usuários'", () => {
    const resultado = filtrarPorBusca(grupos, "usuario");

    expect(resultado).toHaveLength(1);
    expect(resultado[0].visiveis.length).toBeGreaterThan(0);
  });

  test("devolve o grupo ORIGINAL, para o contador não seguir a busca", () => {
    const ligadas = ["usuarios.ler", "usuarios.criar"];

    const resultado = filtrarPorBusca(grupos, "criar");

    // uma permissão visível, mas o contador ainda enxerga as 3 do grupo
    expect(resultado[0].visiveis).toHaveLength(1);
    expect(contarLigadas(resultado[0].grupo, ligadas)).toBe(2);
    expect(resultado[0].grupo.permissoes).toHaveLength(3);
  });

  test("busca só com espaços é tratada como busca vazia", () => {
    expect(filtrarPorBusca(grupos, "   ")).toHaveLength(2);
  });

  test("busca sem nenhum resultado devolve lista vazia", () => {
    expect(filtrarPorBusca(grupos, "xyz")).toEqual([]);
  });
});
