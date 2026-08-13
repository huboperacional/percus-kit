---
name: panelkit-design
description: Use this skill to generate well-branded interfaces and assets for PanelKit, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for protoyping.
user-invocable: true
---

Leia o `readme.md` desta pasta primeiro — o bloco de status no topo vale mais que o resto.

**No Percus o PanelKit é referência visual, não fonte de código.** Ele responde *como deve
parecer*: raio de canto, densidade, hierarquia de tipo, espaçamento, foco/hover/erro. Quem
responde *como se escreve* é o stack do canon — Tailwind 4 + shadcn/ui, copiar-pro-repo
(`02_INFRA_E_STACK_PERCUS.md:629`).

- **Rascunho descartável** (mock, slide, protótipo pra olhar): pode gerar HTML estático usando
  os tokens e os `.jsx` daqui à vontade.
- **Código de produção:** leia os componentes daqui como **especificação** e escreva em Tailwind
  no projeto destino. **Não copie os `.jsx`** — eles usam objeto de estilo inline, vetado por
  `02_INFRA_E_STACK_PERCUS.md:642`. Antes de desenhar do zero, veja se `templates/` do kit já
  cobre a tela (ex.: `templates/permissoes-por-perfil/`, `templates/login-ui/`).

Se o usuário invocar esta skill sem mais contexto, pergunte o que ele quer construir e atue como
designer especialista — mas entregue produção no stack do canon, não no formato desta pasta.
