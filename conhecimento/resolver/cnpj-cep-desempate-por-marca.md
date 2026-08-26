## Casar unidade de franquia com CNPJ só por CEP é ambíguo em ~85% dos casos — desempate por nome da marca resolve a maioria {#cnpj-cep-desempate-por-marca}

`tags: cnpj, receita federal, cep, dados abertos, socio, qso, dono, franquia, desambiguacao, matching, brasilapi, opencnpj, dados publicos rf`

**Contexto:** enriquecer ~1.500 clínicas odontológicas coletadas dos sites das redes com o
sócio-administrador real (não o responsável técnico, que é outra pessoa), usando os dados abertos de
CNPJ da Receita Federal (`arquivos.receitafederal.gov.br`, WebDAV público, token de share
`YggdBLfdninEJX9`, ~7,7GB/mês em 30 zips: Empresas/Estabelecimentos/Sócios × 10 partes + tabelas de
referência Municípios/Qualificações).

**O problema:** casar por CEP exato (`Estabelecimentos.cep` == CEP da unidade coletada) parecia óbvio,
mas devolveu **>1 candidato em 85% dos casos com CEP** (943 unidades, 840 ambíguas na 1ª medição). CEP
no Brasil frequentemente cobre uma rua ou quarteirão inteiro, não um número só — então "mesmo CEP" não
significa "mesmo prédio", e uma clínica odontológica não filiada a rede nenhuma pode dividir o CEP com
a unidade franqueada.

**O que resolveu a maioria:** dentre os candidatos do mesmo CEP, filtrar por substring do nome da marca
(`"ODONTOCOMPANY"` em `nome_fantasia` ou `razao_social`) — se **exatamente um** candidato bate, é o
match certo com confiança média. Subiu o casamento de 10% pra ~55% dos registros com CEP. Motivo:
franquias de rede grande frequentemente registram a unidade com o nome da marca embutido no CNPJ
(`"ODONTOCOMPANY - UNIDADE GALEAZZI"`), mesmo quando o "dono" real é uma pessoa física diferente da
franqueadora.

**O que NÃO resolve, e é limitação real (não bug):** o restante continua ambíguo porque muitas
franquias são registradas com a razão social só do proprietário, sem citar a marca em lugar nenhum do
CNPJ — não tem sinal textual pra desambiguar sem outro dado (ex.: comparar `logradouro` texto a texto,
não tentado ainda por custo/benefício).

**Achado lateral que muda a estratégia de UF:** clínica raspada de site que só publica cidade/bairro
sem UF explícita (comum: título mostra bairro, não cidade — `"DIRCEU II"` em vez de `"Teresina -
Dirceu"`) tem a UF resgatada de graça pelo PRÓPRIO casamento CNPJ, porque `Estabelecimentos.uf` é
campo direto da Receita (não precisa nem de tabela de município). **Não vale inventar uma tabela
CEP→UF de memória** pra esse fallback — as faixas têm exceções reais (RO/RR/AC dentro da faixa "geral"
de outro estado) e um erro aqui vaza SP/RJ pra dentro de uma lista que deveria excluí-los; o
casamento por CNPJ já resolve isso com dado oficial, sem risco.

**Fonte gratuita alternativa pro `dono` isolado** (sem baixar 7,7GB): `BrasilAPI`
(`brasilapi.com.br/api/cnpj/v1/<cnpj>`) devolve o QSA de um CNPJ específico já conhecido, sem chave.
Só serve quando já se tem o CNPJ (não ajuda a DESCOBRIR o CNPJ pelo nome/CEP — pra isso precisa da
base bruta).

Ver também [[spa-hidratacao-embute-payload-completo-sem-api]] pra como as unidades foram coletadas
antes deste casamento.
