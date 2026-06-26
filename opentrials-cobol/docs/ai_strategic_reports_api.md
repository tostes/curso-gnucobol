# ReBEC COBOL AI Strategic Reports API

# API de Relatórios Estratégicos com IA do ReBEC COBOL

---

## Português

### 1. Visão geral

Este documento descreve a integração entre o sistema experimental **ReBEC COBOL**, o banco de dados **PostgreSQL**, uma API em **FastAPI** e a geração de relatórios estratégicos com apoio de **IA**.

O objetivo desta integração é permitir que um sistema COBOL em terminal consiga solicitar, visualizar e reutilizar relatórios analíticos gerados a partir da base pública de ensaios clínicos do ReBEC.

A arquitetura evita enviar registros brutos para a IA. Em vez disso, o PostgreSQL gera um conjunto consolidado de indicadores em formato JSON, contendo estatísticas agregadas, rankings, sinais de governança e indicadores de qualidade dos dados. A IA interpreta esse JSON e produz um relatório estratégico em linguagem natural.

---

### 2. Arquitetura geral

O fluxo principal é:

```text
COBOL terminal
    ↓
curl
    ↓
FastAPI
    ↓
PostgreSQL
    ↓
JSON analítico consolidado
    ↓
OpenAI API
    ↓
Relatório Markdown / HTML / JSON
    ↓
COBOL terminal
```

Cada camada tem uma responsabilidade específica:

| Camada          | Responsabilidade                               |
| --------------- | ---------------------------------------------- |
| COBOL           | Interface terminal para o usuário              |
| curl            | Comunicação simples entre COBOL e HTTP         |
| FastAPI         | Orquestração da geração e cache dos relatórios |
| PostgreSQL      | Cálculo dos indicadores analíticos             |
| OpenAI          | Interpretação estratégica dos indicadores      |
| Arquivos locais | Armazenamento dos relatórios gerados           |

---

### 3. Componentes criados

#### 3.1 API FastAPI

Arquivo principal:

```text
api/app/main.py
```

A API expõe os seguintes endpoints:

```text
GET    /health
GET    /ai/cache/status
GET    /ai/dataset
POST   /ai/reports/strategic-insights/generate
GET    /ai/reports/strategic-insights/latest
DELETE /ai/reports/strategic-insights/cache
```

---

### 4. Endpoints

#### 4.1 Health check

```text
GET /health
```

Verifica se a API está rodando.

Exemplo:

```bash
curl -s http://127.0.0.1:8000/health | jq
```

Retorno esperado:

```json
{
  "status": "ok",
  "service": "ReBEC COBOL AI API",
  "version": "0.2.0",
  "cache_max_age_hours": 24
}
```

---

#### 4.2 Status do cache

```text
GET /ai/cache/status
```

Verifica se já existe um relatório gerado e se ele ainda é válido.

Exemplo:

```bash
curl -s http://127.0.0.1:8000/ai/cache/status | jq
```

Este endpoint **não chama a OpenAI** e **não consulta o PostgreSQL**. Ele apenas verifica os arquivos locais de relatório.

---

#### 4.3 Dataset analítico

```text
GET /ai/dataset
```

Retorna o JSON consolidado produzido pelo PostgreSQL.

Exemplo:

```bash
curl -s http://127.0.0.1:8000/ai/dataset | jq
```

Este endpoint consulta a função PostgreSQL:

```sql
SELECT rebec_cobol.fn_ai_registry_insight_dataset();
```

O dataset contém indicadores como:

* total de ensaios;
* ensaios públicos;
* ensaios registrados no ano;
* distribuição por status de recrutamento;
* top patrocinadores;
* top condições de saúde;
* indicadores de qualidade dos dados;
* sinais de recrutamento possivelmente desatualizado;
* inteligência patrocinador × condição de saúde.

---

#### 4.4 Gerar ou reutilizar relatório estratégico

```text
POST /ai/reports/strategic-insights/generate
```

Este é o endpoint principal.

Ele verifica se já existe um relatório válido com menos de 24 horas. Se existir, retorna o relatório em cache. Se não existir, ou se o relatório estiver expirado, a API consulta o PostgreSQL e chama a OpenAI para gerar um novo relatório.

Exemplo:

```bash
curl -s -X POST http://127.0.0.1:8000/ai/reports/strategic-insights/generate | jq
```

Com cache válido, o retorno será semelhante a:

```json
{
  "status": "success",
  "generated": false,
  "cache_used": true,
  "message": "Using cached AI Strategic Registry Insights Report. OpenAI was not called."
}
```

Quando um novo relatório é gerado:

```json
{
  "status": "success",
  "generated": true,
  "cache_used": false,
  "message": "AI Strategic Registry Insights Report generated successfully. OpenAI was called."
}
```

---

#### 4.5 Forçar nova geração

Para ignorar o cache e gerar um novo relatório:

```bash
curl -s -X POST "http://127.0.0.1:8000/ai/reports/strategic-insights/generate?force=true" | jq
```

Também é possível limpar relatórios antigos mantendo apenas os mais recentes:

```bash
curl -s -X POST "http://127.0.0.1:8000/ai/reports/strategic-insights/generate?force=true&cleanup=true" | jq
```

Esta opção deve ser usada com cuidado, pois chama novamente a OpenAI.

---

#### 4.6 Visualizar último relatório

Markdown:

```bash
curl -s http://127.0.0.1:8000/ai/reports/strategic-insights/latest
```

HTML:

```bash
curl -s "http://127.0.0.1:8000/ai/reports/strategic-insights/latest?format=html"
```

JSON de metadados:

```bash
curl -s "http://127.0.0.1:8000/ai/reports/strategic-insights/latest?format=json" | jq
```

---

#### 4.7 Limpar cache

```text
DELETE /ai/reports/strategic-insights/cache
```

Remove apenas os arquivos `latest`:

```text
strategic_insights_latest.md
strategic_insights_latest.html
strategic_insights_latest.json
```

Exemplo:

```bash
curl -s -X DELETE http://127.0.0.1:8000/ai/reports/strategic-insights/cache | jq
```

Os relatórios históricos com timestamp são preservados.

---

### 5. Regra de cache de 24 horas

Para evitar custo desnecessário com chamadas à OpenAI, a API usa uma regra de cache.

A OpenAI só é chamada quando:

1. não existe relatório anterior no diretório `api/reports/`; ou
2. o relatório mais recente tem mais de 24 horas; ou
3. o usuário força uma nova geração com `force=true`.

A duração do cache é configurada no arquivo:

```text
api/.env
```

Com a variável:

```env
CACHE_MAX_AGE_HOURS=24
```

Essa regra é importante porque os dados de origem são praticamente os mesmos ao longo do dia. Assim, não faz sentido gerar múltiplos relatórios com IA para o mesmo conjunto de indicadores.

---

### 6. Arquivos de relatório gerados

Os relatórios são salvos em:

```text
api/reports/
```

A API gera arquivos com timestamp:

```text
strategic_insights_YYYYMMDD_HHMMSS.md
strategic_insights_YYYYMMDD_HHMMSS.html
strategic_insights_YYYYMMDD_HHMMSS.json
```

E também mantém sempre os arquivos mais recentes:

```text
strategic_insights_latest.md
strategic_insights_latest.html
strategic_insights_latest.json
```

Os arquivos `latest` são usados pelo COBOL para abrir rapidamente o último relatório disponível.

---

### 7. Programa COBOL

Arquivo:

```text
codes/ai_reports_menu.cbl
```

Este programa fornece uma interface terminal para acessar os relatórios estratégicos de IA.

Opções disponíveis:

```text
1 - Check API health
2 - Check report cache status
3 - Generate/reuse AI strategic report
4 - View latest Markdown report
5 - Open latest HTML report
6 - Clear latest report cache
7 - Force new AI report generation
Q - Quit
```

O programa COBOL usa `CALL "SYSTEM"` para executar comandos `curl`, por exemplo:

```bash
curl -s http://127.0.0.1:8000/health
```

Dessa forma, o COBOL não precisa implementar um cliente HTTP nativo.

---

### 8. Compilação do COBOL

Dentro do diretório `codes`:

```bash
cd ~/cobol/curso-gnucobol/opentrials-cobol/codes

mkdir -p bin

cobc -x -free -o bin/ai_reports_menu ai_reports_menu.cbl
```

Executar:

```bash
export COB_LIBRARY_PATH=$(pwd)/bin

./bin/ai_reports_menu
```

---

### 9. Executando a API

Na raiz do projeto:

```bash
cd ~/cobol/curso-gnucobol/opentrials-cobol

source api/.venv/bin/activate

uvicorn app.main:app \
  --app-dir api \
  --host 127.0.0.1 \
  --port 8000 \
  --reload
```

A API ficará disponível em:

```text
http://127.0.0.1:8000
```

---

### 10. Configuração da API

Arquivo de exemplo:

```text
api/.env.example
```

Variáveis principais:

```env
OPENAI_API_KEY=your_openai_key_here
OPENAI_MODEL=gpt-4.1-mini

REBEC_DB_HOST=localhost
REBEC_DB_PORT=5432
REBEC_DB_NAME=rebec_cobol
REBEC_DB_USER=diego
REBEC_DB_PASSWORD=

REBEC_API_TOKEN=change-this-local-token
CACHE_MAX_AGE_HOURS=24
```

O arquivo real deve ser:

```text
api/.env
```

Esse arquivo **não deve ser enviado ao GitHub**.

---

### 11. Arquivos ignorados pelo Git

Por segurança, os seguintes arquivos e diretórios devem ficar fora do Git:

```text
api/.env
api/.venv/
api/__pycache__/
api/app/__pycache__/
api/reports/
codes/bin/
codes/db.conf
*.pyc
*.so
*.o
*.log
*.tmp
```

Isso evita o envio de:

* chaves da OpenAI;
* configurações locais de banco;
* ambiente virtual Python;
* relatórios gerados;
* binários COBOL;
* arquivos temporários.

---

### 12. Função PostgreSQL principal

A API consome a função:

```sql
SELECT rebec_cobol.fn_ai_registry_insight_dataset();
```

Essa função retorna um JSON consolidado com indicadores estratégicos.

O arquivo SQL correspondente está em:

```text
sources/rebec_cobol_ai_reports_api.sql
```

O objetivo é manter o cálculo analítico dentro do PostgreSQL e deixar a IA responsável apenas pela interpretação textual.

---

### 13. Segurança e privacidade

A arquitetura foi desenhada para reduzir exposição de dados.

Pontos principais:

1. A IA não recebe a base completa de registros brutos.
2. A IA recebe apenas indicadores agregados.
3. Dados de contato não devem ser enviados no dataset.
4. O arquivo `.env` não deve ser versionado.
5. A API pode ser protegida com `REBEC_API_TOKEN`.
6. Relatórios gerados ficam locais em `api/reports/`.

---

### 14. Objetivo estratégico

Esta integração demonstra como um sistema legado ou experimental em COBOL pode ser modernizado sem abandonar o terminal.

O COBOL continua sendo a interface operacional.
O PostgreSQL concentra a lógica analítica.
A FastAPI atua como ponte moderna.
A IA gera interpretações estratégicas a partir de dados consolidados.

O resultado é uma arquitetura híbrida:

```text
Legacy terminal + modern API + database intelligence + AI interpretation
```

---

## English

### 1. Overview

This document describes the integration between the experimental **ReBEC COBOL** system, a **PostgreSQL** database, a **FastAPI** service, and AI-assisted strategic report generation.

The goal is to allow a terminal-based COBOL system to request, view and reuse analytical reports generated from the public ReBEC clinical trials registry database.

The architecture avoids sending raw records to the AI model. Instead, PostgreSQL generates a consolidated JSON dataset containing aggregated statistics, rankings, governance signals and data quality indicators. The AI model interprets this JSON and produces a strategic report in natural language.

---

### 2. General architecture

The main flow is:

```text
COBOL terminal
    ↓
curl
    ↓
FastAPI
    ↓
PostgreSQL
    ↓
Consolidated analytical JSON
    ↓
OpenAI API
    ↓
Markdown / HTML / JSON report
    ↓
COBOL terminal
```

Each layer has a specific responsibility:

| Layer       | Responsibility                              |
| ----------- | ------------------------------------------- |
| COBOL       | Terminal user interface                     |
| curl        | Simple communication between COBOL and HTTP |
| FastAPI     | Report orchestration and cache control      |
| PostgreSQL  | Analytical indicator calculation            |
| OpenAI      | Strategic interpretation of the indicators  |
| Local files | Storage of generated reports                |

---

### 3. Created components

#### 3.1 FastAPI service

Main file:

```text
api/app/main.py
```

The API exposes the following endpoints:

```text
GET    /health
GET    /ai/cache/status
GET    /ai/dataset
POST   /ai/reports/strategic-insights/generate
GET    /ai/reports/strategic-insights/latest
DELETE /ai/reports/strategic-insights/cache
```

---

### 4. Endpoints

#### 4.1 Health check

```text
GET /health
```

Checks whether the API is running.

Example:

```bash
curl -s http://127.0.0.1:8000/health | jq
```

Expected response:

```json
{
  "status": "ok",
  "service": "ReBEC COBOL AI API",
  "version": "0.2.0",
  "cache_max_age_hours": 24
}
```

---

#### 4.2 Cache status

```text
GET /ai/cache/status
```

Checks whether a report already exists and whether it is still valid.

Example:

```bash
curl -s http://127.0.0.1:8000/ai/cache/status | jq
```

This endpoint **does not call OpenAI** and **does not query PostgreSQL**. It only checks local report files.

---

#### 4.3 Analytical dataset

```text
GET /ai/dataset
```

Returns the consolidated JSON generated by PostgreSQL.

Example:

```bash
curl -s http://127.0.0.1:8000/ai/dataset | jq
```

This endpoint calls the PostgreSQL function:

```sql
SELECT rebec_cobol.fn_ai_registry_insight_dataset();
```

The dataset contains indicators such as:

* total trials;
* public trials;
* trials registered in the current year;
* recruitment status distribution;
* top sponsors;
* top health conditions;
* data quality indicators;
* possibly outdated recruitment signals;
* sponsor × health condition intelligence.

---

#### 4.4 Generate or reuse strategic report

```text
POST /ai/reports/strategic-insights/generate
```

This is the main endpoint.

It checks whether a valid report exists and is less than 24 hours old. If it exists, the API returns the cached report. If not, or if the report has expired, the API queries PostgreSQL and calls OpenAI to generate a new report.

Example:

```bash
curl -s -X POST http://127.0.0.1:8000/ai/reports/strategic-insights/generate | jq
```

With a valid cache, the response should look like:

```json
{
  "status": "success",
  "generated": false,
  "cache_used": true,
  "message": "Using cached AI Strategic Registry Insights Report. OpenAI was not called."
}
```

When a new report is generated:

```json
{
  "status": "success",
  "generated": true,
  "cache_used": false,
  "message": "AI Strategic Registry Insights Report generated successfully. OpenAI was called."
}
```

---

#### 4.5 Force new generation

To ignore cache and generate a new report:

```bash
curl -s -X POST "http://127.0.0.1:8000/ai/reports/strategic-insights/generate?force=true" | jq
```

It is also possible to remove older timestamped reports after generation:

```bash
curl -s -X POST "http://127.0.0.1:8000/ai/reports/strategic-insights/generate?force=true&cleanup=true" | jq
```

This option should be used carefully because it calls OpenAI again.

---

#### 4.6 View latest report

Markdown:

```bash
curl -s http://127.0.0.1:8000/ai/reports/strategic-insights/latest
```

HTML:

```bash
curl -s "http://127.0.0.1:8000/ai/reports/strategic-insights/latest?format=html"
```

JSON metadata:

```bash
curl -s "http://127.0.0.1:8000/ai/reports/strategic-insights/latest?format=json" | jq
```

---

#### 4.7 Clear cache

```text
DELETE /ai/reports/strategic-insights/cache
```

Removes only the latest files:

```text
strategic_insights_latest.md
strategic_insights_latest.html
strategic_insights_latest.json
```

Example:

```bash
curl -s -X DELETE http://127.0.0.1:8000/ai/reports/strategic-insights/cache | jq
```

Timestamped historical reports are preserved.

---

### 5. 24-hour cache rule

To avoid unnecessary OpenAI costs, the API uses a cache rule.

OpenAI is called only when:

1. there is no previous report in `api/reports/`; or
2. the latest report is older than 24 hours; or
3. the user forces a new generation with `force=true`.

The cache duration is configured in:

```text
api/.env
```

With the variable:

```env
CACHE_MAX_AGE_HOURS=24
```

This rule is important because the source data usually does not change significantly multiple times per day. Therefore, it is unnecessary to generate multiple AI reports for the same indicator set.

---

### 6. Generated report files

Reports are saved in:

```text
api/reports/
```

The API generates timestamped files:

```text
strategic_insights_YYYYMMDD_HHMMSS.md
strategic_insights_YYYYMMDD_HHMMSS.html
strategic_insights_YYYYMMDD_HHMMSS.json
```

It also keeps the most recent files:

```text
strategic_insights_latest.md
strategic_insights_latest.html
strategic_insights_latest.json
```

The `latest` files are used by COBOL to quickly open the latest available report.

---

### 7. COBOL program

File:

```text
codes/ai_reports_menu.cbl
```

This program provides a terminal interface to access AI strategic reports.

Available options:

```text
1 - Check API health
2 - Check report cache status
3 - Generate/reuse AI strategic report
4 - View latest Markdown report
5 - Open latest HTML report
6 - Clear latest report cache
7 - Force new AI report generation
Q - Quit
```

The COBOL program uses `CALL "SYSTEM"` to execute `curl` commands, for example:

```bash
curl -s http://127.0.0.1:8000/health
```

This avoids the need to implement a native HTTP client in COBOL.

---

### 8. COBOL compilation

Inside the `codes` directory:

```bash
cd ~/cobol/curso-gnucobol/opentrials-cobol/codes

mkdir -p bin

cobc -x -free -o bin/ai_reports_menu ai_reports_menu.cbl
```

Run:

```bash
export COB_LIBRARY_PATH=$(pwd)/bin

./bin/ai_reports_menu
```

---

### 9. Running the API

From the project root:

```bash
cd ~/cobol/curso-gnucobol/opentrials-cobol

source api/.venv/bin/activate

uvicorn app.main:app \
  --app-dir api \
  --host 127.0.0.1 \
  --port 8000 \
  --reload
```

The API will be available at:

```text
http://127.0.0.1:8000
```

---

### 10. API configuration

Example file:

```text
api/.env.example
```

Main variables:

```env
OPENAI_API_KEY=your_openai_key_here
OPENAI_MODEL=gpt-4.1-mini

REBEC_DB_HOST=localhost
REBEC_DB_PORT=5432
REBEC_DB_NAME=rebec_cobol
REBEC_DB_USER=diego
REBEC_DB_PASSWORD=

REBEC_API_TOKEN=change-this-local-token
CACHE_MAX_AGE_HOURS=24
```

The real file should be:

```text
api/.env
```

This file **must not be committed to GitHub**.

---

### 11. Git ignored files

For safety, the following files and directories should remain outside Git:

```text
api/.env
api/.venv/
api/__pycache__/
api/app/__pycache__/
api/reports/
codes/bin/
codes/db.conf
*.pyc
*.so
*.o
*.log
*.tmp
```

This prevents committing:

* OpenAI keys;
* local database configuration;
* Python virtual environment;
* generated reports;
* COBOL binaries;
* temporary files.

---

### 12. Main PostgreSQL function

The API consumes the function:

```sql
SELECT rebec_cobol.fn_ai_registry_insight_dataset();
```

This function returns a consolidated JSON with strategic indicators.

The corresponding SQL file is:

```text
sources/rebec_cobol_ai_reports_api.sql
```

The goal is to keep analytical calculation inside PostgreSQL and let the AI model handle only textual interpretation.

---

### 13. Security and privacy

The architecture was designed to reduce data exposure.

Main points:

1. The AI does not receive the complete raw registry database.
2. The AI receives only aggregated indicators.
3. Contact data should not be sent in the dataset.
4. `.env` must not be versioned.
5. The API can be protected using `REBEC_API_TOKEN`.
6. Generated reports remain local in `api/reports/`.

---

### 14. Strategic purpose

This integration demonstrates how a legacy or experimental COBOL system can be modernized without abandoning the terminal.

COBOL remains the operational interface.
PostgreSQL concentrates analytical logic.
FastAPI acts as a modern bridge.
AI generates strategic interpretations from consolidated data.

The result is a hybrid architecture:

```text
Legacy terminal + modern API + database intelligence + AI interpretation
```

