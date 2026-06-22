# ReBEC COBOL Architecture

[Português](#português) | [English](#english)

---

<a name="português"></a>

## Sobre o Projeto

Este projeto é uma iniciativa de estudo, arquitetura e desenvolvimento para criar uma versão simplificada de um **Registro de Ensaios Clínicos** inspirado no **ReBEC — Registro Brasileiro de Ensaios Clínicos**, utilizando **GnuCOBOL**, **PostgreSQL** e conceitos de sistemas transacionais legados.

O objetivo principal não é substituir o sistema real do ReBEC, mas explorar como uma aplicação de registro, consulta, revisão, aprovação e publicação de ensaios clínicos poderia ser construída em COBOL, com interface de terminal e armazenamento relacional.

A aplicação trabalha com uma modelagem simplificada baseada no XML do **ICTRP/WHO**, permitindo carregar registros reais em um banco PostgreSQL e navegar pelos dados por meio de uma interface de terminal escrita em COBOL.

Este projeto também tem uma motivação arquitetural mais ampla: demonstrar que países, instituições públicas, universidades ou redes nacionais de pesquisa poderiam criar registros de ensaios clínicos usando tecnologias robustas e tradicionais, como **COBOL**, **mainframes**, bancos relacionais e sistemas transacionais de alta confiabilidade.

A proposta é estudar a possibilidade de um registro clínico com características como:

* rastreabilidade;
* controle de acesso;
* separação entre área pública e área administrativa;
* submissão e revisão de registros;
* aprovação e publicação de ensaios;
* arquitetura simples, auditável e durável;
* compatibilidade conceitual com ambientes legados e mainframe.

---

## Sobre o autor

Este projeto é desenvolvido por **Diego Tostes**, profissional de tecnologia com atuação em sistemas críticos, engenharia de dados, infraestrutura Linux, bancos de dados, automação e sustentação de plataformas digitais de alta disponibilidade.

Diego atua há mais de uma década em ambientes que exigem confiabilidade, rastreabilidade, continuidade operacional e rigor técnico. No contexto do **Registro Brasileiro de Ensaios Clínicos — ReBEC**, trabalha com evolução de sistemas, modelagem de dados, integração com padrões internacionais, exportação de informações para o ICTRP/OMS e desenvolvimento de soluções para apoio à revisão e publicação de ensaios clínicos.

Este projeto nasce como parte de uma jornada de estudo em **COBOL, sistemas legados, conceitos de mainframe e arquitetura de sistemas transacionais**, conectando fundamentos clássicos da computação com tecnologias modernas como PostgreSQL, Linux, Python e automação de dados.

LinkedIn: [linkedin.com/in/diegotostes](https://www.linkedin.com/in/diegotostes/)

---

## Objetivos

* Estudar **GnuCOBOL** em um caso realista.
* Criar uma aplicação de terminal com aparência de sistema legado/bancário.
* Integrar COBOL com PostgreSQL.
* Modelar dados de ensaios clínicos a partir do XML ICTRP.
* Criar uma base conceitual para registros nacionais de ensaios clínicos usando COBOL/mainframe.
* Implementar controle de acesso por perfil de usuário.
* Separar área pública, área de registro, área de revisão e área administrativa.
* Implementar módulos simples de:

  * listagem pública de ensaios;
  * consulta pública por ID interno ou RBR;
  * solicitação de criação de usuário;
  * login interno da aplicação;
  * futura inserção de registros;
  * futura submissão para revisão;
  * futura revisão/aprovação;
  * futura administração de usuários;
  * futura área de relatórios.

---

## Modelo de acesso da aplicação

A aplicação passa a considerar quatro perfis principais.

### 1. Usuário não logado / público

Usuário que acessa o sistema sem autenticação.

Pode:

* listar ensaios públicos;
* visualizar ensaios públicos;
* solicitar acesso como registrant ou reviewer.

Programas relacionados:

```text
trial_menu.cbl
trial_list.cbl
trial_view.cbl
request_user.cbl
```

Regra importante:

```text
Usuários não logados devem visualizar apenas ensaios com status approved ou published.
```

---

### 2. Registrant

Usuário autorizado a registrar ensaios clínicos.

Pode, futuramente:

* criar novo ensaio;
* editar seus próprios ensaios em draft ou returned;
* submeter ensaio para revisão;
* acompanhar o status dos seus registros.

Não pode:

* aprovar ensaios;
* revisar registros de outros usuários;
* aprovar usuários.

---

### 3. Reviewer

Usuário autorizado a revisar registros.

Pode, futuramente:

* visualizar ensaios submetidos para revisão;
* analisar registros;
* devolver registros com observações;
* aprovar ensaios;
* alterar status de revisão.

Regra importante:

```text
Somente registros approved/published aparecem na área pública.
Registros draft, submitted, under_review e returned pertencem ao fluxo interno.
```

---

### 4. Admin

Usuário administrador.

Pode:

* aprovar solicitações de usuários;
* ativar usuários como registrant;
* ativar usuários como reviewer;
* desativar usuários;
* consultar usuários ativos;
* administrar permissões.

O primeiro usuário admin é criado diretamente no banco durante a configuração inicial do controle de acesso.

---

## Estado atual do projeto

Atualmente o projeto já possui:

* script PostgreSQL para criação do schema principal;
* tabelas principais de ensaios clínicos;
* tabelas de vocabulário;
* funções auxiliares;
* view principal baseada no ICTRP;
* script Python para importar XML ICTRP;
* uso de `SAVEPOINT` na importação, evitando rollback total em caso de falha de um registro;
* módulo COBOL de configuração reutilizável;
* menu principal em COBOL;
* listagem paginada de ensaios;
* visualização detalhada de ensaio por ID ou RBR;
* configuração externa de conexão com banco;
* senha fora do código-fonte;
* estrutura inicial de controle de acesso;
* módulo COBOL de login;
* copybook de sessão;
* teste de login em COBOL;
* suporte inicial para perfis `admin`, `reviewer`, `registrant` e `guest`.

---

## Estrutura do projeto

Estrutura esperada:

```text
opentrials-cobol/
├── README.md
├── .gitignore
├── codes/
│   ├── LOADCONF.cbl
│   ├── LOGIN.cbl
│   ├── db_config.cpy
│   ├── session.cpy
│   ├── db.conf.example
│   ├── db.conf
│   ├── run.sh
│   ├── test_loadconf.cbl
│   ├── test_login.cbl
│   ├── trial_menu.cbl
│   ├── trial_list.cbl
│   ├── trial_view.cbl
│   ├── request_user.cbl
│   ├── trial_list.tmp
│   ├── trial_view.tmp
│   ├── login_result.tmp
│   ├── request_user.tmp
│   └── bin/
│       ├── LOADCONF.so
│       ├── LOGIN.so
│       ├── test_loadconf
│       ├── test_login
│       ├── trial_menu
│       ├── trial_list
│       ├── trial_view
│       └── request_user
└── sources/
    ├── rebec_cobol_schema.sql
    ├── rebec_cobol_access_control.sql
    ├── import_ictrp_xml_to_rebec_cobol_v2_savepoint.py
    ├── RBR-ictrp-ALL.xml
    ├── RBR-24p8wdj-ictrp.xml
    └── import_failed_trials_YYYYMMDD_HHMMSS.log
```

Arquivos que **não devem ir para o Git**:

```text
codes/db.conf
codes/bin/
codes/*.tmp
sources/RBR-ictrp-ALL.xml
sources/import_failed_trials_*.log
__pycache__/
*.pyc
```

O arquivo `RBR-24p8wdj-ictrp.xml` pode ser mantido no Git como XML pequeno de exemplo.

---

## Tecnologias utilizadas

* **GnuCOBOL**
* **PostgreSQL**
* **Python 3**
* **psql**
* **Linux / Ubuntu**
* **Shell script**

No estado atual, a integração COBOL/PostgreSQL é feita de forma simples e didática: os programas COBOL chamam o comando `psql` via `CALL "SYSTEM"` e leem arquivos temporários gerados pelas consultas.

Fluxo atual:

```text
COBOL
  -> CALL "SYSTEM"
  -> psql
  -> PostgreSQL
  -> arquivo temporário
  -> leitura sequencial em COBOL
  -> exibição em terminal
```

Essa abordagem foi escolhida por simplicidade didática. No futuro, a integração pode evoluir para:

* ESQL/C;
* GixSQL;
* chamadas via biblioteca C;
* acesso direto com PostgreSQL libpq;
* TUI com SCREEN SECTION;
* interface mais próxima de sistemas transacionais legados.

---

## Criação do banco PostgreSQL

Crie o banco:

```bash
createdb rebec_cobol
```

Depois execute o script principal:

```bash
psql -U seu_usuario -d rebec_cobol -f sources/rebec_cobol_schema.sql
```

Exemplo:

```bash
psql -U diego -d rebec_cobol -f sources/rebec_cobol_schema.sql
```

O script cria o schema:

```text
rebec_cobol
```

E também cria:

* tabelas principais;
* tabelas de vocabulário;
* inserts iniciais;
* funções auxiliares;
* views para consulta dos dados;
* estrutura simplificada baseada no XML ICTRP.

Teste:

```bash
psql -U diego -d rebec_cobol -c "SELECT COUNT(*) FROM rebec_cobol.trial;"
```

---

## Controle de acesso

O controle de acesso é criado pelo script:

```text
sources/rebec_cobol_access_control.sql
```

Execute após o script principal do banco:

```bash
psql -U diego -d rebec_cobol -f sources/rebec_cobol_access_control.sql
```

Esse script adiciona a estrutura inicial de autenticação e autorização da aplicação COBOL.

### Tabelas adicionadas

#### `app_role`

Tabela de perfis da aplicação.

Perfis previstos:

```text
guest
registrant
reviewer
admin
```

#### `app_user`

Tabela de usuários internos da aplicação.

Campos principais:

```text
username
password_hash
full_name
email
role_id
user_status
requested_role
approved_by
approved_at
last_login_at
```

Status previstos:

```text
pending
active
rejected
disabled
```

#### `app_user_request`

Tabela de solicitações de acesso.

Usada por usuários não logados que desejam solicitar permissão como:

```text
registrant
reviewer
```

Campos principais:

```text
full_name
email
requested_username
requested_role
request_reason
request_status
reviewed_by
reviewed_at
review_comment
```

#### `app_login_log`

Tabela para auditoria de tentativas de login.

Campos principais:

```text
user_id
username_attempt
login_success
message
created_at
```

---

### Alterações na tabela `trial`

O script de controle de acesso também adiciona colunas à tabela `trial`:

```text
created_by_user_id
submitted_by_user_id
reviewed_by_user_id
submitted_at
reviewed_at
```

Esses campos permitem relacionar registros de ensaios clínicos aos usuários internos da aplicação.

---

### Views adicionadas

#### `vw_pending_user_requests`

Lista solicitações de usuários ainda pendentes de aprovação.

#### `vw_active_users`

Lista usuários ativos da aplicação com seus respectivos perfis.

---

### Função de login

A autenticação é feita pela função PostgreSQL:

```text
rebec_cobol.app_login(username, password)
```

Ela retorna:

```text
login_success
user_id
username
full_name
role_code
message
```

Exemplo:

```bash
psql -U diego -d rebec_cobol -At -F '|' -c "SELECT * FROM rebec_cobol.app_login('admin', '123456');"
```

Saída esperada:

```text
t|1|admin|System Administrator|admin|Login successful
```

O projeto usa `pgcrypto` para armazenar senha com hash usando `crypt()` e `gen_salt()`.

Dependendo do schema onde a extensão foi criada, as funções podem estar em:

```text
public.crypt
public.gen_salt
```

ou:

```text
rebec_cobol.crypt
rebec_cobol.gen_salt
```

Confira com:

```sql
SELECT n.nspname AS schema_name, p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN ('crypt', 'gen_salt')
ORDER BY p.proname, n.nspname;
```

---

## Configuração do banco para os programas COBOL

Os programas COBOL não devem conter usuário, banco, host ou schema fixos no código.

A configuração é feita pelo arquivo:

```text
codes/db.conf
```

O repositório possui apenas um modelo:

```text
codes/db.conf.example
```

### Exemplo de `db.conf.example`

```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=rebec_cobol
DB_USER=your_user
DB_SCHEMA=rebec_cobol
```

Para criar sua configuração local:

```bash
cd codes
cp db.conf.example db.conf
vim db.conf
```

Exemplo real:

```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=rebec_cobol
DB_USER=diego
DB_SCHEMA=rebec_cobol
```

O arquivo `db.conf` deve ficar fora do Git.

---

## Senha do PostgreSQL

A senha **não deve ficar no código COBOL** e também **não deve ficar no `db.conf`**.

Use `~/.pgpass`.

Crie o arquivo:

```bash
vim ~/.pgpass
```

Formato:

```text
host:porta:banco:usuario:senha
```

Exemplo:

```text
localhost:5432:rebec_cobol:diego:SUA_SENHA_AQUI
```

Ajuste a permissão:

```bash
chmod 600 ~/.pgpass
```

Teste:

```bash
psql -h localhost -p 5432 -U diego -d rebec_cobol -c "SELECT COUNT(*) FROM rebec_cobol.trial;"
```

Se não pedir senha, está funcionando.

---

## Importação dos dados ICTRP

O diretório `sources/` contém o script de importação:

```text
sources/import_ictrp_xml_to_rebec_cobol_v2_savepoint.py
```

Ele lê um XML no formato:

```xml
<root>
  <trials>
    <trial>
      ...
    </trial>
    <trial>
      ...
    </trial>
  </trials>
</root>
```

E insere os dados nas tabelas do schema `rebec_cobol`.

### Teste com poucos registros

```bash
python3 sources/import_ictrp_xml_to_rebec_cobol_v2_savepoint.py \
  --xml sources/RBR-ictrp-ALL.xml \
  --dsn "host=localhost port=5432 dbname=rebec_cobol user=diego" \
  --limit 5 \
  --dry-run
```

O `--dry-run` testa a importação e faz rollback no final.

### Importação real

```bash
python3 sources/import_ictrp_xml_to_rebec_cobol_v2_savepoint.py \
  --xml sources/RBR-ictrp-ALL.xml \
  --dsn "host=localhost port=5432 dbname=rebec_cobol user=diego"
```

O script usa `SAVEPOINT`, então se um ensaio falhar, apenas aquele registro é revertido. Os demais continuam sendo importados.

Ao final, ele informa:

```text
Import finished. Imported: XXXX. Failed: YY.
```

Os registros com falha são gravados em um log como:

```text
sources/import_failed_trials_YYYYMMDD_HHMMSS.log
```

### Conferir a importação

```bash
psql -U diego -d rebec_cobol -c "SELECT COUNT(*) FROM rebec_cobol.trial;"
```

Exemplo esperado após carregar a base de teste:

```text
9265
```

---

## Módulo de configuração COBOL

O projeto usa um módulo COBOL reutilizável:

```text
codes/LOADCONF.cbl
```

Ele lê:

```text
codes/db.conf
```

e preenche a estrutura definida em:

```text
codes/db_config.cpy
```

Campos carregados:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_SCHEMA
DB_STATUS
DB_MESSAGE
```

Esse padrão deve ser seguido por todos os programas COBOL que acessarem o banco.

---

## Sessão da aplicação

A sessão do usuário logado é definida em:

```text
codes/session.cpy
```

Campos principais:

```text
SESSION-LOGGED-IN
SESSION-USER-ID
SESSION-USERNAME
SESSION-FULL-NAME
SESSION-ROLE
SESSION-STATUS
SESSION-MESSAGE
```

Esse copybook permite que o menu principal e os programas protegidos saibam quem está logado e qual é o perfil do usuário.

---

## Programas COBOL disponíveis

### `trial_menu.cbl`

Menu principal do sistema.

Atualmente executa:

```text
1 - List trials
2 - View trial
```

Módulos previstos:

```text
3 - Request user access
4 - Login
5 - Insert new trial
6 - Review / approve trial
7 - Reports
```

No futuro, o menu deverá mudar dinamicamente conforme o perfil:

```text
guest
registrant
reviewer
admin
```

---

### `trial_list.cbl`

Lista os ensaios clínicos de forma paginada.

Comandos disponíveis:

```text
N - Next page
P - Previous page
V - View trial
Q - Quit
```

A consulta usa `LIMIT` e `OFFSET` no PostgreSQL.

Regra planejada:

```text
Para usuário público, listar somente status approved/published.
```

---

### `trial_view.cbl`

Permite consultar um ensaio por:

```text
1 - Database ID
2 - Trial ID / RBR
```

Exibe:

* database ID;
* RBR;
* UTRN;
* status;
* URL pública;
* contato público;
* datas principais;
* tamanho amostral;
* status de recrutamento;
* tipo de estudo;
* desenho do estudo;
* fase;
* patrocinador principal;
* título público;
* título científico;
* condições de saúde.

Regra planejada:

```text
Para usuário público, visualizar somente status approved/published.
```

---

### `request_user.cbl`

Programa usado por usuários não logados para solicitar acesso ao sistema.

Permite solicitar perfil:

```text
registrant
reviewer
```

Grava a solicitação na tabela:

```text
rebec_cobol.app_user_request
```

O admin deverá aprovar ou rejeitar a solicitação em módulo futuro.

---

### `LOGIN.cbl`

Módulo COBOL de login.

Não é executado diretamente como programa principal. Ele deve ser chamado por outros programas.

Exemplo conceitual:

```cobol
CALL "LOGIN" USING APP-SESSION WS-REQUIRED-ROLE
```

O módulo:

* solicita username;
* solicita password;
* chama `rebec_cobol.app_login`;
* lê o retorno do PostgreSQL;
* preenche a sessão COBOL;
* valida se o usuário possui o perfil exigido.

O módulo é compilado como `.so`:

```bash
cobc -m -free -o bin/LOGIN.so LOGIN.cbl
```

---

### `test_login.cbl`

Programa de teste do módulo de login.

Executa o `LOGIN.so` e exibe:

```text
Status
Message
Logged in
User ID
Username
Full name
Role
```

---

### `LOADCONF.cbl`

Módulo reutilizável para carregar configurações do banco.

Não deve ser executado diretamente.

Correto:

```cobol
CALL "LOADCONF" USING DB-CONFIG
```

Incorreto:

```bash
./bin/LOADCONF.so
```

---

## Compilação

Entre no diretório `codes/`:

```bash
cd codes
```

Crie o diretório de binários:

```bash
mkdir -p bin
```

Compile os módulos compartilhados:

```bash
cobc -m -free -o bin/LOADCONF.so LOADCONF.cbl
cobc -m -free -o bin/LOGIN.so LOGIN.cbl
```

Compile os programas principais:

```bash
cobc -x -free -o bin/test_loadconf test_loadconf.cbl
cobc -x -free -o bin/test_login test_login.cbl
cobc -x -free -o bin/request_user request_user.cbl
cobc -x -free -o bin/trial_list trial_list.cbl
cobc -x -free -o bin/trial_view trial_view.cbl
cobc -x -free -o bin/trial_menu trial_menu.cbl
```

---

## Variável `COB_LIBRARY_PATH`

Como `LOADCONF` e `LOGIN` são módulos compartilhados, o GnuCOBOL precisa saber onde encontrar:

```text
bin/LOADCONF.so
bin/LOGIN.so
```

Antes de executar os programas, use:

```bash
export COB_LIBRARY_PATH=./bin
```

Teste configuração:

```bash
./bin/test_loadconf
```

Teste login:

```bash
./bin/test_login
```

Saída esperada para login válido:

```text
Status    : OK
Message   : Login successful
Logged in : Y
User ID   : 1
Username  : admin
Full name : System Administrator
Role      : admin
```

---

## Script de execução `run.sh`

Para não precisar exportar `COB_LIBRARY_PATH` manualmente toda vez, o projeto usa:

```text
codes/run.sh
```

Conteúdo esperado:

```bash
#!/bin/bash

cd "$(dirname "$0")"

export COB_LIBRARY_PATH="$PWD/bin"

./bin/trial_menu
```

Dê permissão de execução:

```bash
chmod +x run.sh
```

Execute o sistema:

```bash
./run.sh
```

---

## Primeiro teste do sistema

Depois de:

1. criar o banco;
2. rodar `rebec_cobol_schema.sql`;
3. rodar `rebec_cobol_access_control.sql`;
4. importar os dados;
5. criar o `db.conf`;
6. configurar a senha no `~/.pgpass`;
7. compilar os programas;

rode:

```bash
cd codes
./run.sh
```

A tela inicial será semelhante a:

```text
REBEC COBOL DATABASE SYSTEM

1 - List trials
2 - View trial by database ID or RBR
3 - Insert new trial              [coming soon]
4 - Review / approve trial        [coming soon]
5 - Reports                       [coming soon]
0 - Exit
```

---

## `.gitignore` recomendado

Na raiz do projeto:

```gitignore
codes/bin/
codes/*.tmp
codes/db.conf
*.tmp

sources/RBR-ictrp-ALL.xml
sources/import_failed_trials_*.log

__pycache__/
*.pyc
```

Observação:

```text
sources/RBR-ictrp-ALL.xml
```

deve ficar ignorado porque é o XML grande da base completa.

O arquivo pequeno de exemplo pode ser versionado:

```text
sources/RBR-24p8wdj-ictrp.xml
```

Antes do push:

```bash
git status --short
```

Confira se não aparecem:

```text
codes/db.conf
codes/bin/
codes/*.tmp
sources/RBR-ictrp-ALL.xml
sources/import_failed_trials_*.log
```

---

## Comandos úteis

Conferir quantidade de ensaios:

```bash
psql -U diego -d rebec_cobol -c "SELECT COUNT(*) FROM rebec_cobol.trial;"
```

Consultar primeiros registros:

```bash
psql -U diego -d rebec_cobol -c "
SELECT id, trial_id, status, left(public_title, 80)
FROM rebec_cobol.trial
ORDER BY id
LIMIT 10;
"
```

Consultar a view ICTRP:

```bash
psql -U diego -d rebec_cobol -c "
SELECT id, trial_id, study_type, study_design, recruitment_status
FROM rebec_cobol.vw_trial_ictrp_main
LIMIT 10;
"
```

Testar login direto no PostgreSQL:

```bash
psql -U diego -d rebec_cobol -At -F '|' -c "
SELECT * FROM rebec_cobol.app_login('admin', '123456');
"
```

Testar configuração COBOL:

```bash
cd codes
export COB_LIBRARY_PATH=./bin
./bin/test_loadconf
```

Testar login COBOL:

```bash
cd codes
export COB_LIBRARY_PATH=./bin
./bin/test_login
```

Rodar sistema:

```bash
cd codes
./run.sh
```

---

## Observações de arquitetura

Esta versão usa integração simples entre COBOL e PostgreSQL via `psql`. Esse desenho foi escolhido para acelerar o aprendizado e permitir evolução incremental.

A aplicação também foi pensada para simular um sistema de terminal legado com controle de acesso interno. Assim, um servidor pode disponibilizar a aplicação via SSH com um usuário técnico, enquanto os usuários reais são controlados dentro da própria aplicação COBOL/PostgreSQL.

Modelo conceitual:

```text
Usuário remoto
  -> SSH
  -> aplicação COBOL
  -> login interno
  -> sessão COBOL
  -> permissões por perfil
  -> PostgreSQL
```

No futuro, o projeto pode evoluir para:

* autenticação completa por perfil;
* administração de usuários;
* submissão de ensaios;
* revisão e aprovação;
* trilha de auditoria;
* relatórios;
* exportação em formato ICTRP;
* deploy em ambiente semelhante a mainframe;
* integração com banco via ESQL/C, GixSQL ou libpq.

---

<a name="english"></a>

## About the Project

This project is a research, learning, and architecture initiative to build a simplified **Clinical Trials Registry** inspired by the **Brazilian Clinical Trials Registry — ReBEC**, using **GnuCOBOL**, **PostgreSQL**, and legacy transactional system concepts.

The goal is not to replace the real ReBEC system. The goal is to study how a clinical trial registration, visualization, review, approval, and publication system could be implemented in COBOL with a terminal-based interface and relational storage.

The current implementation is based on a simplified **ICTRP/WHO XML** data model and allows loading real clinical trial records into PostgreSQL and navigating them through a COBOL terminal application.

This project also explores a broader architectural idea: countries, public institutions, universities, or national research networks could build clinical trial registries using robust traditional technologies such as **COBOL**, **mainframes**, relational databases, and auditable transactional systems.

---

## Current implementation

The project currently includes:

* PostgreSQL schema creation script;
* clinical trial tables;
* vocabulary tables and seed data;
* Python XML importer with savepoint support;
* reusable COBOL configuration module;
* COBOL main menu;
* paginated trial listing;
* trial detail view by internal ID or RBR;
* external database configuration;
* password kept outside the source code;
* initial access control schema;
* COBOL login module;
* COBOL session copybook;
* login test program;
* initial role support for `guest`, `registrant`, `reviewer`, and `admin`.

---

## Access control

The access control structure is created by:

```text
sources/rebec_cobol_access_control.sql
```

It adds:

```text
app_role
app_user
app_user_request
app_login_log
```

It also adds user-related columns to the `trial` table:

```text
created_by_user_id
submitted_by_user_id
reviewed_by_user_id
submitted_at
reviewed_at
```

The login function is:

```text
rebec_cobol.app_login(username, password)
```

It returns:

```text
login_success
user_id
username
full_name
role_code
message
```

---

## Main COBOL modules

```text
LOADCONF.cbl       -> reusable database configuration loader
LOGIN.cbl          -> reusable login module
session.cpy        -> user session structure
trial_menu.cbl     -> main terminal menu
trial_list.cbl     -> paginated public trial list
trial_view.cbl     -> trial detail visualization
request_user.cbl   -> access request form
test_loadconf.cbl  -> configuration test
test_login.cbl     -> login test
```

---

## Technical Stack

* **GnuCOBOL**
* **PostgreSQL**
* **Python 3**
* **psql**
* **Linux / Ubuntu**
* **Shell script**

At this stage, COBOL/PostgreSQL integration is implemented by calling `psql` from COBOL using `CALL "SYSTEM"` and reading temporary files generated by SQL queries.

---

## Quick start

Create the database:

```bash
createdb rebec_cobol
```

Run the main schema script:

```bash
psql -U your_user -d rebec_cobol -f sources/rebec_cobol_schema.sql
```

Run the access control script:

```bash
psql -U your_user -d rebec_cobol -f sources/rebec_cobol_access_control.sql
```

Create local DB config:

```bash
cd codes
cp db.conf.example db.conf
vim db.conf
```

Example:

```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=rebec_cobol
DB_USER=your_user
DB_SCHEMA=rebec_cobol
```

Configure PostgreSQL password using `~/.pgpass`:

```text
localhost:5432:rebec_cobol:your_user:your_password
```

Then:

```bash
chmod 600 ~/.pgpass
```

Import XML data:

```bash
python3 sources/import_ictrp_xml_to_rebec_cobol_v2_savepoint.py \
  --xml sources/RBR-ictrp-ALL.xml \
  --dsn "host=localhost port=5432 dbname=rebec_cobol user=your_user"
```

Compile:

```bash
cd codes
mkdir -p bin

cobc -m -free -o bin/LOADCONF.so LOADCONF.cbl
cobc -m -free -o bin/LOGIN.so LOGIN.cbl

cobc -x -free -o bin/test_loadconf test_loadconf.cbl
cobc -x -free -o bin/test_login test_login.cbl
cobc -x -free -o bin/request_user request_user.cbl
cobc -x -free -o bin/trial_list trial_list.cbl
cobc -x -free -o bin/trial_view trial_view.cbl
cobc -x -free -o bin/trial_menu trial_menu.cbl
```

Run:

```bash
./run.sh
```

---

## Recommended `.gitignore`

```gitignore
codes/bin/
codes/*.tmp
codes/db.conf
*.tmp

sources/RBR-ictrp-ALL.xml
sources/import_failed_trials_*.log

__pycache__/
*.pyc
```

---

## License and purpose

This project is intended for learning, architecture exploration, and software engineering study.

It is inspired by the clinical trial registry domain, but it is not the official ReBEC system.

