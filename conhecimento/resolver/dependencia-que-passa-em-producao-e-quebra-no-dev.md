## Dependência que passa em produção e quebra no dev — o inverso do "SQLite mente", e ninguém testa nessa direção {#dependencia-que-passa-em-producao-e-quebra-no-dev}

`tags: dependencia, ambiente, zoneinfo, tzdata, fuso horario, windows, container, licenca, cross-plataforma, R23`

**Sintoma:** o código funciona no container Linux e levanta exceção na máquina de
desenvolvimento — ou na suíte local, que roda lá. A falha parece "problema da minha máquina" e
tende a ser contornada com um `try/except` ou um `skipif`, em vez de corrigida.

**Causa raiz:** a biblioteca depende de um recurso **do sistema operacional**, não do pacote. O
caso canônico é `zoneinfo`: ele lê a base de fusos **do SO**, que existe no Linux e **não existe
no Windows**. `ZoneInfo("America/Sao_Paulo")` levanta `ZoneInfoNotFoundError` no dev e resolve no
container. A correção é declarar `tzdata` (Apache-2.0) como dependência — ele empacota a base IANA
e torna o comportamento igual nos dois lados.

**Por que é mais perigoso que o inverso:** todo mundo já desconfia de "verde no dev, vermelho em
produção" — é o `SQLite mente` de sempre, e existe disciplina contra ele. Esta falha vai na
direção **oposta**, e por isso escapa: quem roda a suíte local vê vermelho, atribui ao ambiente
próprio e desabilita o teste; quem roda em CI Linux vê verde e conclui que está tudo certo. O
defeito só aparece quando alguém precisa depurar localmente — normalmente no pior momento.

**Como detectar antes de adotar:** pergunte *"este pacote é puro na linguagem, ou ele chama
biblioteca nativa / lê arquivo do SO?"*. Sinais: dependência de `.so`/`.dll`, instruções de
instalação com `apt-get`/`brew` no README, ou leitura de caminho do sistema (`/usr/share/...`).

Exemplos medidos em 2026-08-31, escolhendo gerador de PDF:

- `weasyprint` — BSD no pacote Python, mas puxa **GTK/Pango/Cairo** nativos. Rejeitado por
  ambiente, **não** por licença.
- `reportlab` e `openpyxl` — **puros em Python**, zero dependência nativa. Adotados.

**Regra que sai disso:** "puro na linguagem" é critério de seleção de dependência **ao lado da
licença**, não depois dela. E vale registrar a rejeição por ambiente no ADR junto com as de
licença — senão a próxima sessão reavalia o mesmo pacote, vê a licença limpa e o adota.

⚠️ **Ao conferir a licença, abra o arquivo — e olhe se há mais de um.** No mesmo dia, `tzdata`
trouxe **dois** arquivos de licença, um deles na subpasta `licenses/`; conferir só o da raiz seria
conferir metade. E `reportlab` tem uma **edição comercial** além da OSS: a checagem incluiu o
`METADATA` para confirmar a identidade do mantenedor, porque licença certa em pacote errado não
vale nada.

A conferência de licença tem verbete próprio no ADR-0004 do projeto que a mediu; aqui o ponto é o EIXO ambiente, que costuma ser esquecido ao lado dele.
