## Guard que IMPRIME uma checagem mas não mede nada {#guard-que-imprime-mas-nao-mede}

`tags: guard, portao de deploy, gate, migration, prova negativa, falso verde, PERFORM, grep regex, BRE, acento, teste que contradiz o desenho, verificacao, R23`

**Contexto:** numa sessão de 2026-08-21 no Micro Investors, **três** guards escritos por mim
imprimiram linha de checagem, passaram, e não verificavam nada. Nenhum falhou; todos deram "OK".
O padrão é o mesmo nos três, e é o mais perigoso da família: um guard ausente ninguém confunde com
segurança, mas um guard que imprime `(espera >=1)` e passa **é lido como prova**.

**Os três, porque a variedade é o ponto — cada um errou por um mecanismo diferente:**

1. **SQL que não pode levantar.** A "prova positiva" de uma migration era
   `PERFORM 1 FROM tabela WHERE status = 'sending'` dentro de um bloco com
   `EXCEPTION WHEN OTHERS THEN v_ok := false`. Um `SELECT` com `WHERE` **não levanta** seja qual
   for a constraint — a linha `v_ok := true` rodava incondicionalmente. Se o `ADD CONSTRAINT`
   tivesse falhado, a migration passaria com um "OK" no log.

2. **Padrão que nunca casa.** Um portão de deploy contava `mensagem(ns) sairao agora` no bundle
   servido. O bundle tem **"sairão"**, acentuado. O contorno foi pior que o defeito: marquei
   `esperado=0` para a linha parar de reprovar, e ela virou uma checagem que **imprime como
   checagem e não checa**. (Irmão disso no mesmo dia: `grep_count` usava grep **regex**, e o `[0]`
   de um padrão virou classe de caractere — esse ao menos reprovou um deploy CORRETO, que é o
   lado seguro do erro.)

3. **Teste que contradiz o desenho.** Um teste de PII exigia a **ausência** dos 4 últimos dígitos
   do telefone na mensagem de exceção — dígitos que a máscara mantém **de propósito**, para o
   operador saber qual destinatário falhou. O teste não verificava a máscara: disputava com ela.

**Como pegar, e é sempre a mesma pergunta:** *o que aconteceria se o código estivesse errado?*
Se você não consegue responder com um caso concreto, o guard não mede.

**Procedimento que funcionou (3 aplicações no mesmo dia):**

- **Rode o guard contra uma versão MUTILADA do alvo.** Não basta o caso bom passar; o caso ruim
  precisa reprovar. Em teste, extraia a asserção para uma função e chame-a com o corpo estragado
  dentro de `pytest.raises(AssertionError)` — asserção que só roda sobre o dado bom prova que o
  dado bom existe, não que a guarda funciona.
- **Conte o ERRADO, não o certo.** "2 raises mascarados" não prova nada se existir um terceiro sem
  máscara. Contar `raise` **sem** máscara e exigir zero fecha a classe; contar os mascarados fecha
  a instância. Foi assim que um vazamento de PII sobreviveu à primeira correção.
- **Verifique o formato REAL do alvo antes de escrever o padrão.** Acento, espaço depois de `:`,
  metacaractere de regex. Um `grep -oF` literal contra o artefato responde em um comando.
- **Migration aplicada é imutável.** Quando o guard defeituoso já rodou, não reescreva o arquivo:
  ele deixaria de descrever o que realmente aconteceu. Anote o defeito nele e ponha a verificação
  de verdade numa migration nova. Para constraint, o jeito que distingue os três estados que
  importam — CHECK certo, CHECK antigo, CHECK **ausente** — é ler `pg_get_constraintdef()` no
  catálogo, não tentar um INSERT que a FK pode barrar antes do CHECK.

**Sinal de alerta em revisão:** qualquer linha de portão cujo valor esperado seja `0` **para o caso
positivo**, qualquer `EXCEPTION WHEN OTHERS` em volta de operação que não levanta, e qualquer teste
cujo nome diga "não contém X" quando X é comportamento desejado.

Ver também: [alargar-matcher-de-guarda-troca-miss-por-alvo-errado](alargar-matcher-de-guarda-troca-miss-por-alvo-errado.md).
