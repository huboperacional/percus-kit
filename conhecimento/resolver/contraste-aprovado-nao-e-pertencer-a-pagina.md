## Contraste aprovado não é o mesmo que pertencer à página {#contraste-aprovado-nao-e-pertencer-a-pagina}

`tags: contraste, WCAG, AA, 4.5:1, evidência visual, screenshot, tema claro, dark mode, superfície, bg-dark, alfa, remapeamento de tema, guarda de cor, medir versus olhar`

**Contexto:** cartões de destaque num hero herdados de um layout **escuro**, numa página que passou a ser **clara**. Uma leva anterior já tinha consertado a tinta deles (regra de tema que devolve a rampa clara sobre superfície escura), e a medição confirmava: 13,73:1 nos rótulos, 5,87:1 nos sub-rótulos — os dois acima do mínimo AA.

**Sintoma:** o operador reporta "ilegíveis" com print. A guarda de contraste passa. Os dois estão certos.

**Causa raiz:** a medição responde *"dá para ler?"*. O olho responde *"isto pertence a esta página?"*. Os cartões continuavam `bg-dark-800/60` — navy translúcido — porque esse utilitário com alfa **não está na lista de remapeamento do tema claro**, e o fundo em volta virou um gradiente claro. Três lajes cinza-azuladas boiando. Legível e errado.

**Como distinguir os dois problemas antes de consertar o errado:**

- **Contraste quebrado** → o número reprova. Conserto é de **tinta** (token de cor do texto).
- **Superfície fora do tema** → o número aprova e a foto destoa. Conserto é de **fundo**: a peça precisa virar superfície do tema da página, não ganhar mais uma exceção de tinta.

O sinal de que você está no segundo caso: a peça carrega uma marca de "isto fica escuro nos dois temas" (uma classe própria, uma exceção declarada) **e** a página em volta deixou de ser escura. A exceção sobreviveu à mudança de contexto.

**Fix:** troque a superfície pelo idioma claro que a própria página já usa em outra seção (`bg-white` + borda suave + tinta escura), e **remova a marca de exceção** — ela existe para painel que fica escuro nos dois temas, e este deixou de ser um. Mantenha a guarda de contraste apontando para um `data-testid`, não para a classe que sumiu: guarda amarrada à implementação para de medir no dia da troca.

**Regra geral:** medição e foto respondem perguntas diferentes, e nenhuma das duas dispensa a outra. Guarda numérica sem screenshot deixa passar "legível mas de outro produto"; screenshot sem guarda numérica volta a depender de alguém olhar. **Rode as duas, e quando discordarem, a foto é quem está fazendo a pergunta certa.**

**Ref:** Empresa Milionária, 2026-08-20, hero de `/afiliados`. Decisão que fechou o caso: página pública é **sempre clara** — não acompanha o tema do app.
