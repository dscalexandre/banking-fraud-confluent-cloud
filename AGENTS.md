# AGENTS.md

## Escopo

- Estas instruções se aplicam a todo o repositório.
- Arquivos `AGENTS.md` mais próximos de um caminho podem especializar estas
  regras sem reduzir seus controles de segurança e governança.

## Fontes de verdade

- Leia `docs/architecture/solution-design.md` antes de alterar arquitetura,
  fluxos de ingestão, contratos, destinos, falhas, recuperação ou
  infraestrutura.
- Quando existir, leia `docs/adr/ADR-001-adotar-poetry.md` antes de alterar
  dependências, empacotamento ou gerenciamento do ambiente Python.
- Trate os artefatos versionados, as configurações, os contratos executáveis,
  os testes aplicáveis e os resultados de validações observados como evidência
  do comportamento implementado.
- A árvore do desenho da solução representa a direção arquitetural. Implemente
  apenas os componentes necessários ao incremento em execução e não crie
  componentes vazios somente para reproduzir a árvore.

## Invariantes do produto

- Preserve os contratos, identificadores, destinos, estados de processamento,
  mecanismos de recuperação e comportamento de falha definidos na arquitetura,
  salvo mudança explicitamente solicitada e documentada.
- Falhas transitórias não podem confirmar, avançar ou descartar estado que
  impeça uma recuperação segura.
- Dados ou artefatos inválidos devem seguir o tratamento, a retenção e o
  relatório de validação definidos na arquitetura e nos contratos aplicáveis.

## Requisitos obrigatórios do pipeline

- Use exclusivamente os cinco CSVs sintéticos versionados. Não introduza dados
  reais, anonimizados, PAN completo, CVV, PIN, geradores ou downloads externos.
- O caminho obrigatório é PostgreSQL/Neon → Debezium CDC → Kafka Avro + Schema
  Registry → Flink SQL → `desafio.fraud.detected` → `payments.fraud_alerts`.
  Eventos de prova nascem no PostgreSQL; nunca os produza diretamente no Kafka.
- O CDC usa `PostgresCdcSourceV2`, `cdc_user` de menor privilégio, a
  publication `desafio_cdc_publication`, `REPLICA IDENTITY FULL`, snapshot
  inicial, Avro e `heartbeat.interval.ms=60000`.
- Preserve os nomes `desafio-final`, `desafio-basic`, `desafio-pool`, tópicos
  `desafio.*` e consumer groups `desafio-*`. A ACL de tópico usa `desafio.` e
  a ACL de grupo usa `desafio-`.
- Contratos Avro usam `com.bootcamp.payments.*`; valores monetários usam
  `NUMERIC(15,2)` no PostgreSQL e decimal Avro `precision=15`, `scale=2`.
  Prove BACKWARD aceitando campo com default e rejeitando remoção obrigatória.
- Antes de declarar conclusão, registre evidência real de CDC, tags PII/PCI/FIN
  no Schema Registry, join temporal, duas regras de fraude, sink idempotente,
  throughput, lag, ACLs, billing e teardown. Arquivos locais e resultados
  esperados não substituem evidência de execução.

## Organização do código

- Respeite a organização, os limites entre módulos e as convenções definidos no
  desenho da solução e nos artefatos versionados do repositório.
- Não duplique regras da aplicação em scripts, automações ou arquivos de
  configuração.
- Ao criar pacotes, módulos ou diretórios, siga as convenções da linguagem e
  das ferramentas já adotadas no repositório.

## Segurança e operação

- Nunca versione, exponha ou imprima segredos, arquivos `.env`, tokens, chaves
  privadas, dados pessoais ou sensíveis, dumps, dados brutos, logs sensíveis
  ou estados locais de ferramentas.
- Não desabilite, contorne ou reduza controles de segurança do GitHub.
- Não publique detalhes exploráveis de vulnerabilidades em Issues públicas.
- Não execute operações destrutivas, provisionamento, publicação remota ou
  reprocessamento de dados sem solicitação explícita.
- Preserve arquivos ignorados e artefatos locais.

## Mudanças e documentação

- Para uma decisão durável que altere arquitetura, ferramenta, compatibilidade,
  operação ou trade-off relevante, proponha ou registre uma ADR em `docs/adr/`.
- Não crie ADR para correções locais, detalhes internos ou mudanças sem impacto
  arquitetural.
- Atualize contratos e testes quando alterar formatos, interfaces, eventos,
  estados, destinos ou comportamento de erro.
- Atualize runbooks quando alterar recuperação, replay, tratamento de falhas
  ou procedimentos operacionais.

## Qualidade

- Antes de executar validações, leia os manifestos de dependências e os
  comandos oficiais do `README.md`, `Makefile` ou equivalente, quando existirem.
- Use o gerenciador de dependências e preserve as faixas de versões declaradas
  pelo repositório.
- Respeite as configurações de lint, formatação e testes do projeto, quando
  existirem.
- Execute somente as validações aplicáveis à alteração e registre resultados
  realmente observados.
- Valide alterações de infraestrutura, integrações e contratos com as
  ferramentas específicas, sem provisionar recursos remotos automaticamente.

## Versionamento e entrega

- Não faça push direto para `main`, force push, exclusão de branches ou merge
  sem solicitação explícita.
- Quando a tarefa envolver entrega no repositório remoto, siga o fluxo
  `Issue → branch → Pull Request → Merge Commit`.
- Use apenas Merge Commit; não use squash merge ou rebase merge.
- Mantenha commits atômicos, reversíveis e coesos. Não misture alterações
  funcionais, refatorações não relacionadas, configuração e documentação no
  mesmo commit.
- Antes de criar um commit, execute `git diff --cached --check`.
- Quando houver uma Issue associada, referencie-a no commit e vincule o Pull
  Request para preservar a rastreabilidade.
- Não reverta alterações existentes do usuário sem solicitação explícita.
