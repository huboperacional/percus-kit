## Ausência numa tabela só é prova se o PRODUTOR escreve nela — abra o produtor, não o consumidor {#ausencia-numa-tabela-so-e-prova-se-o-produtor-escreve-nela}

`tags: instrumento cego, baseline, evidencia, guarda inerte, 5-T, predicao negativa, silencio nao e ausencia, R23`

**Sintoma:** você quer saber se uma guarda já disparou alguma vez. Faz a consulta óbvia —
`SELECT count(*) FROM <tabela> WHERE <texto da guarda>` — e vem **0**. Com o número na mão você
constrói o resto do diagnóstico: derruba as hipóteses de explicação uma a uma, confirma que o call
site está fiado, que o código está no ar há semanas, que a regra pura devolveria "sim" para a
entrada real. Fecha em *"regra certa + call site fiado + código no ar = fala que nunca saiu"*.

**E está tudo errado, porque aquele `0` era propriedade do código.**

**Causa raiz:** o produtor daquela fala **não escreve na tabela que você consultou**. No caminho
típico, quem despacha (`dispatchResponse`, `sendMessage`, o cliente HTTP do provider) só **envia** —
persistir é responsabilidade do *caller*, e cada caller decide por conta própria. Um caller que
esquece de persistir cria uma fala **estruturalmente invisível** para toda consulta ao histórico.
O eco do provider também não repõe: pipelines de inbound costumam **descartar** mensagens
`is_from_me`.

**Medido em tiatendo (2026-08-25):** concluí que a salvaguarda de handoff *"nunca disparou"* porque
o texto dela aparecia **0 vezes** em `messages`, no histórico inteiro de produção. Um smoke
autorizado mostrou a guarda disparando em **19 segundos**. O emissor chamava o dispatcher direto, e
**nenhum dos dois** gravava em `messages` — contra 20+ call sites do mesmo repositório que gravavam.
A contraprova estava registrada no próprio repositório havia semanas, **na mesma conversa**, e eu
não a cruzei.

**Como não cair:**

1. **Abra o PRODUTOR, não o consumidor.** `grep saveMessage` (ou o equivalente) **no módulo que
   emite**. Se ele não escreve, seu número não é baseline nem zero: é **vazio por construção**, e a
   frase *"nunca disparou"* não pode ser dita.
2. **Cheque o segundo instrumento com o mesmo rigor.** No caso acima a flag `handoff_client_notified`
   parecia servir — mas era **zerada** em toda devolução ao bot, em cinco lugares. Contá-la hoje
   também nunca acusaria disparo passado.
3. **Cruze com o histórico de provas da própria frente** antes de concluir. Um `[5-T]` antigo que
   observou a guarda funcionando derruba a tese em um minuto.
4. **Registre a predição NEGATIVA junto da positiva** ao desenhar o experimento. Foi ela —
   *"não haverá linha nova de assistente"*, confirmada por `1312 → 1313` com a única linha nova
   sendo a do cliente — que provou a cegueira do instrumento **de forma executável**, em vez de
   argumentada.

**Achado que vem de brinde:** guarda cujo sucesso não deixa rastro durável é **achado por si só**.
Vale abrir como dívida de observabilidade — é exatamente o que torna esta classe de erro repetível,
e o próximo a perguntar *"isso já disparou?"* cai igual.

**Regra que fica:** *ausência de evidência só é evidência de ausência quando o produtor
comprovadamente escreve no lugar onde você procurou.*

**Recorrência confirmada — Micro Investors, 2026-08-25, e quase reprovei trabalho correto.** Fui
verificar se um conserto realmente gravava em produção e busquei a prova no `audit_log`: **3
gravações, todas num investidor, nenhuma no caso que eu queria**. A leitura óbvia — "o
implementador não provou" — estava errada. A query seguinte derrubou a primeira:

```sql
SELECT tgname FROM pg_trigger
 WHERE tgrelid = 'public.users'::regclass AND NOT tgisinternal;   -- vazio
```

**Não há trigger de auditoria naquela tabela.** Os registros vinham da **aplicação**, num caminho
específico (admin editando investidor); o endpoint self-service que eu investigava não passa por
ali. O instrumento não capta esse evento, então o silêncio dele não significava nada.

Troquei de instrumento e a resposta veio em uma linha: `users.updated_at` do usuário certo era **de
hoje**, e as dos outros quatro eram de março e abril. **Uma query provando que o instrumento
registra esse tipo de evento vale mais que dez interpretando o silêncio dele.**

Irmãos: [[guarda-que-mede-o-eixo-que-ela-mesma-escreve-e-inerte]] ·
[[fixture-que-mente-faz-a-mutacao-mentir-junto]] ·
[[golden-de-regressao-que-guarda-caminho-morto]] ·
[[argumento-posicional-vira-parametro-e-o-gate-passa-vazio]]
