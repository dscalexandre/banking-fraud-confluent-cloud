![Banking Fraud Confluent Cloud](docs/assets/banking-fraud.png)

# Banking Fraud Confluent Cloud

## Objetivo

O projeto implementa um pipeline reproduzível de detecção de fraude bancária em tempo real. Dados sintéticos são carregados no PostgreSQL/Neon; Debezium publica alterações no Kafka; Avro e Schema Registry governam contratos; Flink SQL detecta fraudes; um consumidor persiste alertas de forma idempotente em PostgreSQL.

DLQ, Tableflow e Streaming Agent são extensões previstas depois da validação do fluxo obrigatório.

## Arquitetura

Consultar o [desenho da solução](docs/architecture/solution-design.md), que
constitui a referência arquitetural para o desenvolvimento do projeto.

## Tecnologias

- Python
- Poetry
- PostgreSQL
- Neon
- Debezium
- Apache Kafka
- Kafka Connect
- Confluent Cloud
- Avro e Schema Registry
- Flink SQL

## Pré-requisitos

- Python `>=3.12,<3.13`
- Poetry 2.x
- Git
- Confluent CLI v4+
- `psql` e acesso a um PostgreSQL/Neon com logical replication habilitada

## Preparação do ambiente

Configurar o ambiente virtual dentro do projeto:

```bash
poetry config virtualenvs.in-project true
```

Instale as dependências:

```bash
poetry install
```

Validar a configuração:

```bash
poetry check
```

## Reprodução e operação

Crie `.env` a partir de `.env.example`; ele nunca deve ser versionado. O
`setup.sh` cria ou seleciona os recursos, carrega os CSVs sintéticos e prepara
o pipeline. Execute o consumer do sink em terminal separado antes de executar
`dataset/neon/fraud-test.sql`. O README final só pode incluir outputs reais:
compatibilidade do Schema Registry, envelopes CDC, alerta de cada regra,
materialização idempotente, métricas, ACLs, billing e teardown.

O teardown remove, nesta ordem, connectors, statements Flink, compute pool,
tópicos, API keys e service accounts, comprovando ao final as listas vazias de
Connect e compute pools do desafio.

## Contrato do README final

Esta versão inicial não declara o pipeline executado. Antes da submissão, ela
deve ser substituída por um README de reprodução que contenha, sem marcadores
pendentes: arquitetura; pré-requisitos; estrutura; `.env.example`; instalação
com Poetry; uso de `setup.sh`; dados sintéticos e suas contagens; Schema
Registry; CDC; Flink; as duas regras; sink PostgreSQL; observabilidade;
segurança; custos; confiabilidade; `teardown.sh`; e a prova de clone limpo.

As quatro respostas operacionais devem conter os números e outputs da própria
conta. O README deve explicar a garantia trecho a trecho, onde uma duplicata
ainda pode ocorrer e por que o UPSERT do sink torna o efeito idempotente, sem
alegar transação distribuída exactly-once.

## Status

Projeto preparado para iniciar o pipeline pela carga dos dados sintéticos
existentes no PostgreSQL/Neon, com governança, referência arquitetural e
ambiente local estabelecidos. Os recursos de execução ainda não foram
provisionados nesta etapa.

## Governança de entregas

Cada entrega segue o fluxo `Issue → branch → commits → Pull Request → Merge Commit`.
As Issues usam os templates `01-entrega.md` ou `02-bug.md`, os Pull Requests
usam o template padrão em `.github/pull_request_template.md` e o conteúdo deve
ser revisado e aprovado explicitamente antes da criação da Issue ou do Pull
Request.

## Licença

Este projeto está licenciado sob a licença MIT. Consultar [LICENSE](LICENSE).
