## Regex que "reconhece" um id quando existe função que o MONTA: duas aproximações erradas antes do conjunto {#regex-que-aproxima-conjunto-canonico-de-ids}

`tags: regex, fonte canonica, id de slot, reconhecedor, falso positivo, ancora, Set, divergencia silenciosa, painel de admin, review cross-provider`

**Sintoma:** um reconhecedor (`ehX(id)`) e um construtor (`idDeX(...)`) descrevem o mesmo conjunto por caminhos diferentes. Enquanto os dados são poucos, concordam. A divergência aparece quando alguém acrescenta um caso — e o efeito é **o oposto do que a função existe para fazer**.

**Caso medido em 2026-08-19.** Um painel ganhou "vagas" (endereços de foto que podem estar vazios). O construtor era a fonte:

```ts
const idDaVaga = (svc: string, n: number) => `service.${svc}.extraPhoto${n}`;
```

O reconhecedor foi escrito por regex, e **errou duas vezes seguidas**:

| Tentativa | Aceitava indevidamente | Efeito |
|---|---|---|
| `/\.extraPhoto\d+$/` | `client.extraPhoto1` | slot comum vira "vaga" |
| `/^service\.[^.]+\.extraPhoto\d+$/` | serviço fora da lista; `extraPhoto99` | idem |

🔑 **Por que o efeito é pior do que parece:** o campo servia para o painel **não pedir bytes** de uma vaga vazia. Um falso positivo faz o painel **esconder a foto de um slot comum** — ou seja, a aproximação não "deixa passar" um caso raro: ela produz exatamente o defeito que a função veio consertar, num slot que funcionava.

**Solução — derive do construtor, não descreva o formato dele:**

```ts
const IDS_DE_VAGA = new Set(
  SERVICOS_COM_VAGA.flatMap((svc) =>
    Array.from({ length: VAGAS_POR_GALERIA }, (_, i) => idDaVaga(svc, i + 1)),
  ),
);
export const ehVaga = (id: string) => IDS_DE_VAGA.has(id);
```

Agora o conjunto **é** a definição: acrescentar um serviço ou mudar o teto atualiza os dois lados de uma vez, e não há formato para divergir.

**Teste que fecha (os três casos que as regex deixaram passar):**

```ts
for (const svc of SERVICOS) for (let n = 1; n <= TETO; n++)
  expect(ehVaga(idDaVaga(svc, n))).toBe(true);          // casa tudo que o construtor monta
expect(ehVaga('client.extraPhoto1')).toBe(false);        // sufixo parecido
expect(ehVaga('service.fora-da-lista.extraPhoto1')).toBe(false);
expect(ehVaga(`service.ppf.extraPhoto${TETO + 1}`)).toBe(false);
```

⚠️ **A regra prática:** se existe uma função que **constrói** o identificador, o reconhecedor deve derivar dela — `Set` de ids, ou comparação com o resultado do construtor. Regex ali é uma **segunda definição** do mesmo conjunto, escrita em outra linguagem, que ninguém sincroniza. Vale igual para nome de chave de cache, de arquivo, de fila e de evento.

Relacionado: [regra-escrita-em-n-lugares-e-enforcada-em-nenhum](regra-escrita-em-n-lugares-e-enforcada-em-nenhum.md) · [alargar-matcher-de-guarda-troca-miss-por-alvo-errado](alargar-matcher-de-guarda-troca-miss-por-alvo-errado.md)
