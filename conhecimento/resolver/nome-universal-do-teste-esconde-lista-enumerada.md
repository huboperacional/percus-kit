## Nome universal do teste esconde uma lista enumerada, e só é verdadeiro até a próxima coluna {#nome-universal-do-teste-esconde-lista-enumerada}

`tags: teste, nome do teste, lista enumerada, cobertura, falso verde, anonimizacao, LGPD, varredura, sabotagem, guarda que nao guarda, coluna nova, promessa maior que a implementacao`

**Sintoma:** um teste com nome absoluto — `nenhum_valor_original_sobrevive_em_lugar_nenhum`,
`nada_vaza_para_a_vizinha`, `todos_os_campos_sao_anonimizados` — está verde, e o defeito que ele
promete impedir está no banco. Ninguém desconfia dele **porque o nome é a própria asserção que
você queria**: quem lê a lista de testes marca o requisito como coberto e vai embora.

**Causa raiz:** o nome é universal e o corpo é uma **lista literal**. Ele varre as colunas que
existiam no dia em que foi escrito:

```python
# o nome promete "nenhum valor original"; o corpo promete tres colunas
for pessoa in pessoas:
    assert original not in (pessoa.nome, pessoa.apelido, pessoa.documento)
```

A coluna que entra depois — aqui `pessoas.whatsapp` — não está na tupla, então não é varrida, e o
teste continua verde com o dado original vivo. Não há erro, não há aviso: a lista simplesmente não
sabe que ficou incompleta. O mesmo vale para a **lista de originais**: varrer a coluna nova sem
acrescentar o valor dela ao conjunto procurado dá o mesmo verde.

**Como foi pego, e por que só assim:** pela **sabotagem**. Desliguei de propósito a passada que
anula o telefone, esperando que este teste caísse — e ele **passou**, com os dois números
intactos no banco. Foi o único sinal. A suíte inteira verde, o nome do teste dizendo "em lugar
nenhum", e o lugar estava ali. Ver [[sabotagem-que-nao-aplica-reporta-verde]] para a assimetria:
verde depois de sabotar obriga a medir.

**Solução:**

- **Enumere pelo METADADO, não à mão.** Em SQLAlchemy, `__table__.columns` dá a lista viva; a
  coluna nova entra sozinha e o teste passa a exigi-la sem ninguém lembrar:

  ```python
  colunas = [c.name for c in Pessoa.__table__.columns if isinstance(c.type, sa.String)]
  ```

- **Se a enumeração à mão for inevitável** (nem toda coluna deve ser anonimizada — CNPJ e razão
  social são registro fiscal e FICAM), então o nome do teste tem de **dizer quantas**:
  `nenhum_dos_quatro_valores_originais_sobrevive`. Nome que promete o universo obriga o corpo a
  varrer o universo; nome que promete quatro é conferível por leitura.
- **A guarda de escopo é o par disso:** uma asserção `set(medidos) <= set(ESCOPO)` obriga quem
  acrescenta uma passada a declará-la. Ela pega a passada nova que ninguém contou — não pega a
  coluna nova dentro de uma passada que já existe. São dois buracos diferentes.

**🔑 Como reconhecer antes de o defeito chegar:** leia o nome do teste e o corpo em sequência e
pergunte *"o que precisaria mudar no sistema para o nome ficar falso sem o corpo ficar
vermelho?"*. Se a resposta for "acrescentar uma coluna", "acrescentar um caso ao enum",
"acrescentar um provedor" — e isso for coisa que o produto faz toda semana — o teste tem prazo de
validade e ninguém marcou a data.

**Ref:** 2026-09-10, Empresa Milionária — fatia 4 Task 13 (RF-168.11), commit `ec184a6`. O teste
existia desde a Task 8 do FR-043 e era honesto quando nasceu: naquele dia `pessoas` tinha três
colunas de dado pessoal. Irmão de [[categoria-nova-esquecida-em-lista-de-enumeracao]] e de
[[assert-sobre-conteiner-maior-que-o-alvo-passa-vazio]] — a família toda é *a promessa é maior que a
medição*.
