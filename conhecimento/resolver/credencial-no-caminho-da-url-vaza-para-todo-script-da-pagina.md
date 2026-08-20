## Credencial no caminho da URL vaza para todo script de terceiro da página {#credencial-no-caminho-da-url-vaza-para-todo-script-da-pagina}

`tags: segurança, magic-link, token, analytics, gtag, GA4, script de terceiro, url, vazamento, privacidade, LGPD`

**Sintoma:** você entrega um magic link — aprovação, confirmação, download, convite — com o token
num segmento do caminho (`/recurso/por-link/{token}`). Tudo passa: o token é guardado em hash, tem
expiração, tem escopo estreito, e há teste para cada uma dessas guardas. Nenhum teste falha, e o
vazamento já está lá.

**A armadilha:** o `layout` raiz da aplicação carrega rastreadores em **todas** as páginas — GA4,
Meta Pixel, Hotjar, script de afiliado, o que for. Todos leem a URL:

- o `gtag('config', ID)` manda `page_location` com a **URL inteira** no evento `page_view`;
- script de terceiro (`<script src="https://outro-dominio/...">`) lê `location.href` **por conta
  própria**, quando quiser, e você não controla o código.

Resultado: a credencial vai parar no painel de analytics de dois fornecedores. Quem tiver acesso a
qualquer um dos relatórios abre a URL e **usa o token** — e, se ele aprova dinheiro, a trilha de
auditoria registra a ação no nome da vítima. Medido num produto real em 2026-08-19: token de
aprovação de contas a pagar, indo para o Google Analytics e para o script de um parceiro.

Três razões de isso escapar de toda revisão:

1. o vazamento não está no módulo do token — está no `layout` raiz, que ninguém abre ao revisar uma
   feature de backend;
2. `grep` pelo nome do token não acha nada, porque o script de terceiro nunca cita o token: ele cita
   `location.href`;
3. os testes do magic link testam **expiração e escopo**, que estão certos.

**O que fazer:** o token **não pode carregar em página que sirva script que você não escreveu**.

1. **Exclua a rota dos rastreadores**, num componente cliente que olha o caminho:

```tsx
'use client'
const ROTAS_SEM_RASTREIO = [/^\/recurso\/por-link\//]

export function Rastreadores() {
  const caminho = usePathname()
  // Na dúvida (caminho nulo no 1º render), NÃO carrega: falhar para o lado de não
  // rastrear custa uma visita no relatório; falhar para o outro lado vaza credencial.
  if (caminho === null || ROTAS_SEM_RASTREIO.some((r) => r.test(caminho))) return null
  return <>{/* gtag, pixel, script de afiliado */}</>
}
```

2. **Teste sobre a REQUISIÇÃO DE REDE, não sobre a tag no HTML** — tag ausente com o script chegando
   por outro caminho passa despercebida, e é a rede que vaza:

```ts
const pedidos: string[] = []
page.on('request', (r) => { if (HOSTS.some(h => r.url().includes(h))) pedidos.push(r.url()) })
await page.goto(CAMINHO_COM_TOKEN)
expect(pedidos).toEqual([])
```

3. **Escreva também o controle positivo** — sem ele, o teste acima passa se os rastreadores sumirem
   do site inteiro, que é o modo clássico de "verde por ausência de mecanismo":

```ts
await page.goto('/')
expect(pedidos.length).toBeGreaterThan(0)   // a home CONTINUA rastreando
```

**O que NÃO resolve:**

- **Sanear a URL para o rastreador** (`gtag('set', {page_location: redigido})`) só funciona nos
  scripts que você configura. Contra código de terceiro que lê `location.href` sozinho, não há
  saneamento — só ausência.
- **Mover o token para o fragmento** (`#token=`) tira ele do `Referer` e do log do servidor, o que é
  bom, mas o fragmento continua legível por **qualquer JS da página**, inclusive o de terceiro.
- **Encurtar a expiração.** Reduz a janela, não fecha o buraco: o rastreador dispara no mesmo
  instante em que a vítima abre.

**Relacionado:** [[teste-que-reimplementa-a-expressao-nao-prova-nada]] — a mesma disciplina de exigir
controle positivo antes de acreditar num verde.
