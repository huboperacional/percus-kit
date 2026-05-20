import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import React from "react";
import { LoginCard } from "../components/login-card";

vi.mock("@percus/auth", () => ({
  useTenant: () => ({
    status: "ready",
    config: {
      audience: "plexco-coach",
      product_name: "Plexco Coach",
      copy: { helper_text: "Você receberá uma mensagem do {product_name}." },
    },
    error: null,
    refresh: () => {},
  }),
}));

describe("LoginCard", () => {
  it("renderiza título com product_name do tenant", () => {
    render(<LoginCard onSubmit={vi.fn()} />);
    expect(screen.getByText("Entrar no Plexco Coach")).toBeInTheDocument();
  });

  it("interpola {product_name} no helper text", () => {
    render(<LoginCard onSubmit={vi.fn()} />);
    // helper_text "Você receberá uma mensagem do {product_name}." -> interpolado.
    // "Plexco Coach" também aparece no título, então qualificamos pela frase do helper.
    expect(
      screen.getByText(/mensagem do Plexco Coach/)
    ).toBeInTheDocument();
  });

  it("CTA disabled quando phone vazio", () => {
    render(<LoginCard onSubmit={vi.fn()} />);
    expect(screen.getByRole("button", { name: /Enviar link/i })).toBeDisabled();
  });

  it("chama onSubmit com payload canônico ao clicar CTA", async () => {
    const handle = vi.fn();
    render(<LoginCard onSubmit={handle} />);

    const input = screen.getByPlaceholderText("(11) 98765-4321");
    fireEvent.change(input, { target: { value: "11987654321" } });

    const cta = screen.getByRole("button", { name: /Enviar link/i });
    fireEvent.click(cta);

    await waitFor(() => {
      expect(handle).toHaveBeenCalledWith({
        channel: "whatsapp",
        destination: "+5511987654321",
        audience: "plexco-coach",
      });
    });
  });
});
