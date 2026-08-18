## Mensagem de erro de serviço alheio virou "causa raiz" e documentou uma escassez que não existia {#mensagem-de-erro-alheia-promovida-a-diagnostico}

tags: diagnostico, servico de terceiro, http 400, mensagem de erro, causa nao medida, documentacao, pendencia destrutiva, port allocate

**Sintoma.** Um serviço central recusa uma operação com `HTTP 400` e uma mensagem que **explica a
si mesma** ("range exausto: ~349 projetos ocupam as 350 vagas"). A explicação entra na
documentação do consumidor como fato apurado, vira pendência de operador, e o projeto passa a
carregar um `unverified: true` e um plano de saneamento para um problema que nunca existiu.

**Como aparece (Empresa Milionária, 2026-08-11 → 15).** O `/admin/projects/port-allocate` do
Painel de Gestão recusou alocar porta. O `docs/PORTS.md` do projeto registrou o range global
3000–9999 como esgotado, com 349 projetos, e abriu "pendência do operador: realocar slugs
deprecated" — operação que afeta terceiros. Quatro dias depois a devolutiva do Painel **mediu**:
**12 projetos**, ocupando `3000`–`3160`. O range estava praticamente vazio.

**Causa (do lado de lá).** O alocador escolhia `próxima = MAX(port_base) + 20`. Uma linha de
teste esquecida (`test-port-exhaust-sentinel`) estava em `9980`, então `9980 + 20 = 10000 > 9999`
reprovava **qualquer** projeto novo. A linha vazou porque o teste que a criava só limpava depois
do `assert` — qualquer falha deixava o sentinela no banco. A mensagem de erro afirmava uma causa
(escassez) que o código nunca mediu.

**A lição, que não é sobre portas.** Mensagem de erro de serviço alheio é **sintoma**, não
diagnóstico. Ela é escrita por quem supôs por que a operação falharia, e envelhece sem ninguém
notar, porque o autor não vê o consumidor copiando aquilo para dentro da documentação dele. Ao
documentar a falha de um serviço de terceiro:

1. Registre a **mensagem literal** e o que você **observou** — não a causa que ela alega.
2. Se a causa alegada for verificável (contagem, ocupação, quota), **meça** antes de escrever.
   Não dá para medir de fora? Escreva "o serviço alega X; não verificado".
3. **Nunca abra pendência destrutiva** (realocar, apagar, migrar recurso de terceiro) a partir de
   causa não medida. Foi o que quase aconteceu aqui.
4. Avise o dono do serviço. Foi a devolutiva que fechou o caso — e o bug de lá só apareceu porque
   alguém do lado de cá relatou o `400`.

**Contraprova barata.** O fallback determinístico do consumidor (`sha256(slug)` → bloco) escolheu
`5580`, e o registro central **confirmou exatamente essa porta** depois do conserto. Ou seja: a
"escassez" nunca chegou a afetar a decisão — só a documentação.
