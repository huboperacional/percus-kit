/**
 * Máscara progressiva pra telefones brasileiros.
 * Aceita 10 dígitos (fixo) ou 11 dígitos (celular).
 * Trunca em 11 e ignora caracteres não-numéricos do input.
 */
export function stripPhone(raw: string): string {
  return raw.replace(/\D/g, "");
}

export function maskPhone(raw: string): string {
  const digits = stripPhone(raw).slice(0, 11);
  const len = digits.length;
  if (len === 0) return "";
  if (len <= 2) return `(${digits}`;
  if (len <= 6) return `(${digits.slice(0, 2)}) ${digits.slice(2)}`;
  if (len <= 10) {
    // 10 dígitos: (XX) XXXX-XXXX
    return `(${digits.slice(0, 2)}) ${digits.slice(2, 6)}-${digits.slice(6)}`;
  }
  // 11 dígitos: (XX) XXXXX-XXXX
  return `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`;
}
