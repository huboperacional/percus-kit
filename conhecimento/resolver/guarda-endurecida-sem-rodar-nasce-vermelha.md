## Guarda endurecida sem ser rodada nasce vermelha — e fica vermelha até alguém tropeçar nela {#guarda-endurecida-sem-rodar-nasce-vermelha}

`tags: guarda, teste de política, varredura, regex, alargar matcher, review cross-provider, suíte lenta, enforcement, identidade de produto, fork, CI, falso silêncio`

**Contexto:** um review pede para **alargar** uma guarda que varre o repositório — "o padrão está
estreito demais, ele não pega a grafia com acento / com hífen / o nome em prosa". A sugestão é
certa, o alargamento entra, e o commit passa porque quem alargou rodou só o arquivo da task.

**O que acontece:** o padrão novo casa coisas que **já estavam no repositório antes da guarda
existir**. A guarda entra vermelha e ninguém vê, porque a suíte inteira só roda no fechamento de
fase. Ela é descoberta semanas depois, por acaso, enquanto se investiga outra coisa.

**Medido num caso real:** guarda de identidade de produto alargada em 14/08 por sugestão de review;
as linhas que ela passou a casar entraram em 11/08, no commit do **fork** — três dias antes. Ela
nunca passou desde que foi endurecida. Quando finalmente rodou, acusou **15** ocorrências em dois
projetos, nenhuma introduzida pelo trabalho que a fez rodar.

**Por que é pior que não ter guarda:** guarda vermelha treina quem lê a saída a ignorar a saída.
É o mesmo mecanismo de [[alarme-falso-mata-o-alarme]], só que do lado de dentro — e some no meio
de "a suíte está lenta, roda depois".

**O que fazer ao alargar QUALQUER matcher de varredura** (regex, glob, lista de extensões):

1. **Rode a guarda alargada antes de commitar o alargamento.** Não a suíte inteira — só ela. Se
   ela varre o repositório, o custo é de segundos a um minuto, não de meia hora.
2. **Conte os ofensores e decida na hora**: consertar todos, ou entrar com uma exceção **explícita
   e datada**. O que não vale é commitar vermelho "para consertar depois".
3. **Se o alargamento veio de review, o review não fecha antes de a guarda estar verde.** "Aplicado
   conforme sugerido" não é o mesmo que "passa".

**Ao CONSERTAR os ofensores, obedeça à política da guarda em vez de afrouxá-la.** O caso típico é
uma guarda que **não isenta comentário nem docstring**, e cujo motivo está escrito nela — o nome
errado numa docstring é o que faz a próxima pessoa copiar o valor errado para o código. A tentação
é adicionar "ignore comentários" e ver tudo verde; isso remove a guarda e mantém a aparência dela.
Procure a convenção que o repositório **já usa** para dizer a mesma coisa (uma sigla, um apelido) e
alinhe os pontos inconsistentes com ela. Costuma haver: no caso medido, a abreviação já aparecia em
arquivos vizinhos, e os 15 ofensores eram justamente os que não a seguiam.

**O buraco de processo que fica, e que é decisão de enforcement:** enquanto a guarda só rodar no
fechamento de fase, a próxima ocorrência entra e fica. Meça o custo dela isolada e registre o
número — é isso que transforma "deveríamos rodar mais" numa decisão em vez de uma intenção.

**Onde apareceu:** Empresa Milionária, 2026-08-20, guardas `test_nenhum_arquivo_de_execucao_
referencia_o_produto_de_origem` e `test_o_frontend_nao_aponta_para_o_dominio_do_produto_de_origem`.
