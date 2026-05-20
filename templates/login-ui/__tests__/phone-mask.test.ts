import { describe, it, expect } from "vitest";
import { maskPhone, stripPhone } from "../lib/phone-mask";

describe("maskPhone", () => {
  it("formata 11 dígitos como (DDD) NNNNN-NNNN", () => {
    expect(maskPhone("11987654321")).toBe("(11) 98765-4321");
  });

  it("formata 10 dígitos como (DDD) NNNN-NNNN", () => {
    expect(maskPhone("1133334444")).toBe("(11) 3333-4444");
  });

  it("formata progressivamente conforme usuário digita", () => {
    expect(maskPhone("1")).toBe("(1");
    expect(maskPhone("11")).toBe("(11");
    expect(maskPhone("119")).toBe("(11) 9");
    expect(maskPhone("11987")).toBe("(11) 987");
    expect(maskPhone("119876")).toBe("(11) 9876");
    expect(maskPhone("1198765")).toBe("(11) 9876-5");
  });

  it("ignora não-dígitos no input", () => {
    expect(maskPhone("(11) 98765-4321")).toBe("(11) 98765-4321");
    expect(maskPhone("11 98765-4321")).toBe("(11) 98765-4321");
  });

  it("trunca em 11 dígitos", () => {
    expect(maskPhone("119876543210")).toBe("(11) 98765-4321");
  });
});

describe("stripPhone", () => {
  it("remove tudo exceto dígitos", () => {
    expect(stripPhone("(11) 98765-4321")).toBe("11987654321");
    expect(stripPhone("abc11def")).toBe("11");
  });
});
