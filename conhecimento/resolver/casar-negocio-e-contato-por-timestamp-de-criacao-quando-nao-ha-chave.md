## Espelho de CRM sem chave negócio↔contato: o timestamp de criação do contato copiado no negócio casa 97,7% — mede closed-loop sem chamar a API {#casar-negocio-e-contato-por-timestamp-de-criacao-quando-nao-ha-chave}

`tags: hubspot, crm, closed-loop, join, timestamp, contact_createdate, atribuicao, lead para reuniao, coorte, espelho local, R23`

**Sintoma:** o espelho local do CRM tem `crm_contacts` (com origem: `source`, `hsa_acc`, `hsa_cam`,
click ids) e `crm_deals` (com o evento de negócio: reunião, venda), mas **nenhuma chave** entre
eles — `contact_email_hash` nulo em todos os negócios, nenhum id de contato no `prepared_record`.
A conclusão natural é "lead→reunião por origem/campanha não é computável localmente; precisa da API
ao vivo" — que estoura em `429` e pagina até 10k.

**O que destrava:** o sync grava no negócio a propriedade `contact_createdate` do contato
associado, e o contato tem `contact_created_at`. Ambos com **precisão de milissegundo** do HubSpot.
Timestamp de criação é, na prática, uma chave.

```sql
select d.id, c.prepared_record->>'source', c.prepared_record->>'hsa_cam'
from crm_deals d
join crm_contacts c
  on c.tenant_id = d.tenant_id
 and c.contact_created_at = nullif(d.prepared_record->>'contact_createdate','')::timestamptz
where d.tenant_id = :t and d.appointment_entered_at is not null;
```

Medido no D4U (tenant 7), 2026-09-05: **8.290 de 8.484 reuniões (97,7%) casam com exatamente um
contato**; 191 ambíguas (timestamps repetidos — importações em lote, todas `OFFLINE`); 3 sem par.

**Cuidados que fazem parte do método, não notas de rodapé:**

- **Declare a taxa de match e a distribuição dos ambíguos por origem.** Se os repetidos se
  concentrassem numa origem, a taxa dela estaria subcontada. Aqui eram todos `OFFLINE` em lote;
  Meta aparecia como candidato em 4 de 191 — sem viés. Sem essa verificação, o número é suspeito.
- **Denominador:** lead de plataforma ≠ contato no CRM (no D4U, 48% dos leads Meta viram contato
  novo). Toda taxa deve dizer qual usa.
- **Coorte fechada:** só compare origens em contatos criados há mais tempo que o lag p90 (no D4U,
  mediana 10 dias, p90 111). Coortes imaturas subcontam.
- **Primeiro toque:** `hsa_acc`/`hsa_cam` vêm do primeiro URL do contato. Remarketing sobre
  contato que já está no CRM **nunca** recebe crédito — a régua é cega a ele por construção. Não
  condene remarketing com esta régua; diga "não mensurável".
- **Negócio com vários contatos** casa com o contato principal — em nichos de casal/família
  (imigração), atribui a reunião à origem de um só.

**O que isso permitiu:** lead→reunião por origem (Meta via site 6,6% · Google 4,1% · Meta USD 4,0%
· Meta BR 0,9%), por campanha (US$/reunião por campanha, com IC) e por coorte mensal — e o **teste
distintivo** entre "lead ruim" e "SDR saturado": comparar origens **na mesma coorte** (se só uma
cai, é qualidade; se todas caem, é capacidade). Tudo local, zero chamada ao HubSpot.

**How to apply:** antes de dizer que closed-loop "não é computável localmente", procure um
timestamp de criação copiado entre as duas tabelas. Vale para qualquer sync que grave
`contact_createdate` (ou equivalente) no negócio.
