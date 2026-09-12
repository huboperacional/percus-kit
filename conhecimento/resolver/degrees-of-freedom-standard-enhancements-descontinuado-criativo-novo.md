## `degrees_of_freedom_spec.standard_enhancements` descontinuado pra criativo NOVO — mas ainda aparece em GET {#degrees-of-freedom-standard-enhancements-descontinuado-criativo-novo}

tags: meta-ads, api, criativo, degrees-of-freedom, breaking-change

**Sintoma.** Você lê um `AdCreative` existente (`GET .../{id}?fields=...,degrees_of_freedom_spec`),
copia o campo inteiro pra criar um criativo novo (`POST /act_<id>/adcreatives`),
e a API recusa com `(#100) Invalid parameter`, `error_subcode: 3858504`,
`error_user_title`: *"O criativo não deve incluir aprimoramentos padrão"*,
`error_user_msg`: *"O recurso de inclusão do campo de aprimoramentos padrão no
criativo foi descontinuado. Defina recursos individuais."*

**Por que morde.** O `GET` continua devolvendo `standard_enhancements` dentro de
`creative_features_spec` pra criativos antigos — a leitura não avisa que o campo
morreu. Só o `POST` de criação recusa. Copiar um objeto que a própria API te
devolveu, sem editar, parece seguro — e não é: campo de LEITURA histórica ≠ campo
aceito em ESCRITA nova.

**O fix.** Antes do `POST`, remova só essa chave — o resto de
`creative_features_spec` (`advantage_plus_creative`, `cv_transformation`,
`image_animation`, etc.) continua sendo aceito normalmente:

```python
dof = json.loads(json.dumps(original["degrees_of_freedom_spec"]))
dof.get("creative_features_spec", {}).pop("standard_enhancements", None)
```

Isso é o mesmo tipo de defeito já catalogado pra `instagram_actor_id`
(depreciado na v22, mata a requisição em vez de voltar nulo) — **a Meta muda
schema de escrita sem sincronizar o schema de leitura**, e o sintoma sempre bate
no primeiro `POST`, nunca num `GET`.

**Caso real** (Paid Media Automation, D4U, 2026-09-10). Recriando um criativo
pra corrigir `url_tags` (ver [[meta-ad-creative-so-nome-status-rotulo-sao-editaveis]]),
copiar `degrees_of_freedom_spec` verbatim do original recusou o `POST` até a
chave ser removida.

🔑 **Achado adicional, mesma sessão (continuação): OMITIR o objeto inteiro
também funciona, e é mais simples que remover só a chave.** Em 2 recriações
seguintes (criativos Advantage+ dinâmicos, `asset_feed_spec` por posicionamento)
o payload do `POST /adcreatives` simplesmente não incluiu `degrees_of_freedom_spec`
nenhum — só `name`, `object_story_spec`, `asset_feed_spec`, `url_tags`. Funcionou
de primeira, sem erro. O `GET` de releitura mostra um `degrees_of_freedom_spec`
completo mesmo assim (dezenas de chaves, muito mais que o original tinha) —
confirma que a Meta SEMPRE devolve a lista cheia com os defaults da conta no
`GET`, independente do que foi mandado no `POST`. Ou seja: **não precisa
diffar/editar o objeto original** pra achar e tirar só `standard_enhancements`
— basta não mandar `degrees_of_freedom_spec` nenhum ao recriar.
