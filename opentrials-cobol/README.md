# ReBEC COBOL Architecture

[Português](#português) | [English](#english)

---

<a name="português"></a>

## Sobre o Projeto

Este projeto é uma iniciativa de estudo e desenvolvimento para criar uma versão simplificada do **ReBEC** — Registro Brasileiro de Ensaios Clínicos — utilizando **GnuCOBOL** e **PostgreSQL**.

O objetivo principal não é substituir o sistema real, mas estudar COBOL aplicado a um domínio real de alta importância: registro, consulta, revisão, aprovação e publicação de ensaios clínicos.

A aplicação trabalha com uma modelagem simplificada baseada no XML do **ICTRP/WHO**, permitindo carregar registros reais em um banco PostgreSQL e navegar pelos dados por meio de uma interface de terminal escrita em COBOL.

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
* Implementar módulos simples de:

  * listagem de ensaios;
  * consulta por ID interno ou RBR;
  * futura inserção de registros;
  * futura revisão/aprovação;
  * futura área de relatórios.

---

## Estado atual do projeto

Atualmente o projeto já possui:

* script PostgreSQL para criação do banco e vocabulários;
* script Python para importar XML ICTRP com vários ensaios;
* módulo COBOL de configuração reutilizável;
* menu principal em COBOL;
* listagem paginada de ensaios;
* visualização detalhada de ensaio por ID ou RBR;
* configuração externa de conexão com banco;
* senha fora do código-fonte.

---

## Estrutura do projeto

Estrutura esperada:

```text
opentrials-cobol/
├── README.md
├── .gitignore
├── codes/
│   ├── LOADCONF.cbl
│   ├── db_config.cpy
│   ├── db.conf.example
│   ├── db.conf
│   ├── run.sh
│   ├── test_loadconf.cbl
│   ├── trial_menu.cbl
│   ├── trial_list.cbl
│   ├── trial_view.cbl
│   ├── trial_list.tmp
│   ├── trial_view.tmp
│   └── bin/
│       ├── LOADCONF.so
│       ├── test_loadconf
│       ├── trial_menu
│       ├── trial_list
│       └── trial_view
└── sources/
    ├── rebec_cobol_schema.sql
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
```

---

## Tecnologias utilizadas

* **GnuCOBOL**
* **PostgreSQL**
* **Python 3**
* **psql**
* **Linux / Ubuntu**
* **Shell script**

No estado atual, a integração COBOL/PostgreSQL é feita de forma simples e didática: os programas COBOL chamam o comando `psql` via `CALL "SYSTEM"` e leem arquivos temporários gerados pelas consultas.

---

## Configuração inicial

### 1. Instalar dependências

No Ubuntu:

```bash
sudo apt update
sudo apt install gnucobol postgresql-client python3 python3-pip
```

Para o script de importação:

```bash
pip install psycopg2-binary
```

Ou, se preferir via APT:

```bash
sudo apt install python3-psycopg2
```

---

## Criação do banco PostgreSQL

Crie o banco:

```bash
createdb rebec_cobol
```

Depois execute o script de criação:

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

Há duas formas recomendadas.

### Opção 1: usar `~/.pgpass`

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

### Opção 2: usar variável de ambiente

Alternativamente:

```bash
export PGPASSWORD='SUA_SENHA_AQUI'
```

Essa opção funciona, mas para uso contínuo o `~/.pgpass` é mais adequado.

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

Antes de importar tudo, rode com `--limit` e `--dry-run`:

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

## Compilação

Entre no diretório `codes/`:

```bash
cd codes
```

Crie o diretório de binários se ele ainda não existir:

```bash
mkdir -p bin
```

Compile o módulo de configuração:

```bash
cobc -m -free -o bin/LOADCONF.so LOADCONF.cbl
```

Compile os programas principais:

```bash
cobc -x -free -o bin/test_loadconf test_loadconf.cbl
cobc -x -free -o bin/trial_list trial_list.cbl
cobc -x -free -o bin/trial_view trial_view.cbl
cobc -x -free -o bin/trial_menu trial_menu.cbl
```

---

## Variável `COB_LIBRARY_PATH`

Como `LOADCONF` é um módulo compartilhado, o GnuCOBOL precisa saber onde encontrar:

```text
bin/LOADCONF.so
```

Antes de executar os programas, use:

```bash
export COB_LIBRARY_PATH=./bin
```

Teste:

```bash
./bin/test_loadconf
```

Saída esperada:

```text
Status : OK
Message: Configuration loaded
Host   : localhost
Port   : 5432
Name   : rebec_cobol
User   : diego
Schema : rebec_cobol
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
2. rodar o script SQL;
3. importar os dados;
4. criar o `db.conf`;
5. configurar a senha no `~/.pgpass`;
6. compilar os programas;

rode:

```bash
cd codes
./run.sh
```

A tela inicial será:

```text
REBEC COBOL DATABASE SYSTEM

1 - List trials
2 - View trial by database ID or RBR
3 - Insert new trial              [coming soon]
4 - Review / approve trial       [coming soon]
5 - Reports                      [coming soon]
0 - Exit
```

---

## Programas disponíveis

### `trial_menu.cbl`

Menu principal do sistema.

Executa:

```text
1 - List trials
2 - View trial
```

Módulos futuros:

```text
3 - Insert new trial
4 - Review / approve trial
5 - Reports
```

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

Antes do primeiro push:

```bash
git status
```

Confira se não aparecem:

```text
codes/db.conf
codes/bin/
codes/trial_list.tmp
codes/trial_view.tmp
sources/RBR-ictrp-ALL.xml
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

Testar configuração COBOL:

```bash
cd codes
export COB_LIBRARY_PATH=./bin
./bin/test_loadconf
```

Rodar sistema:

```bash
cd codes
./run.sh
```

---

## Observações de arquitetura

Esta versão usa integração simples entre COBOL e PostgreSQL via `psql`. Esse desenho foi escolhido para acelerar o aprendizado e permitir evolução incremental.

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

No futuro, a integração pode evoluir para:

* ESQL/C;
* GixSQL;
* chamadas via biblioteca C;
* acesso direto com PostgreSQL libpq;
* TUI com SCREEN SECTION;
* interface mais próxima de sistemas transacionais legados.

---

<a name="english"></a>

## About the Project

This project is a research and learning initiative to build a simplified version of the **Brazilian Clinical Trials Registry — ReBEC** using **GnuCOBOL** and **PostgreSQL**.

The goal is not to replace the real system, but to study COBOL using a realistic domain: clinical trial registration, visualization, review, approval, reporting, and public publication.

The current implementation is based on a simplified ICTRP/WHO XML data model and allows loading real trial data into PostgreSQL and navigating it through a COBOL terminal application.

---

## About the author

This project is developed by **Diego Tostes**, a technology professional with experience in mission-critical systems, data engineering, Linux infrastructure, databases, automation, and high-availability digital platforms.

Diego has worked for more than a decade in environments that require reliability, traceability, operational continuity, and technical rigor. In the context of the **Brazilian Clinical Trials Registry — ReBEC**, he works on system evolution, data modeling, integration with international standards, ICTRP/WHO data export, and the development of solutions to support clinical trial review and publication workflows.

This project is part of his learning journey in **COBOL, legacy systems, mainframe concepts, and transactional system architecture**, connecting classical computing foundations with modern technologies such as PostgreSQL, Linux, Python, and data automation.

LinkedIn: [linkedin.com/in/diegotostes](https://www.linkedin.com/in/diegotostes/)

---

## Current implementation

The project currently includes:

* PostgreSQL schema creation script;
* vocabulary tables and seed data;
* Python XML importer;
* reusable COBOL configuration module;
* COBOL main menu;
* paginated trial listing;
* trial detail view by internal ID or RBR;
* external database configuration;
* password kept outside the source code.

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

Run the schema script:

```bash
psql -U your_user -d rebec_cobol -f sources/rebec_cobol_schema.sql
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

cobc -x -free -o bin/test_loadconf test_loadconf.cbl
cobc -x -free -o bin/trial_list trial_list.cbl
cobc -x -free -o bin/trial_view trial_view.cbl
cobc -x -free -o bin/trial_menu trial_menu.cbl
```

Run:

```bash
./run.sh
```

---

## License and purpose

This project is intended for learning, architecture exploration, and software engineering study.

It is inspired by the clinical trial registry domain, but it is not the official ReBEC system.

