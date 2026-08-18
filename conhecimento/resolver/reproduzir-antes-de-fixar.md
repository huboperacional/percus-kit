## Fix aplicado não funciona / hipótese de root cause estava errada {#reproduzir-antes-de-fixar}

`tags: debug, root cause, hipotese errada, fix nao funciona, curl, argv, mangling, reproduzir, tooling`

**Contexto:** apliquei um fix baseado numa hipótese plausível e o problema continuou — a causa real era
outra. (Incidente v6.8.4: hipótese inicial "AGENTS.md em CP1252" estava parcialmente certa, mas o root
cause real — `curl` argv mangling — só apareceu rodando o script local de tooling.)

**Causa raiz:** declarar fix sem **reproduzir** o problema com a ferramenta real primeiro.

**Solução:** antes de declarar qualquer fix de tooling, **rode o script/comando que reproduz** o
problema localmente e confirme a causa observada — não a inferida. Reproduzir > teorizar.

**Ref:** memória `feedback_reproduce_tooling_before_fix`.
