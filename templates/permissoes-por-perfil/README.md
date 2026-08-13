# Permissões por perfil — template copy-paste

Padrão Percus para a tela de **seletor de acessos**: escolhe-se um perfil de usuário e
liga/desliga o que ele pode fazer, em grupos colapsáveis.

Referência visual: `images/seletor de acessos 1.png` e `2.png` (tela "Invite members" da
Cloudflare). Dali veio a **arquitetura de informação** — grupos colapsáveis, contador `N/N`,
interruptor-mestre por grupo, busca. A **pele** segue o PanelKit (`Design/readme.md`):
painel branco de canto arredondado, controles pill, sem régua entre linhas.

## Como usar

1. Copie `components/` e `lib/` para o projeto (é copy-paste, não pacote).
2. O projeto precisa ter `@/lib/utils` com o `cn` do shadcn e `lucide-react` instalado.
3. Alimente com os perfis e os grupos:

```tsx
import { PermissoesPorPerfil } from "@/components/permissoes-por-perfil";

<PermissoesPorPerfil
  perfis={[
    { id: "admin",    nome: "Administrador", permissoes: ["usuarios.ler", "usuarios.criar"] },
    { id: "vendedor", nome: "Vendedor",      permissoes: ["financeiro.ler"] },
  ]}
  grupos={[
    {
      id: "usuarios",
      titulo: "Usuários",
      permissoes: [
        { id: "usuarios.ler",   nome: "Ver usuários",  descricao: "Lista quem tem acesso." },
        { id: "usuarios.criar", nome: "Criar usuário", descricao: "Cria e envia convite." },
      ],
    },
  ]}
  onChange={(perfilId, permissoes) => salvarPermissoes(perfilId, permissoes)}
/>
```

## Contrato

| Prop | O que é |
|---|---|
| `perfis` | Os perfis do projeto. `permissoes` é a lista de ids ligados **naquele** perfil. |
| `grupos` | Os blocos de permissão. Iguais para todos os perfis. |
| `onChange(perfilId, permissoes)` | Dispara a cada clique, com a lista nova inteira. |
| `perfilInicialId` | Opcional. Padrão: o primeiro perfil da lista. |

As permissões são **controladas pelo pai** — o componente não guarda estado de permissão.
Só a seleção de perfil e o texto da busca são internos.

## Decisões fechadas (não são acidentes)

1. **O contador ignora a busca.** `2/3` é sobre o grupo inteiro, sempre. Se contasse só o
   filtrado, o número mudaria a cada tecla e deixaria de significar algo.
2. **Buscar abre o grupo.** Grupos nascem fechados; ao mudar o termo, quem tem resultado abre
   sozinho e quem não tem some da lista. Sem isso o usuário digita e encara caixas fechadas.
   A abertura tem **uma fonte de verdade só** (`abertos`) — a busca abre, mas não trava: o
   clique no cabeçalho continua fechando o grupo mesmo com busca ativa.
3. **O mestre age sobre o grupo inteiro**, mesmo com busca filtrando linhas — é o mesmo
   recorte do contador, então mestre e número nunca discordam.
4. **Sem régua entre linhas.** Separação por espaço; fio sutil só entre grupos
   (`Design/readme.md:37`).
5. **Grupo vazio é "nenhum", não "todos".** Um `every` sobre lista vazia devolveria `true` e
   acenderia o mestre de um grupo sem nada dentro.

## O que ele NÃO faz

Persistência, verificação de quem pode editar, aviso de alteração não salva, e o campo de
e-mails/convite do print original. Tudo isso muda por tela — fica com quem chama.

## Testes

```bash
npm install && npm test
```

35 testes: 23 no modelo puro (`lib/modelo-permissoes.ts`), 12 de comportamento renderizado.
Os stubs em `__tests__/__stubs__/` são infra de teste — **não** fazem parte do copy-paste.

**O que os testes não cobrem:** `@/lib/utils` e `lucide-react` são substituídos por stub via
`resolve.alias`, porque só existem no projeto destino. O `cn` do stub é um `join` simples, sem
`clsx`/`tailwind-merge` — portanto **conflito de classe Tailwind não é testado aqui**. Vale
conferir isso no projeto que consumir o template.
