![Banking Fraud Confluent Cloud](docs/assets/banking-fraud.png)

# Banking Fraud Confluent Cloud

## Objetivo

O projeto implementa um pipeline reproduzível de detecção de fraude bancária em tempo real com PostgreSQL/Neon e serviços do Confluent Cloud. Dados sintéticos alimentam CDC com Debezium, eventos Kafka com contratos Avro e regras determinísticas em Flink SQL; os alertas são persistidos de forma idempotente em PostgreSQL.

A arquitetura separa origem dos dados, CDC, contratos, processamento, persistência e extensões opcionais de DLQ, Tableflow e Streaming Agent.

## Estado do projeto

Projeto em estruturação inicial. A sequência funcional começa com a carga dos dados sintéticos existentes no PostgreSQL/Neon; os componentes produtivos ainda não estão implementados nesta etapa de governança.

## Governança de entregas

Cada entrega segue o fluxo `Issue → branch → commits → Pull Request → Merge Commit`.
As Issues usam os templates `01-entrega.md` ou `02-bug.md`, os Pull Requests usam o template padrão
em `.github/pull_request_template.md` e o conteúdo deve ser revisado e aprovado explicitamente antes
da criação da Issue ou do Pull Request.
