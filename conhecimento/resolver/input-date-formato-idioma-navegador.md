## `<input type="date">` mostra mm/dd mesmo com a página inteira em pt-BR {#input-date-formato-idioma-navegador}

`tags: input date, formato de data, dd/mm/aaaa, mm/dd, locale, lang, navegador em ingles, mascara, PatternFormat, react-number-format, showPicker, picker nativo`

**Sintoma:** usuário com o navegador em inglês vê datas `mm/dd/aaaa` numa página inteiramente
pt-BR; pôr `lang="pt-BR"` no HTML não muda nada.

**Causa raiz:** o formato de EXIBIÇÃO do `<input type="date">` nativo segue o **idioma da
interface do navegador**, não o `lang` da página — testado nos 3 casos (sem `lang`, `en-US`,
`pt-BR`): renderizam igual. Não existe fix por atributo.

**Solução:** componente próprio que preserva o picker nativo: input de texto com máscara
digitável `dd/mm/aaaa` (na FM: `PatternFormat` do `react-number-format`, dep que já estava no
bundle pro campo de dinheiro — zero dependência nova) + um `<input type="date">` **oculto**
(opacity 0, 1×1, `tabIndex={-1}`, `aria-hidden`) ancorando o botão de calendário via
`el.showPicker()` com fallback `el.focus()`. O contrato com o form continua ISO
(`aaaa-mm-dd`), idêntico ao input que foi substituído: digitação completa e válida emite ISO,
incompleta/inválida emite `''` — a validação de obrigatório do form segue intacta e os
call-sites não mudam de shape. Implementação de referência:
`Familia-Milionaria/familia-frontend/src/components/DateInput.tsx`.

**Ref:** FM commit `cbbd4e6` (2026-07-28) + spec `tests/e2e/date-mask.spec.ts` (digitou
dd/mm/aaaa → POST ISO; incompleta → zero POST; picker sincroniza a máscara).
