## Mover uma tela/módulo para fora do raio de um gate resolve o que ele reclamava e apaga a proteção dele no mesmo commit {#aninhar-para-sair-de-um-gate-tira-a-protecao-dele}

`tags: gate, teste de cobertura, tela orfa, refactor, mover arquivo, aninhar rota, protecao silenciosa, revisao de branch, R23`

**Sintoma:** um refactor move um arquivo/rota/módulo de lugar **de propósito**, para que um gate
automático pare de reclamar dele. O gate fica verde, a suíte inteira fica verde, e ninguém percebe
que a garantia que aquele gate dava também acabou de sumir. O defeito só aparece meses depois, na
forma que o gate existia para impedir.

**Caso medido (2026-08-28, Paid Media Automation):** a tela de Criativos deixou de ter item de menu e
virou aba de outra tela. O gate anti-tela-órfã (`nav-cobertura-de-telas.test.ts`) enumera **só as
pastas diretamente dentro de `(shell)/`**, então aninhar a pasta em `campaigns/creatives/` a tirava da
varredura — que era exatamente o efeito desejado, já que ela não teria mais item de menu.

O que quase passou: com a tela fora do raio do gate, e **sem nenhum teste que renderizasse a página
que monta a aba** (1.160 linhas, sem suíte própria), **apagar a única linha
`<CampaignsSubTabs clientId={clientId} />` deixaria a suíte 100% verde e a tela alcançável só por URL
digitada** — que é precisamente a classe de defeito que aquele gate nasceu para travar. Nenhuma das
8 revisões por task viu. Só a **revisão final de branch**, olhando a branch como unidade, viu.

**Causa raiz:** um gate protege um **caminho**, não um arquivo. Tirar o arquivo do caminho satisfaz
o gate sem satisfazer a intenção dele. E a satisfação é silenciosa: verde não distingue "está
coberto" de "não é mais olhado".

**Como resolver:** quando uma mudança fizer algo **sair do raio de um gate**, o *mesmo commit* repõe
a guarda no caminho novo. No caso, um teste que lê o **texto-fonte** da página e exige a montagem:

```ts
const src = readFileSync(resolve(__dirname, "../page.tsx"), "utf8");
expect(src).toContain("<CampaignsSubTabs");
```

⚠️ E o teste só vale **visto REPROVANDO**: remova a linha de verdade, veja falhar, restaure. Aqui
isso foi feito duas vezes — pelo implementador e, de novo, pelo re-revisor por conta própria.

**Limite conhecido desta guarda:** `toContain` casa também se a montagem virar **comentário JSX**
(`{/* <CampaignsSubTabs …> */}`) — medido ao vivo. Cobre o caso real (apagar a linha), não cobre
comentar. Apertar é barato: normalizar removendo comentários (`/\{\/\*[\s\S]*?\*\/\}/g`) antes do
`toContain`.

**Pergunta que evita o caso:** *"o que este gate estava me garantindo, e quem garante isso depois da
mudança?"* — feita antes do refactor, não depois.

Relacionado: [gate que nunca foi visto reprovando aprova tudo](gate-que-nunca-foi-visto-reprovando-aprova-tudo.md).
