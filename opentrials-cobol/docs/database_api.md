# ReBEC COBOL — Documentação da API do Banco de Dados

Este documento descreve as **views, functions e procedures** atualmente usadas pelo projeto `opentrials-cobol`.

A arquitetura adotada é:

```text
COBOL chama views/functions/procedures estáveis.
PostgreSQL concentra regras de negócio, filtros, validações e mudanças de estado.
COBOL fica responsável por tela, entrada de dados, fluxo básico e exibição.
```

Com isso, quando uma regra precisar mudar, a preferência será alterar o banco de dados, e não recompilar programas COBOL.

---

## 1. Convenções do projeto

### Schema principal

```sql
rebec_cobol
```

### Convenções de nomes

| Prefixo | Uso |
|---|---|
| `vw_` | View de leitura |
| `fn_` | Function de leitura, validação ou operação com retorno |
| `sp_` | Ação de negócio que altera estado, implementada como function para facilitar consumo via `SELECT` no COBOL |

Observação: neste projeto, algumas ações chamadas `sp_...` foram implementadas como `FUNCTION`, não como `PROCEDURE`, porque os programas COBOL consomem a saída usando:

```bash
psql -At -F '|'
```

---

## 2. Visão geral dos objetos usados pelos binários COBOL

| Objeto PostgreSQL | Tipo | Chamado por |
|---|---|---|
| `rebec_cobol.fn_cobol_clean_text(text)` | Function utilitária | Usada internamente por outras functions |
| `rebec_cobol.vw_public_trials` | View | Base de `fn_public_trial_list`, `fn_public_trial_view_by_id`, `fn_public_trial_view_by_rbr` |
| `rebec_cobol.fn_public_trial_list(integer, integer)` | Function | `trial_list.cbl` |
| `rebec_cobol.fn_public_trial_view_by_id(integer)` | Function | `trial_view.cbl` |
| `rebec_cobol.fn_public_trial_view_by_rbr(text)` | Function | `trial_view.cbl` |
| `rebec_cobol.fn_app_login(text, text)` | Function | `LOGIN.cbl`, `test_login.cbl`, `admin_user_requests.cbl` |
| `rebec_cobol.app_login(text, text)` | Function wrapper | Compatibilidade com versões antigas de `LOGIN.cbl` |
| `rebec_cobol.fn_request_user_access(...)` | Function | `request_user.cbl` |
| `rebec_cobol.fn_list_pending_user_requests()` | Function | `admin_user_requests.cbl` |
| `rebec_cobol.sp_approve_user_request(integer, integer, text)` | Function de ação | `admin_user_requests.cbl` |
| `rebec_cobol.sp_reject_user_request(integer, integer, text)` | Function de ação | `admin_user_requests.cbl` |
| `rebec_cobol.fn_list_active_users()` | Function | Atualmente teste/admin futuro |
| `rebec_cobol.vw_trial_ictrp_main` | View | Base consolidada de dados ICTRP; não deve ser chamada diretamente pelos binários públicos |
| `rebec_cobol.vw_trial_criteria_xml` | View | Exportação/consulta XML futura |
| `rebec_cobol.generate_study_design(integer)` | Function | Trigger/função interna de modelagem |
| `rebec_cobol.generate_study_design_compact(integer)` | Function | Trigger/função interna de modelagem |
| `rebec_cobol.refresh_study_design_after_save()` | Trigger function | Triggers de atualização de desenho do estudo |
| `rebec_cobol.set_updated_at()` | Trigger function | Triggers de atualização de `updated_at` |

---

# 3. API pública de ensaios

## 3.1 `vw_public_trials`

### Tipo

View.

### Objetivo

Expor somente os ensaios clínicos públicos.

### Regra de negócio

Atualmente, um ensaio é público quando:

```sql
status IN ('approved', 'published')
```

### Usada por

```text
fn_public_trial_list
fn_public_trial_view_by_id
fn_public_trial_view_by_rbr
```

### Consumidores COBOL indiretos

```text
trial_list.cbl
trial_view.cbl
```

### Motivo arquitetural

O COBOL não deve saber quais status tornam um ensaio público. Se futuramente a regra mudar para apenas `published`, ou incluir outro status, a mudança deve ser feita nesta view ou nas functions que usam esta view.

---

## 3.2 `fn_public_trial_list(p_limit integer, p_offset integer)`

### Tipo

Function de leitura.

### Objetivo

Retornar uma página de ensaios públicos para listagem no terminal.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.fn_public_trial_list(20, 0);
```

### Retorno

| Campo | Descrição |
|---|---|
| `id` | ID interno do ensaio |
| `trial_id` | Identificador público/RBR |
| `status` | Status público |
| `registration_date` | Data de registro |
| `public_title` | Título público |
| `recruitment_status` | Situação de recrutamento |
| `study_type` | Tipo do estudo |

### Chamado por

```text
codes/trial_list.cbl
```

### Observação

Este objeto substituiu queries diretas no COBOL contra a tabela `trial`.

---

## 3.3 `fn_public_trial_view_by_id(p_id integer)`

### Tipo

Function de leitura.

### Objetivo

Retornar os detalhes públicos de um ensaio a partir do ID interno.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.fn_public_trial_view_by_id(9244);
```

### Retorno principal

| Campo | Descrição |
|---|---|
| `id` | ID interno |
| `trial_id` | RBR/trial_id |
| `utrn` | UTRN |
| `status` | Status |
| `url` | URL pública |
| `public_contact_name` | Nome do contato público |
| `public_contact_phone` | Telefone do contato público |
| `public_contact_email` | Email do contato público |
| `registration_date` | Data de registro |
| `enrolment_date` | Data de recrutamento/enrolment |
| `target_size` | Tamanho da amostra |
| `recruitment_status` | Status de recrutamento |
| `study_type` | Tipo do estudo |
| `study_design` | Desenho do estudo consolidado |
| `phase` | Fase |
| `primary_sponsor` | Patrocinador primário |
| `public_title` | Título público |
| `scientific_title` | Título científico |
| `health_conditions` | Condições de saúde |

### Chamado por

```text
codes/trial_view.cbl
```

### Regra importante

A função parte de `vw_public_trials`, portanto não deve retornar ensaio que não seja público.

---

## 3.4 `fn_public_trial_view_by_rbr(p_trial_id text)`

### Tipo

Function de leitura.

### Objetivo

Retornar os detalhes públicos de um ensaio pelo identificador RBR/trial_id.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.fn_public_trial_view_by_rbr('RBR-3fnbr78');
```

### Chamado por

```text
codes/trial_view.cbl
```

### Regra importante

Assim como `fn_public_trial_view_by_id`, esta função também parte de `vw_public_trials`.

---

# 4. API de autenticação

## 4.1 `fn_app_login(p_username text, p_password text)`

### Tipo

Function de autenticação.

### Objetivo

Validar usuário e senha da aplicação COBOL.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.fn_app_login('admin', '123456');
```

### Retorno

| Campo | Descrição |
|---|---|
| `login_success` | `true` ou `false` |
| `user_id` | ID do usuário autenticado |
| `username` | Nome de usuário |
| `full_name` | Nome completo |
| `role_code` | Perfil: `admin`, `registrant`, `reviewer` |
| `message` | Mensagem de retorno |

### Chamado por

```text
codes/LOGIN.cbl
codes/test_login.cbl
codes/admin_user_requests.cbl
```

### Regras de negócio

A função:

```text
1. valida se o usuário está ativo;
2. valida senha usando hash com pgcrypto;
3. atualiza last_login_at;
4. registra tentativa em app_login_log;
5. retorna dados de sessão para o COBOL.
```

### Observação

A senha nunca deve ser validada no COBOL.

---

## 4.2 `app_login(p_username text, p_password text)`

### Tipo

Function wrapper de compatibilidade.

### Objetivo

Manter compatibilidade com versões anteriores do `LOGIN.cbl`.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.app_login('admin', '123456');
```

### Implementação

Internamente chama:

```sql
SELECT *
FROM rebec_cobol.fn_app_login(p_username, p_password);
```

### Chamado por

```text
Nenhum código novo deve chamar diretamente.
Pode existir apenas para compatibilidade.
```

### Recomendação

Código novo deve usar:

```sql
rebec_cobol.fn_app_login(...)
```

---

# 5. API de solicitação de usuários

## 5.1 `fn_request_user_access(...)`

### Tipo

Function de ação com retorno.

### Objetivo

Criar uma solicitação pendente de conta para `registrant` ou `reviewer`.

### Assinatura

```sql
rebec_cobol.fn_request_user_access(
    p_full_name text,
    p_email text,
    p_requested_username text,
    p_requested_role text,
    p_request_reason text
)
```

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.fn_request_user_access(
    'Teste Registrante',
    'teste.registrante@example.org',
    'teste_registrante',
    'registrant',
    'Solicito acesso para registrar ensaios clínicos.'
);
```

### Retorno

| Campo | Descrição |
|---|---|
| `success` | `true` ou `false` |
| `request_id` | ID da solicitação criada |
| `message` | Mensagem de retorno |

### Chamado por

```text
codes/request_user.cbl
```

### Regras de negócio

A função valida:

```text
1. nome obrigatório;
2. email obrigatório;
3. username obrigatório;
4. role deve ser registrant ou reviewer;
5. não pode existir usuário ativo com mesmo username/email;
6. não pode existir solicitação pendente com mesmo username/email;
7. cria registro em app_user_request com status pending.
```

---

## 5.2 `fn_list_pending_user_requests()`

### Tipo

Function de leitura.

### Objetivo

Listar solicitações de conta ainda pendentes.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.fn_list_pending_user_requests();
```

### Retorno

| Campo | Descrição |
|---|---|
| `request_id` | ID da solicitação |
| `full_name` | Nome completo |
| `email` | Email |
| `requested_username` | Username solicitado |
| `requested_role` | Perfil solicitado |
| `request_reason` | Justificativa |
| `created_at` | Data de criação |

### Chamado por

```text
codes/admin_user_requests.cbl
```

---

## 5.3 `sp_approve_user_request(p_request_id integer, p_admin_user_id integer, p_initial_password text)`

### Tipo

Function de ação, nomeada como `sp_`.

### Objetivo

Aprovar uma solicitação de conta e criar um usuário ativo.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.sp_approve_user_request(1, 1, '123456');
```

### Retorno

| Campo | Descrição |
|---|---|
| `success` | `true` ou `false` |
| `new_user_id` | ID do usuário criado |
| `message` | Mensagem de retorno |

### Chamado por

```text
codes/admin_user_requests.cbl
```

### Regras de negócio

A função:

```text
1. valida request_id;
2. valida admin_user_id;
3. valida senha inicial;
4. confirma que o usuário aprovador é admin ativo;
5. localiza solicitação pending;
6. localiza role solicitada;
7. impede duplicidade de username/email;
8. cria app_user ativo;
9. grava hash da senha inicial;
10. marca app_user_request como approved;
11. grava reviewed_by e reviewed_at.
```

---

## 5.4 `sp_reject_user_request(p_request_id integer, p_admin_user_id integer, p_review_comment text)`

### Tipo

Function de ação, nomeada como `sp_`.

### Objetivo

Rejeitar uma solicitação de conta.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.sp_reject_user_request(
    1,
    1,
    'Dados insuficientes.'
);
```

### Retorno

| Campo | Descrição |
|---|---|
| `success` | `true` ou `false` |
| `message` | Mensagem de retorno |

### Chamado por

```text
codes/admin_user_requests.cbl
```

### Regras de negócio

A função:

```text
1. valida request_id;
2. valida admin_user_id;
3. confirma que o usuário aprovador é admin ativo;
4. localiza solicitação pending;
5. marca a solicitação como rejected;
6. grava reviewed_by, reviewed_at e review_comment.
```

---

## 5.5 `fn_list_active_users()`

### Tipo

Function de leitura.

### Objetivo

Listar usuários ativos da aplicação.

### Chamada SQL esperada

```sql
SELECT *
FROM rebec_cobol.fn_list_active_users();
```

### Retorno

| Campo | Descrição |
|---|---|
| `user_id` | ID do usuário |
| `username` | Nome de usuário |
| `full_name` | Nome completo |
| `email` | Email |
| `role_code` | Perfil |
| `user_status` | Status |
| `created_at` | Data de criação |
| `last_login_at` | Último login |

### Chamado por

```text
Ainda não há tela principal dedicada.
Pode ser usado por futura tela admin de usuários ativos.
```

---

# 6. Views e funções internas do schema principal

## 6.1 `vw_trial_ictrp_main`

### Tipo

View.

### Objetivo

Consolidar os principais dados de um ensaio no formato próximo ao ICTRP.

### Uso atual

É uma view de apoio do schema principal.

### Recomendação arquitetural

Programas COBOL públicos não devem chamar diretamente esta view. Devem chamar:

```text
fn_public_trial_view_by_id
fn_public_trial_view_by_rbr
```

### Motivo

As functions públicas já aplicam a regra de visibilidade pública.

---

## 6.2 `vw_trial_criteria_xml`

### Tipo

View.

### Objetivo

Expor critérios do ensaio em formato útil para exportação XML ou integrações futuras.

### Chamado por

```text
Nenhum binário COBOL atual.
Uso futuro em exportação ICTRP/XML.
```

---

## 6.3 `generate_study_design(p_trial_id integer)`

### Tipo

Function interna.

### Objetivo

Gerar a descrição completa do desenho do estudo a partir das tabelas relacionadas.

### Chamado por

```text
refresh_study_design_after_save()
```

### Uso direto por COBOL

```text
Não.
```

---

## 6.4 `generate_study_design_compact(p_trial_id integer)`

### Tipo

Function interna.

### Objetivo

Gerar uma versão compacta do desenho do estudo.

### Chamado por

```text
refresh_study_design_after_save()
```

### Uso direto por COBOL

```text
Não.
```

---

## 6.5 `refresh_study_design_after_save()`

### Tipo

Trigger function.

### Objetivo

Atualizar dados consolidados do desenho do estudo após alterações nas tabelas relacionadas.

### Chamado por

```text
Triggers do banco.
```

### Uso direto por COBOL

```text
Não.
```

---

## 6.6 `set_updated_at()`

### Tipo

Trigger function.

### Objetivo

Atualizar automaticamente o campo `updated_at` em tabelas que tenham esse controle.

### Chamado por

```text
Triggers do banco.
```

### Uso direto por COBOL

```text
Não.
```

---

# 7. Relação por binário COBOL

## 7.1 `trial_list.cbl`

### Objetos PostgreSQL chamados

```text
fn_public_trial_list
```

### Responsabilidade do COBOL

```text
1. carregar db.conf;
2. montar chamada simples para fn_public_trial_list;
3. ler arquivo temporário;
4. exibir lista paginada.
```

### Responsabilidade do PostgreSQL

```text
1. decidir quais ensaios são públicos;
2. paginar resultados;
3. retornar campos já limpos para psql/COBOL.
```

---

## 7.2 `trial_view.cbl`

### Objetos PostgreSQL chamados

```text
fn_public_trial_view_by_id
fn_public_trial_view_by_rbr
```

### Responsabilidade do COBOL

```text
1. receber ID ou RBR;
2. chamar a function correta;
3. exibir detalhes.
```

### Responsabilidade do PostgreSQL

```text
1. impedir visualização de ensaio não público;
2. consolidar dados do ensaio;
3. retornar contato público;
4. limpar texto para consumo COBOL.
```

---

## 7.3 `LOGIN.cbl`

### Objetos PostgreSQL chamados

```text
fn_app_login
```

### Responsabilidade do COBOL

```text
1. coletar username e password;
2. chamar fn_app_login;
3. preencher estrutura de sessão.
```

### Responsabilidade do PostgreSQL

```text
1. validar usuário ativo;
2. validar senha com hash;
3. identificar role;
4. registrar tentativa de login;
5. atualizar último login.
```

---

## 7.4 `test_login.cbl`

### Objetos PostgreSQL chamados

```text
fn_app_login
```

### Responsabilidade

Programa de teste para validar autenticação.

---

## 7.5 `request_user.cbl`

### Objetos PostgreSQL chamados

```text
fn_request_user_access
```

### Responsabilidade do COBOL

```text
1. coletar nome;
2. coletar email;
3. coletar username desejado;
4. coletar role desejada;
5. coletar justificativa;
6. exibir resultado.
```

### Responsabilidade do PostgreSQL

```text
1. validar campos obrigatórios;
2. validar role permitida;
3. impedir duplicidades;
4. criar solicitação pending.
```

---

## 7.6 `admin_user_requests.cbl`

### Objetos PostgreSQL chamados

```text
fn_app_login
fn_list_pending_user_requests
sp_approve_user_request
sp_reject_user_request
```

### Responsabilidade do COBOL

```text
1. autenticar admin;
2. listar solicitações pendentes;
3. coletar ID da solicitação;
4. coletar senha inicial ou comentário;
5. chamar aprovação/rejeição;
6. exibir resultado.
```

### Responsabilidade do PostgreSQL

```text
1. validar que o operador é admin ativo;
2. criar usuário aprovado;
3. gerar hash da senha;
4. mudar status da solicitação;
5. impedir duplicidades;
6. registrar metadados de revisão.
```

---

## 7.7 `trial_menu.cbl`

### Objetos PostgreSQL chamados diretamente

```text
Nenhum obrigatório.
```

### Responsabilidade

Menu principal que chama outros binários:

```text
trial_list
trial_view
request_user
admin_user_requests
```

---

# 8. Regras de manutenção

## 8.1 Regra principal

Antes de adicionar uma query nova no COBOL, perguntar:

```text
Essa regra pode virar uma function/view no PostgreSQL?
```

A resposta preferencial deve ser:

```text
Sim.
```

## 8.2 COBOL deve evitar

```text
SELECT direto em tabelas de negócio;
JOINs complexos;
regras de status;
validação de permissões;
hash de senha;
INSERT/UPDATE direto em tabelas principais.
```

## 8.3 COBOL pode fazer

```text
chamadas simples do tipo SELECT * FROM fn(...);
exibição;
menus;
entrada de dados;
paginação básica;
leitura de retorno psql com separador |.
```

## 8.4 PostgreSQL deve concentrar

```text
regras de negócio;
filtros de visibilidade;
validação de usuário;
aprovação/rejeição;
criação de hash;
mudanças de status;
auditoria;
consistência dos dados.
```

---

# 9. Checklist após alterar uma function/view

Sempre que alterar um objeto da API do banco:

```bash
psql -U diego -d rebec_cobol -f sources/rebec_cobol_database_api.sql
```

Depois testar:

```bash
psql -U diego -d rebec_cobol -At -F '|' -c "SELECT * FROM rebec_cobol.fn_public_trial_list(5, 0);"

psql -U diego -d rebec_cobol -At -F '|' -c "SELECT * FROM rebec_cobol.fn_app_login('admin', '123456');"

psql -U diego -d rebec_cobol -At -F '|' -c "SELECT * FROM rebec_cobol.fn_public_trial_view_by_id(9244);"

psql -U diego -d rebec_cobol -At -F '|' -c "SELECT * FROM rebec_cobol.fn_public_trial_view_by_rbr('RBR-3fnbr78');"

psql -U diego -d rebec_cobol -At -F '|' -c "SELECT * FROM rebec_cobol.fn_list_pending_user_requests();"

psql -U diego -d rebec_cobol -At -F '|' -c "SELECT * FROM rebec_cobol.fn_list_active_users();"
```

Depois recompilar:

```bash
make -f Makefile.local all
```

E testar os binários principais:

```bash
make -f Makefile.local list
make -f Makefile.local view
make -f Makefile.local test-login
```

---

# 10. Arquivos SQL relacionados

| Arquivo | Função |
|---|---|
| `sources/rebec_cobol_schema.sql` | Schema principal, tabelas, views ICTRP, funções internas |
| `sources/rebec_cobol_access_control.sql` | Tabelas de usuários, roles, pedidos de acesso e login |
| `sources/rebec_cobol_database_api.sql` | API estável consumida pelo COBOL |

---

# 11. Status atual

Até este ponto, os seguintes fluxos já foram implementados e testados:

```text
listar ensaios públicos;
ver detalhes de ensaio público por ID;
ver detalhes de ensaio público por RBR;
login de admin;
pedido de conta;
aprovação/rejeição de pedido de conta;
login de usuário aprovado.
```

