## `<input type="date">` nativo segue o locale do NAVEGADOR, não o `lang` da página {#input-date-nativo-segue-locale-do-navegador-nao-o-lang-da-pagina}

`tags: input type=date, locale, i18n, formato de data, html lang, chrome, dd/mm/yyyy, R23`

**Sintoma:** produto brasileiro, `<html lang="pt-BR">` no layout raiz, mas os campos de data
(`<input type="date">`) mostram `MM/DD/AAAA` (formato americano) em vez de `DD/MM/AAAA` pra
alguns usuários — mesmo código, mesma página, formato diferente conforme quem abre.

**Causa raiz:** o formato de EXIBIÇÃO de `<input type="date">` no Chrome/Chromium é decidido pelo
**locale do navegador/SO** (idioma da UI do Chrome, não o do sistema operacional necessariamente),
**não** pelo atributo `lang` do HTML. Isso é comportamento documentado do Chromium, não bug — e
não tem flag de CSS/HTML pra forçar. Firefox, por comparação, respeita o `lang` mais de perto —
então o mesmo código pode parecer "certo" em Firefox e "errado" em Chrome com perfil en-US.

**Onde bateu:** `web/src/app/dashboard/clients/[id]/(shell)/leads/hubspot-performance/page.tsx`,
26/08 — usuário com Chrome em locale en-US via os campos De/Até em `MM/DD/AAAA`. O `.value`
(programático) do input continua sempre ISO `YYYY-MM-DD`, só a exibição varia — o que engana quem
só testa via `fireEvent.change`/Playwright com valor ISO e nunca olha o rendering real.

**Fix aplicado:** trocar `<input type="date">` por um campo de texto mascarado
(`DateInputBR.tsx`) que formata manualmente pra `DD/MM/AAAA` e converte de/para o mesmo contrato
ISO usado no resto do código — mas **aceitando os DOIS formatos de entrada**: dígitos digitados
(mascarados ao vivo) E string ISO completa setada de uma vez (`fireEvent.change` de teste,
autofill, colar de outro campo `type="date"`). Sem esse segundo caminho, testes que migraram de
`type="date"` e ainda fazem `fireEvent.change(input, {value: "2026-02-27"})` quebram: os dígitos
de "2026-02-27" viram "20260227" e a máscara os lê como DD/MM/AAAA, produzindo "20/26/0227".

**Regra que fica:** se o formato de data importa pra IDENTIDADE VISUAL do produto (não só pra
funcionar), não confie em `<input type="date">` pra controlar isso — ele está fora do seu
controle. Ou aceita o formato que o navegador do usuário decidir, ou implementa mascaramento
próprio sobre o mesmo contrato ISO, com um caminho de aceitação pra valor ISO completo (pra não
quebrar testes/integrações que já falam ISO).
