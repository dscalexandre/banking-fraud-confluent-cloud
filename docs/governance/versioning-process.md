# Processo de Versionamento

Este processo rege o versionamento de novos projetos, da preparação do
repositório à conclusão da entrega.

Cada entrega segue este fluxo:

```text
Issue → branch → alterações → commits → preenchimento da Issue
      → publicação da branch → Pull Request → critérios de aceite → Merge Commit
      → Issue encerrada → main sincronizada
```

Para módulos funcionais, inicie após uma descoberta sem escrita: analise `docs/architecture/solution-design.md`, o estado e o histórico do repositório, identifique a última implementação e proponha um único próximo módulo. Sem proposta inequívoca e aprovação explícita, não crie Issue, branch, commit ou Pull Request. Após a aprovação, execute as etapas abaixo somente no escopo necessário ao módulo.

## Padrão de apresentação dos comandos

- Preserve a sequência do guia e a governança por Issues, branches, commits e
  Pull Requests.
- Ao criar um novo roteiro de versionamento baseado neste processo, use os
  mesmos nomes de variáveis definidos nos comandos deste guia.
- Produza commits atômicos, reversíveis e semanticamente coerentes.
- Use uma célula `bash` por ação independente.
- Acima de cada célula, escreva uma descrição objetiva, clara e sem negrito.
- Separe os blocos de execução com `---`.
- Quando relevante e previsível, descreva a saída imediatamente abaixo da
  célula, em texto corrido, no formato **Saída:** descrição.
- Inclua o código de saída quando relevante; por exemplo, **Saída:** nenhuma saída
  e código de saída zero.
- Nunca deixe **Saída:** isoladamente nem represente saídas em células de código.
- Para condições, inclusive no tratamento de erros, use `test` e somente para
  essa finalidade.
- Execute comandos cotidianos do Git e da GitHub CLI (`gh`) diretamente, sem
  envolvê-los com `test`.

## 1. Preparar o repositório

Confirmar que a árvore de trabalho não possui alterações pendentes:

```bash
git status --short
```

**Saída:** nenhuma saída e código de saída zero, indicando que a árvore de trabalho está limpa.

---

Mudar para a branch `main`:

```bash
git switch main
```

**Saída:** muda para a branch `main` ou informa que ela já está ativa.

---

Atualizar a `main` a partir do repositório remoto somente por avanço direto:

```bash
git pull --ff-only origin main
```

**Saída:** atualiza a `main` por avanço direto ou informa que ela já está
atualizada.

---

## 2. Criar a Issue

Criar uma nova Issue diretamente pela GitHub CLI com o corpo integralmente
declarado no comando. Selecionar um dos formatos abaixo e substituir o título,
o rótulo e o conteúdo entre sinais de menor e maior pelos valores específicos
da entrega. Não manter marcadores genéricos no comando executado.

Para uma entrega:

```bash
issue_url=$(
  gh issue create \
    --title "[Entrega]: <título específico>" \
    --label "enhancement" \
    --body-file - <<'EOF'
### Objetivo

<Resultado verificável esperado.>

### Escopo

- <Item específico coberto pelas alterações do Pull Request>

### Critérios de aceite

- [ ] <Condição objetiva e verificável>
EOF
)

issue_number=${issue_url##*/}
printf 'Issue criada: #%s\n' "$issue_number"
```

**Saída:** exibe `Issue criada: #<número atribuído pelo GitHub>`.

---

Para um defeito:

```bash
issue_url=$(
  gh issue create \
    --title "[Bug]: <título específico>" \
    --label "bug" \
    --body-file - <<'EOF'
### Objetivo

<Correção verificável esperada.>

### Comportamento observado

<O que ocorreu, incluindo impacto e mensagens de erro não sensíveis.>

### Comportamento esperado

<O resultado que deveria ocorrer.>

### Passos para reproduzir

1. <Passo reproduzível>

### Evidências

<Logs sanitizados, métricas, versões e demais evidências sem segredos ou PII.>

### Critérios de aceite

- [ ] <Condição objetiva e verificável>
EOF
)

issue_number=${issue_url##*/}
printf 'Issue criada: #%s\n' "$issue_number"
```

**Saída:** exibe `Issue criada: #<número atribuído pelo GitHub>`.

Nos dois formatos, o corpo deve preservar a estrutura selecionada e conter
todos os campos preenchidos. O Pull Request deve registrar a evidência e o
resultado correspondente a cada critério de aceite.

---

## 3. Criar a branch vinculada à Issue

Criar a branch de desenvolvimento a partir da `main`, vinculá-la à Issue e
fazer checkout. Substituir o tipo e o nome curto antes da execução:

```bash
branch_name="<tipo>/${issue_number}-<nome-curto>"

gh issue develop "$issue_number" \
  --base main \
  --name "$branch_name" \
  --checkout
```

**Saída:** cria a branch vinculada à Issue e muda para ela.

---

Confirmar o vínculo entre a branch e a Issue:

```bash
gh issue develop --list "$issue_number"
```

**Saída:** exibe a branch criada e vinculada à Issue.

---

## 4. Validar e registrar as alterações

Realizar somente as alterações necessárias para atender ao escopo e aos critérios
de aceite da Issue.

Revisar o estado da árvore de trabalho:

```bash
git status
```

---

Adicionar somente os arquivos relacionados à Issue:

```bash
git add <arquivos>
```

---

Validar as alterações preparadas para commit:

```bash
git diff --cached --check
```

---

Criar um commit coeso e rastreável:

```bash
git commit \
  -m "..." \
  -m "Refs #${issue_number}"
```

---

Repetir esta seção para cada unidade de alteração coesa. Cada repetição deve
preparar somente os arquivos daquele commit e executar novamente a validação
do conteúdo preparado antes de registrá-lo. Não acumular alterações sem
relação no mesmo commit.

---

## 5. Preencher a Issue antes da publicação da branch

Obter a URL da Issue em revisão:

```bash
gh issue view "$issue_number" --json url --jq '.url'
```

**Saída:** exibe a URL da Issue atual no GitHub.

---

Preencher na Issue somente os critérios de aceite comprovados pelas validações
executadas, mas não fechar a Issue. Ela deve permanecer aberta até a integração
do Pull Request; a referência `Closes #${issue_number}` a encerrará
automaticamente após o merge.

---

## 6. Publicar a branch

Publicar a branch e configurar o upstream:

```bash
git push -u origin "$branch_name"
```

**Saída:** publica a branch e configura seu acompanhamento em `origin`.

---

## 7. Criar e validar o Pull Request

Criar o Pull Request diretamente pela GitHub CLI com o corpo integralmente
declarado no comando. Substituir o título e o conteúdo entre sinais de menor e
maior pelos valores específicos da entrega. Não manter marcadores genéricos no
comando executado. O heredoc protegido preserva literalmente o Markdown; a
substituição seguinte injeta somente o número da Issue:

```bash
pr_body=$(cat <<'EOF'
## Objetivo

Closes #__ISSUE_NUMBER__

<Resultado verificável produzido pela entrega, alinhado ao objetivo da Issue.>

## Alterações

- <Arquivo ou componente afetado e a mudança realizada>

## Validação

- <Validação executada e resultado observado>

## Impacto

- <Efeito em comportamento funcional, infraestrutura e dados, ou ausência de impacto>
EOF
)

pr_body=${pr_body/__ISSUE_NUMBER__/$issue_number}

gh pr create \
  --base main \
  --head "$branch_name" \
  --title "<tipo>: <título específico>" \
  --body "$pr_body"
```

**Saída:** cria o Pull Request e exibe sua URL.

---

Consultar e guardar o número atribuído ao Pull Request, sem depender do formato
textual retornado pelo comando de criação:

```bash
pr_number=$(gh pr view "$branch_name" --json number --jq '.number')
printf 'Pull Request: #%s\n' "$pr_number"
```

**Saída:** exibe `Pull Request: #<número atribuído pelo GitHub>`.

O corpo deve preservar as quatro seções do modelo, cobrir o escopo aprovado
na Issue e declarar as validações e os impactos evidenciados.

---

### 7.1. Obter a URL do Pull Request

Obter a URL do Pull Request recém-criado:

```bash
gh pr view "$pr_number" --json url --jq '.url'
```

**Saída:** exibe a URL do Pull Request atual no GitHub.

---

Confirmar que o Pull Request está configurado para encerrar a Issue:

```bash
closes_issue=$(gh pr view "$pr_number" \
  --json closingIssuesReferences \
  --jq ".closingIssuesReferences | any(.number == ${issue_number})")

test "$closes_issue" = "true"
```

A execução deve prosseguir somente se o vínculo estiver confirmado.

---

## 8. Confirmar os critérios de aceite e a prontidão do Pull Request

Confirmar que o Pull Request está aberto e não é rascunho:

```bash
gh pr view "$pr_number" \
  --json state,isDraft \
  --jq '(.state == "OPEN") and (.isDraft == false)' | grep -qx true
```

**Saída:** nenhuma saída e código de saída zero se o Pull Request estiver
aberto e não for rascunho.

---

Revisar os critérios de aceite registrados na Issue:

```bash
gh issue view "$issue_number" --json body --jq '.body'
```

**Saída:** exibe o corpo da Issue para conferir cada critério marcado e sua
evidência correspondente no Pull Request. Não avançar com critérios pendentes
ou resultados de validação não observados.

---

## 9. Integrar por Merge Commit

Solicitar o Merge Commit do Pull Request associado à branch de desenvolvimento:

```bash
gh pr merge "$branch_name" --merge
```

**Saída:** confirma a integração por Merge Commit.

---

Continuar somente após a notificação de que o Pull Request foi integrado.

---

## 10. Sincronizar e validar a conclusão

Mudar para a branch `main`:

```bash
git switch main
```

**Saída:** muda para a branch `main`.

---

Atualizar a `main` somente por avanço direto:

```bash
git pull --ff-only origin main
```

**Saída:** atualiza a `main` até o Merge Commit do Pull Request.

---

### 10.1. Validar o encerramento automático da Issue

Confirmar que a palavra-chave `Closes #${issue_number}` encerrou a Issue após
o merge:

```bash
gh issue view "$issue_number" \
  --json number,title,state,closedAt \
  --jq '{number, title, state, closedAt}'
```

**Saída:** o campo `state` exibe `CLOSED`, `closedAt` contém a data e a hora do
encerramento, e o comando termina com código de saída zero.

---

## 11. Finalizar

Remover a branch local integrada:

```bash
git branch -d "$branch_name"
```

**Saída:** remove a branch local integrada.

---

Validar o estado final do repositório:

```bash
git status --short --branch
```

**Saída:** `## main...origin/main`, sem linhas adicionais nem indicadores
`ahead` ou `behind`.

---

## Auditoria final

Consultar o histórico gráfico:

```bash
git log \
  --graph \
  --oneline \
  --decorate \
  --all \
  --date-order
```

**Saída:** apresenta os commits atômicos da entrega e o Merge Commit do Pull
Request na `main`.

O histórico deve permitir rastrear o fluxo:

```text
Issue
  ↓
Branch vinculada
  ↓
Alterações
  ↓
Validações aplicáveis e commits atômicos
  ↓
Critérios comprovados registrados na Issue
  ↓
Branch publicada
  ↓
Pull Request
  ↓
Critérios de aceite e evidências confirmados
  ↓
Merge Commit
  ↓
Issue encerrada
  ↓
main sincronizada
```

No histórico esperado:

- `A`: estado inicial da `main`;
- `C1..Cn`: commits atômicos e rastreáveis da entrega;
- `M`: Merge Commit do Pull Request.

## Regra de conclusão

O processo de versionamento somente pode ser considerado concluído quando:

- todos os critérios de aceite estiverem concluídos;
- o Pull Request estiver integrado e a Issue encerrada;
- a `main` estiver sincronizada e a árvore de trabalho limpa;
- a branch local integrada tiver sido removida.
