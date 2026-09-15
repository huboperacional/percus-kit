## Adoção de diretiva "por mescla" deixa a regra antiga ao lado da nova — e o CLAUDE.md passa a dar duas ordens {#adocao-por-mescla-deixa-a-regra-antiga-ao-lado-da-nova}

`tags: REORGANIZAR_PROJETO, alinhamento, CLAUDE.md, AGENTS.md, mesclar, diretiva, trilhos, contradicao, subagente, criterio de aceite, grep, cross-repo`

**Sintoma:** depois de uma rodada de alinhamento ao canon, o `CLAUDE.md` do projeto tem o parágrafo novo
("Trilhos P e M — este arquivo tem precedência sobre as skills upstream") **e**, algumas linhas acima,
a regra que ele substitui ("Execução de plano = subagent-driven por DEFAULT ... 2+ tasks"). O relatório
do agente diz "adotado".

**Reprodução real** (2026-09-15, canon 6.58.0): dois subagentes alinharam 14 projetos seguindo
`comandos/REORGANIZAR_PROJETO.md` ("MESCLE, não sobrescreva"). A conferência por grep achou a regra antiga
em 7 projetos (Plexco Tasks, WhatsApp-API-Oficial, auth-service, Painel, Plexco Coach, huboperacional-site,
tiatendo) e a linha antiga do roteador ("Spec ou plano acabou de fechar ... automático") no tiatendo.
Achado junto: o caminho `D:\Claud Automations\_Novo_Projeto` (nome antigo do kit) em 6 projetos.

**Causa raiz:** "mesclar" foi lido como "acrescentar sem apagar". O brief listava o que **entra**, não o
que **sai**; o agente não tem como saber que um parágrafo com outro título é a versão velha da mesma regra.

**Conserto:** uma onda de correção com **critério de aceite por grep zerado**, por projeto:
`grep -c -i "2+ tasks\|subagent-driven por default" CLAUDE.md` = 0,
`grep "acabou de fechar" CLAUDE.md | grep -vc "trilho G"` = 0, `grep -c "_Novo_Projeto"` = 0 — e o
controlador roda os mesmos greps depois, sem confiar no relatório.

⚠️ **Armadilha da própria conferência:** grep pela frase "automático" casou também a linha **nova** do
roteador ("no G, automático, não pergunte"). O padrão de aceite tem de excluir o texto novo
(`grep -v "trilho G"`), senão a medição acusa falso resíduo.

📌 **O que fecha a classe:** toda diretiva que **substitui** outra vem com a lista do que **sai** e o grep
que prova que saiu. Brief de alinhamento sem critério de remoção produz arquivo com duas ordens.

**Relacionados:** [mesclar-so-imediatamente-antes-do-commit](mesclar-so-imediatamente-antes-do-commit.md),
[git-bash-converte-argumento-com-barra-e-a-contagem-sai-vazia](git-bash-converte-argumento-com-barra-e-a-contagem-sai-vazia.md).
