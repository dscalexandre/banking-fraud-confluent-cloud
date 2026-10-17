# Desenho da Solução de Detecção de Fraude Bancária em Tempo Real

## Conteúdo de referência arquitetural permanente

As seções desta parte definem o escopo e o desenho de alto nível do
sistema.

Este documento descreve a arquitetura do projeto
`banking-fraud-confluent-cloud`. A árvore oficial do repositório é
mantida separadamente em `project-structure.md`.

------------------------------------------------------------------------

## 1. Contexto, objetivo e fronteiras

O projeto `banking-fraud-confluent-cloud` implementa um pipeline
reproduzível de detecção de fraude bancária em tempo real usando
PostgreSQL/Neon e serviços do Confluent Cloud.

A solução parte de dados bancários 100% sintéticos, persiste o estado de
origem no PostgreSQL, captura alterações por CDC com Debezium, publica
os eventos no Apache Kafka, governa os contratos com Avro e Schema
Registry e processa os eventos com Flink SQL.

A detecção determinística é executada por duas regras:

-   `RULE_VELOCITY`: identifica 3 ou mais transações do mesmo `card_id`
    dentro de 60 segundos;
-   `RULE_CARD_TESTING`: identifica 3 ou mais transações de baixo valor,
    com `amount <= R$ 20,00`, do mesmo `card_id` dentro de 10 segundos.

Os alertas das duas regras convergem para `desafio.fraud.detected`. O
fluxo obrigatório persiste esses alertas de forma idempotente em
PostgreSQL. Como extensão opcional, um Streaming Agent pode realizar
julgamento contextual dos alertas já detectados.

A solução também prevê uma DLQ para tratamento controlado de eventos
defeituosos e Tableflow para materialização de tópicos selecionados como
tabelas Apache Iceberg.

Não fazem parte do escopo atual AWS, Terraform, Databricks, Kubernetes,
Docker, arquitetura multiagente, RAG ou banco vetorial.

### 1.1 Estratégia de implantação inicial

A implementação deve avançar em incrementos verificáveis, mantendo o
pipeline principal funcional antes das extensões opcionais.

A ordem arquitetural é:

``` text
dados sintéticos
      ↓
PostgreSQL / Neon
      ↓
CDC / Debezium
      ↓
Confluent Kafka
      ↓
Schema Registry / Avro
      ↓
Flink SQL
      ↓
detecção determinística
      ↓
desafio.fraud.detected
      ↓
Sink PostgreSQL
```

Depois do caminho obrigatório estar validado, entram os incrementos de
DLQ, Tableflow e Streaming Agent, sem alterar a responsabilidade das
duas regras determinísticas.

------------------------------------------------------------------------

## 2. Arquitetura dos fluxos

### 2.1 Carga dos dados sintéticos existentes

``` text
dataset/data/
├── customers.csv       200
├── accounts.csv        240
├── cards.csv           320
├── merchants.csv        60
└── transactions.csv  2.000
        │
        │ arquivos sintéticos versionados no repositório
        ▼
dataset/neon/
├── schema.sql
├── load-data.sql
└── cdc-setup.sql
        │
        │ executados pelo setup/reprodução
        ▼
PostgreSQL / Neon
payments.*
```

Os dados já disponíveis no projeto são totalmente sintéticos, ficam versionados em `dataset/data/` e não serão regenerados. O `load-data.sql` deve carregá-los no PostgreSQL a partir de um clone limpo, sem depender de arquivos existentes apenas na máquina do autor. PAN completo, CVV e PIN não fazem
parte do dataset. O cartão é representado por `card_id` e `last4`.

A implementação não inclui gerador nem regeneração. Os datasets sintéticos já
produzidos são tratados como artefatos oficiais de entrada e permanecem fixos e
versionados.

Os casos controlados de fraude permanecem separados dos dados de
entrada:

``` text
dataset/expected/
├── fraud_cases.json
└── fraud_card_testing_cases.json
```

`fraud_cases.json` registra os casos esperados da `RULE_VELOCITY`.
`fraud_card_testing_cases.json` registra os casos esperados da
`RULE_CARD_TESTING`. Esses arquivos são ground truth de validação e não
entram no processamento Flink.

`dataset/quality_report.csv` preserva a validação já produzida do dataset base:
cardinalidade, unicidade das chaves primárias e ausência de chaves estrangeiras
órfãs. Ele é evidência de qualidade da massa de entrada e não participa do fluxo
de streaming.

### 2.2 CDC e publicação no Kafka

``` text
PostgreSQL / Neon
payments.*
      │
      ▼
Debezium
PostgreSQL CDC Source
      │
      ├── INSERT
      ├── UPDATE
      └── DELETE / tombstone
      │
      ▼
Confluent Kafka
desafio.payments.*
```

A configuração do CDC fica em `connectors/cdc.json`, sem segredos
versionados. Ela usa `PostgresCdcSourceV2`, `output.data.format=AVRO`,
`output.key.format=AVRO`, `topic.prefix=desafio`, snapshot inicial,
`heartbeat.interval.ms=60000`, `tasks.max=1`,
`publication.name=desafio_cdc_publication` e
`publication.autocreate.mode=disabled`.

`dataset/neon/cdc-setup.sql` deve preparar o PostgreSQL integralmente:
criar ou atualizar `cdc_user` sem versionar sua senha, conceder somente
CONNECT, USAGE e SELECT necessários, criar a publication
`desafio_cdc_publication` para as cinco tabelas e aplicar `REPLICA IDENTITY
FULL` nas tabelas usadas na evidência. O connector lê a publication pronta;
ele não recebe privilégio para criá-la.

O CDC deve produzir evidência real de criação, atualização e exclusão,
incluindo o comportamento de tombstone quando aplicável.

### 2.3 Contratos Avro e Schema Registry

``` text
Kafka
  │
  ▼
Schema Registry
  │
  ├── contratos Avro
  ├── namespace com.bootcamp.payments
  ├── compatibilidade BACKWARD
  └── classificação PII / PCI / FIN
```

Os contratos ficam em `schemas/payments/` e a classificação de
governança em `schemas/governance-tags.json`.

Valores monetários usam semântica decimal exata. No PostgreSQL,
`NUMERIC(15,2)`; no Avro, logical type `decimal` com `precision=15` e
`scale=2`.

Os arquivos locais expressam o contrato desejado. A evidência de
execução deve demonstrar o subject e a versão realmente registrados, a
política BACKWARD e as classificações efetivamente aplicadas no Schema
Registry.

### 2.4 Preparação e enriquecimento no Flink

``` text
desafio.payments.transactions
            │
            │ temporal join
            ▼
desafio.payments.accounts
            │
            ▼
desafio.transactions.enriched
```

O Flink prepara as chaves necessárias, configura o comportamento
temporal e realiza o enriquecimento das transações com o estado da
conta. `sql/preparation/01-flink-preparation.sql` deve registrar as PKs
lógicas `NOT ENFORCED` e `sql.tables.scan.idle-timeout='5 s'`. Quando o
statement mantiver estado não janelado, deve registrar também um valor real e
justificado de `sql.state-ttl`; o marcador `STATE_TTL` não pode chegar à
entrega.

A preparação fica em `sql/preparation/01-flink-preparation.sql` e o
enriquecimento em `sql/enrichment/02-enrichment.sql`. O join é temporal,
usando `FOR SYSTEM_TIME AS OF t.$rowtime`; a validação precisa considerar o
avanço de watermarks nos dois lados, e não interpretar uma saída vazia como
falha automática.

### 2.5 Regra `RULE_VELOCITY`

``` text
desafio.transactions.enriched
            │
            ▼
PARTITION BY card_id
            │
            ▼
3 ou mais transações
dentro de 60 segundos
            │
            ▼
RULE_VELOCITY
            │
            ▼
desafio.fraud.detected
```

A implementação fica em:

``` text
sql/fraud-detection/rule-velocity.sql
```

A regra preserva a semântica principal do desafio: três ou mais
transações do mesmo cartão dentro de 60 segundos.

### 2.6 Regra `RULE_CARD_TESTING`

``` text
desafio.transactions.enriched
            │
            ▼
mesmo card_id
            │
            ├── 3 ou mais transações
            ├── amount <= R$ 20,00
            └── dentro de 10 segundos
            │
            ▼
RULE_CARD_TESTING
            │
            ▼
desafio.fraud.detected
```

A implementação fica em:

``` text
sql/fraud-detection/rule-card-testing.sql
```

Os limites de R\$ 20,00 e 10 segundos são parâmetros controlados deste
projeto sintético. Não representam um limite bancário universal.

`dataset/neon/fraud-test.sql` é o único roteiro de inserção controlada e deve
conter os cenários positivos das duas regras e os casos negativos de fronteira
descritos em `dataset/expected/`. O cenário de card testing pode também
satisfazer velocity; essa sobreposição deve ser identificada na evidência, não
mascarada.

### 2.7 Consolidação dos alertas

``` text
RULE_VELOCITY ───────────┐
                         │
                         ├──► desafio.fraud.detected
                         │            │
RULE_CARD_TESTING ───────┘            │
                                      ▼
                                   rule_id
```

`rule_id` identifica qual regra originou o alerta. As duas regras
compartilham o mesmo fluxo downstream.

### 2.8 Sink PostgreSQL

``` text
desafio.fraud.detected
        │
        ▼
consumer.py
        │
        ├── alert_id determinístico
        ├── transação PostgreSQL
        ├── UPSERT idempotente
        └── commit do offset após sucesso
        │
        ▼
payments.fraud_alerts
```

A implementação fica em:

``` text
sink/postgres/
├── schema.sql
└── consumer.py
```

O efeito externo é idempotente. Isso não transforma Kafka e PostgreSQL
em uma transação distribuída exactly-once; a proteção contra
reprocessamento é responsabilidade do consumidor e da chave
determinística do alerta.

### 2.9 DLQ

``` text
evento
  │
  ├── válido ─────────► fluxo normal
  │
  └── defeituoso ─────► DLQ
```

A configuração relacionada fica em `connectors/dlq.json`.

A configuração executável deve ser compatível com o mecanismo de
tratamento de erros do conector realmente utilizado. O objetivo
arquitetural é isolar eventos defeituosos, preservar evidência do erro e
impedir que um registro inválido seja confundido com um evento
processado com sucesso.

### 2.10 Tableflow e Apache Iceberg

``` text
Kafka
  │
  ├── transactions ───────► Tableflow ─► Apache Iceberg
  │
  └── fraud.detected ─────► Tableflow ─► Apache Iceberg
```

A documentação/configuração fica em:

``` text
tableflow/
├── transactions.md
└── fraud-detected.md
```

Tableflow é uma evolução da solução e não substitui Flink nem o Sink
PostgreSQL.

### 2.11 Streaming Agent opcional

``` text
desafio.fraud.detected
          │
          ▼
Streaming Agent
          │
          ├── recebe rule_id
          ├── recebe contexto estruturado
          └── realiza julgamento contextual
          │
          ▼
desafio.fraud.analyzed
```

O agente não decide se `RULE_VELOCITY` ou `RULE_CARD_TESTING` ocorreu.
Essa decisão permanece determinística no Flink.

A área correspondente fica em `flink/streaming-agent/`, separada em
conexão, modelo e agente.

------------------------------------------------------------------------

## 3. Organização e estrutura-alvo do repositório

A estrutura-alvo completa do repositório é apresentada abaixo, seguindo
o modelo arquitetural adotado para este documento. O arquivo
`project-structure.md` mantém essa mesma árvore de forma isolada.

``` text
banking-fraud-confluent-cloud/
├── AGENTS.md
├── .gitignore
├── .agents/
│   └── skills/
│       ├── technical-documenter/
│       │   ├── SKILL.md
│       │   └── templates/
│       │       ├── adr.md
│       │       ├── runbook.md
│       │       └── migration.md
│       ├── learning-documenter/
│       │   ├── SKILL.md
│       │   └── assets/
│       │       └── module-learning.md
│       └── module-builder/
│           ├── SKILL.md
│           └── templates/
│               └── implementation-guide.md
├── .codex/
│   └── agents/
│       ├── technical-documenter.toml
│       ├── learning-documenter.toml
│       └── module-builder.toml
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── 01-entrega.md
│   │   ├── 02-bug.md
│   │   └── config.yml
│   └── pull_request_template.md
│
├── docs/
│   ├── architecture/
│   │   └── solution-design.md
│   ├── governance/
│   │   └── versioning-process.md
│   ├── adr/
│   │   └── ADR-001-adotar-poetry.md
│   └── assets/
│       └── banking-fraud.png
│
├── LICENSE
│
├── dataset/
│   ├── data/
│   │   ├── customers.csv
│   │   ├── accounts.csv
│   │   ├── cards.csv
│   │   ├── merchants.csv
│   │   └── transactions.csv
│   ├── neon/
│   │   ├── schema.sql
│   │   ├── load-data.sql
│   │   ├── cdc-setup.sql
│   │   └── fraud-test.sql
│   ├── expected/
│   │   ├── fraud_cases.json
│   │   └── fraud_card_testing_cases.json
│   └── quality_report.csv
│
├── schemas/
│   ├── governance-tags.json
│   └── payments/
│       ├── customers-value.avsc
│       ├── accounts-value.avsc
│       ├── cards-value.avsc
│       ├── merchants-value.avsc
│       ├── transactions-value.avsc
│       ├── transactions-v1.avsc
│       ├── transactions-v2-add-default.avsc
│       └── transactions-v3-remove-required.avsc
│
├── connectors/
│   ├── cdc.json
│   └── dlq.json
│
├── sql/
│   ├── preparation/
│   │   └── 01-flink-preparation.sql
│   ├── enrichment/
│   │   └── 02-enrichment.sql
│   └── fraud-detection/
│       ├── rule-velocity.sql
│       └── rule-card-testing.sql
│
├── flink/
│   └── streaming-agent/
│       ├── connection/
│       ├── model/
│       └── agent/
│
├── tableflow/
│   ├── transactions.md
│   └── fraud-detected.md
│
├── sink/
│   └── postgres/
│       ├── schema.sql
│       └── consumer.py
│
├── evidencias/
│   ├── 01-envelopes-cdc.json
│   ├── 01-foundation/
│   │   ├── cluster-describe.txt
│   │   ├── service-accounts.txt
│   │   ├── producer-acls.txt
│   │   └── consumer-acls.txt
│   ├── 02-cdc/
│   │   ├── connector-status.txt
│   │   └── postgres-counts.txt
│   ├── 03-schema-registry/
│   │   ├── subjects-version.txt
│   │   ├── compatibility-backward.txt
│   │   └── tags-pii-pci-fin.txt
│   ├── 04-flink/
│   │   ├── rule-velocity/
│   │   └── rule-card-testing/
│   ├── 05-sink/
│   │   ├── fraud-alerts.txt
│   │   └── idempotency-check.txt
│   ├── 06-operations/
│   │   ├── observability/
│   │   ├── security/
│   │   ├── costs/
│   │   ├── reliability/
│   │   └── teardown/
│   ├── 07-dlq/
│   └── 08-tableflow/
│
├── setup.sh
├── teardown.sh
├── .env.example
├── pyproject.toml
├── poetry.lock
└── README.md
```

A árvore representa a estrutura planejada do projeto
`banking-fraud-confluent-cloud`. A presença de um componente na estrutura não
deve ser confundida com evidência de que ele já foi executado ou validado. As
responsabilidades de cada área são detalhadas na seção seguinte.

## 4. Componentes da solução

Esta seção consolida as responsabilidades dos componentes definidos na
arquitetura. A estrutura física completa do repositório permanece
descrita na seção 3.

### 4.1 Componentes e responsabilidades

  -----------------------------------------------------------------------------
  Componente                                      Responsabilidade
  ----------------------------------------------- -----------------------------
  `dataset/data/`                                 Cinco arquivos CSV sintéticos,
                                                  versionados e prontos para
                                                  carga reproduzível.

  `dataset/neon/`                                 Schema, carga inicial e
                                                  preparação do PostgreSQL para
                                                  CDC.

  `dataset/expected/`                             Ground truth dos casos
                                                  controlados de
                                                  `RULE_VELOCITY` e
                                                  `RULE_CARD_TESTING`.

  `dataset/quality_report.csv`                    Evidência de qualidade do
                                                  dataset base: contagens, PKs
                                                  únicas e FKs órfãs.

  `schemas/payments/`                             Contratos Avro versionados
                                                  dos eventos do domínio de
                                                  pagamentos.

  `schemas/governance-tags.json`                  Classificação dos campos
                                                  sujeitos às categorias PII,
                                                  PCI e FIN.

  `connectors/cdc.json`                           Configuração não sensível do
                                                  PostgreSQL CDC Source
                                                  Connector.

  `connectors/dlq.json`                           Configuração ou documentação
                                                  executável do tratamento de
                                                  eventos defeituosos, conforme
                                                  o mecanismo suportado pelo
                                                  conector utilizado.

  `sql/preparation/`                            Preparação das tabelas e
                                                  parâmetros necessários ao
                                                  processamento Flink.

  `sql/enrichment/`                             Enriquecimento temporal das
                                                  transações com dados de
                                                  contexto.

  `sql/fraud-detection/rule-velocity.sql`       Implementação determinística
                                                  da `RULE_VELOCITY`.

  `sql/fraud-detection/rule-card-testing.sql`   Implementação determinística
                                                  da `RULE_CARD_TESTING`.

  `flink/streaming-agent/`                        Extensão opcional para
                                                  julgamento contextual dos
                                                  alertas já detectados.

  `tableflow/`                                    Definição da materialização
                                                  dos tópicos selecionados como
                                                  tabelas Apache Iceberg.

  `sink/postgres/`                                Persistência idempotente dos
                                                  alertas em
                                                  `payments.fraud_alerts`.

  `evidencias/`                                   Evidências reais obtidas
                                                  durante a execução e
                                                  validação do projeto.

  `setup.sh` Preparaç                             ão reproduzível dos recursos
                                                  e componentes do projeto.

  `teardown.sh` Remoção                           controlada dos recursos
                                                  criados durante a execução.

  `.env.example`                                  Contrato das variáveis de
                                                  ambiente necessárias, sem
                                                  valores secretos.

  `pyproject.toml`                                Configuração do projeto
                                                  Python e declaração das
                                                  dependências gerenciadas pelo
                                                  Poetry.

  `poetry.lock`                                   Fixação das versões
                                                  resolvidas das dependências
                                                  para execução reproduzível.

  `README.md`                                     Instruções de execução,
                                                  reprodução e navegação da
                                                  entrega.
  -----------------------------------------------------------------------------

### 4.2 Segurança e governança

A segurança deve ser aplicada desde a origem dos dados até o consumo dos
alertas.

#### Dados

-   Os dados utilizados no projeto são 100% sintéticos.
-   PAN completo não é armazenado.
-   CVV e PIN não fazem parte do dataset, mesmo como valores sintéticos.
-   O cartão é representado por `card_id` e `last4`.
-   Campos relevantes são classificados como PII, PCI ou FIN conforme a
    política de governança definida pelo projeto.

#### Segredos e credenciais

-   Segredos reais não devem ser versionados.
-   `.env.example` documenta apenas os nomes das variáveis necessárias.
-   Valores reais permanecem no ambiente local ou no mecanismo de
    credenciais do serviço.
-   `.env` deve permanecer fora do controle de versão por meio do
    `.gitignore`.

#### Acesso ao Confluent Cloud

Service Accounts e ACLs devem seguir o princípio de privilégio mínimo.
As permissões devem corresponder apenas aos tópicos, consumer groups e
demais recursos necessários a cada responsabilidade.

`desafio-producer` recebe somente WRITE e DESCRIBE para tópicos com prefixo
`desafio.`. `desafio-consumer` recebe READ e DESCRIBE para o mesmo prefixo e
READ para consumer groups com prefixo `desafio-`. A conta administrativa é
restrita ao provisionamento e teardown. API keys de Kafka, Schema Registry e
Metrics Cloud têm escopos distintos; nenhuma delas pode ser reutilizada por
suposição nem registrada em evidência.

A classificação e a minimização de dados adotadas pelo projeto são
controles de governança. Isoladamente, elas não constituem certificação
de conformidade PCI DSS.

### 4.3 Observabilidade

A operação deve permitir verificar o comportamento do pipeline de ponta
a ponta.

#### Indicadores mínimos

  ---------------------------------------------------------------------
  Área                               Evidência ou indicador
  ---------------------------------- ----------------------------------
  CDC                                Estado do connector e eventos
                                     efetivamente publicados.

  Kafka                              Volume recebido e comportamento
                                     dos tópicos utilizados pelo
                                     projeto.

  Consumer                           Consumer lag do grupo responsável
                                     pelo Sink PostgreSQL.

  Schema Registry                    Subjects, versões, compatibilidade
                                     e classificações aplicadas.

  Flink                              Estado dos statements e alertas
                                     produzidos por cada regra.

  `RULE_VELOCITY`                    Transações controladas e alerta
                                     correspondente.

  `RULE_CARD_TESTING`                Transações controladas e alerta
                                     correspondente.

  Sink PostgreSQL                    Alertas persistidos e
                                     comportamento idempotente.

  DLQ                                Eventos desviados e motivo do
                                     tratamento, quando habilitada.

  Tableflow                          Materialização das tabelas Apache
                                     Iceberg, quando habilitada.

  Streaming Agent                    Eventos analisados e saída
                                     estruturada, quando habilitado.
  ---------------------------------------------------------------------

As evidências devem representar resultados reais da execução. Arquivos
ou capturas preparados antecipadamente não substituem a validação do
recurso em funcionamento.

As quatro respostas operacionais exigem: pico de
`io.confluent.kafka.server/received_bytes` e lag de um consumer group reais;
ACLs efetivamente listadas; custo obtido por `billing cost list`; e uma tabela
de garantia, risco residual e evidência para cada trecho do fluxo. Os outputs
devem ficar, respectivamente, em `evidencias/06-operations/observability/`,
`security/`, `costs/` e `reliability/`.

### 4.4 Confiabilidade e idempotência

A confiabilidade deve ser analisada por etapa, sem assumir uma garantia
única para todo o pipeline.

``` text
PostgreSQL
    │
    ▼
Debezium CDC
    │
    ▼
Kafka
    │
    ▼
Flink
    │
    ▼
desafio.fraud.detected
    │
    ▼
Consumer
    │
    ▼
PostgreSQL
payments.fraud_alerts
```

O ponto mais sensível para duplicação do efeito externo é a transição
`consumer → PostgreSQL`.

Para esse ponto, o projeto adota:

1.  `alert_id` determinístico;
2.  transação no PostgreSQL;
3.  `UPSERT` idempotente;
4.  confirmação do offset Kafka somente depois do sucesso da transação
    no PostgreSQL.

Esse desenho torna o efeito externo idempotente, mas não deve ser
descrito como uma transação distribuída exactly-once entre Kafka e
PostgreSQL.

### 4.5 Custos e teardown

O ambiente deve permanecer dimensionado para a demonstração do projeto,
evitando recursos desnecessários ou mantidos ativos após os testes.

#### Controle de custos

Durante a execução, devem ser observados os recursos que geram cobrança
no Confluent Cloud, especialmente cluster, Flink e componentes
gerenciados utilizados pelo pipeline.

As principais formas de limitar custo neste projeto são:

-   utilizar capacidade compatível com o pequeno volume da demonstração;
-   executar o teardown assim que as evidências necessárias forem
    coletadas.

#### Encerramento dos recursos

`teardown.sh` deve realizar a remoção controlada dos recursos criados
pelo projeto. A execução final deve produzir evidência de que os
recursos cobrados foram efetivamente removidos.

A ordem é obrigatória: connectors, statements Flink, compute pool, tópicos,
API keys e service accounts. O script termina listando Connect e compute pools
e preserva os outputs em `evidencias/06-operations/teardown/`; listas vazias
para os recursos do desafio são o critério de aceite.

O teardown faz parte da conclusão técnica da entrega e não deve ser
tratado apenas como uma etapa opcional de limpeza.

------------------------------------------------------------------------

## Conteúdo que poderá ser especializado futuramente

As seções seguintes permanecem neste documento enquanto representam a
visão consolidada da solução. Detalhes executáveis continuam nos
respectivos diretórios da árvore do projeto.

------------------------------------------------------------------------

## 5. Entregas, destinos e recuperação

### 5.1 Entregas oficiais

  ---------------------------------------------------------------------
  Informação                         Entrega
  ---------------------------------- ----------------------------------
  eventos CDC                        tópicos `desafio.payments.*`

  transações enriquecidas            `desafio.transactions.enriched`

  alertas das duas regras            `desafio.fraud.detected`

  alertas persistidos                `payments.fraud_alerts`

  análise contextual opcional        `desafio.fraud.analyzed`

  materialização analítica opcional  tabelas Apache Iceberg via
                                     Tableflow
  ---------------------------------------------------------------------

### 5.2 Tratamento de falhas

  ---------------------------------------------------------------------
  Tipo de falha                      Tratamento arquitetural
  ---------------------------------- ----------------------------------
  falha transitória do CDC           retry e observabilidade do
                                     conector

  evento defeituoso compatível com   isolamento na DLQ
  tratamento por DLQ

  falha do Flink                     retomada conforme garantias do
                                     serviço e estado do statement

  repetição de alerta no consumer    UPSERT idempotente

  falha PostgreSQL no Sink           não confirmar o offset antes do
                                     efeito bem-sucedido

  falha da extensão de IA            não interromper o pipeline
                                     obrigatório de detecção
  ---------------------------------------------------------------------

------------------------------------------------------------------------

## 6. Contratos de dados das fontes

As cinco entidades principais são:

``` text
customers
accounts
cards
merchants
transactions
```

As relações principais são:

``` text
customers
    │
    └── accounts
          │
          └── cards

merchants
    │
    └──────────────┐
                   ▼
              transactions
                   ▲
                   │
             accounts/cards
```

Os contratos Avro versionados ficam em `schemas/payments/`. O schema do
PostgreSQL deve manter tipos compatíveis com os contratos de eventos,
especialmente para valores monetários e timestamps.

------------------------------------------------------------------------

## 7. Integração Kafka, Flink e consumo

A integração principal da solução é:

``` text
PostgreSQL / Neon
      │
      ▼
Debezium CDC
      │
      ▼
Confluent Kafka
      │
      ▼
Schema Registry / Avro
      │
      ▼
Flink SQL
      │
      ├── enrichment
      ├── RULE_VELOCITY
      └── RULE_CARD_TESTING
              │
              ▼
     desafio.fraud.detected
              │
        ┌─────┼──────────────┐
        ▼     ▼              ▼
 PostgreSQL Tableflow   Streaming Agent
    Sink      │            opcional
              ▼
        Apache Iceberg
```

O pipeline obrigatório termina com o alerta persistido em PostgreSQL.
Tableflow e o Streaming Agent ampliam a solução, mas não são
pré-requisitos para demonstrar a detecção determinística.

------------------------------------------------------------------------

## 8. Evidências da solução

As evidências reais são organizadas em `evidencias/`:

``` text
evidencias/
├── 01-foundation/
├── 02-cdc/
├── 03-schema-registry/
├── 04-flink/
│   ├── rule-velocity/
│   └── rule-card-testing/
├── 05-sink/
├── 06-operations/
├── 07-dlq/
└── 08-tableflow/
```

A documentação não deve inventar resultados. Arquivos de evidência devem
ser preenchidos com outputs, capturas ou resultados obtidos durante a
execução real do projeto.

Para as duas regras de fraude, a evidência deve permitir relacionar as
transações de entrada, o `rule_id` correspondente e o alerta produzido.

------------------------------------------------------------------------

## 9. Critério arquitetural de conclusão

A solução estará arquiteturalmente completa quando for possível
demonstrar, de forma reproduzível:

1.  disponibilidade no repositório e carga reproduzível dos dados sintéticos existentes;
2.  CDC funcional do PostgreSQL para Kafka;
3.  contratos Avro registrados e governados;
4.  enriquecimento temporal no Flink;
5.  `RULE_VELOCITY` produzindo alertas controlados;
6.  `RULE_CARD_TESTING` produzindo alertas controlados;
7.  convergência das duas regras em `desafio.fraud.detected`;
8.  persistência idempotente em `payments.fraud_alerts`;
9.  observabilidade, segurança e custos documentados;
10. teardown comprovado;
11. DLQ validada quando habilitada;
12. Tableflow/Iceberg validado quando habilitado;
13. Streaming Agent validado separadamente quando habilitado.

O princípio central é manter o pipeline determinístico simples,
reproduzível e verificável. As extensões não devem enfraquecer o caminho
obrigatório nem transformar julgamento de IA em substituto das regras de
fraude executadas no Flink.

O teste de aceitação obrigatório parte de um clone limpo e segue esta ordem:
`poetry install`, criação de `.env` a partir de `.env.example`, `setup.sh`,
início separado do consumer do sink, execução de `fraud-test.sql`, validação
do alerta no Flink e em `payments.fraud_alerts`, coleta das evidências
operacionais e `teardown.sh`. Falha em qualquer gate impede a declaração de
entrega concluída; extensões opcionais não alteram esse resultado.
