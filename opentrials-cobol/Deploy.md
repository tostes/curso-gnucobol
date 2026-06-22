# Como usar os Makefiles do projeto ReBEC COBOL

Este documento explica o uso dos dois Makefiles do projeto:

```text
Makefile.local   -> usado no ambiente local de desenvolvimento
Makefile.deploy  -> usado para atualizar e compilar a aplicação em /opt
```

---

## 1. Estrutura considerada

### Ambiente local

```text
~/cobol/curso-gnucobol/opentrials-cobol/
├── Makefile.local
├── Makefile.deploy
├── codes/
└── sources/
```

### Ambiente de deploy

```text
/opt/opentrials-cobol/                        -> raiz do Git em /opt
├── .git/
├── README.md
├── codes/
└── opentrials-cobol/                         -> diretório real da aplicação
    ├── Makefile.local
    ├── codes/
    └── sources/
```

No deploy:

```text
git pull roda em:       /opt/opentrials-cobol
compilação roda em:     /opt/opentrials-cobol/opentrials-cobol
usuário de deploy:      rebecapp
```

---

# 2. Makefile.local

O `Makefile.local` é usado para compilar e testar o projeto no ambiente local.

Entre na raiz do projeto:

```bash
cd ~/cobol/curso-gnucobol/opentrials-cobol
```

## Compilar tudo

```bash
make -f Makefile.local all
```

Esse comando compila os módulos:

```text
codes/bin/LOADCONF.so
codes/bin/LOGIN.so
```

E os binários:

```text
codes/bin/test_loadconf
codes/bin/test_login
codes/bin/trial_list
codes/bin/trial_view
codes/bin/trial_menu
```

## Rodar a aplicação local

```bash
make -f Makefile.local run
```

Esse comando chama:

```bash
cd codes && ./run.sh
```

## Testar configuração do banco

```bash
make -f Makefile.local test-config
```

Esse teste verifica se o COBOL consegue ler:

```text
codes/db.conf
```

e carregar as configurações:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_SCHEMA
```

## Testar login

```bash
make -f Makefile.local test-login
```

Esse teste valida o fluxo:

```text
COBOL -> LOGIN.so -> LOADCONF.so -> psql -> PostgreSQL -> app_login()
```

Exemplo:

```text
Username: admin
Password: 123456
```

Saída esperada:

```text
Status    : OK
Message   : Login successful
Logged in : Y
User ID   : 1
Username  : admin
Full name : System Administrator
Role      : admin
```

## Rodar módulos individuais

Listagem:

```bash
make -f Makefile.local list
```

Visualização:

```bash
make -f Makefile.local view
```

Menu:

```bash
make -f Makefile.local menu
```

## Limpar binários e temporários

```bash
make -f Makefile.local clean
```

Remove:

```text
codes/bin/
codes/*.tmp
codes/login_result.tmp
codes/trial_list.tmp
codes/trial_view.tmp
```

Depois de limpar, compile novamente:

```bash
make -f Makefile.local all
```

---

# 3. Atenção ao diretório de execução

Os binários não devem ser executados diretamente de dentro de:

```text
codes/bin/
```

Exemplo incorreto:

```bash
cd codes/bin
./trial_list
```

Isso pode gerar:

```text
Configuration error.
Message: Could not open db.conf
```

Porque o `LOADCONF.cbl` procura `db.conf` no diretório atual.

Forma correta:

```bash
cd codes
export COB_LIBRARY_PATH=./bin
./bin/trial_list
```

Ou use sempre:

```bash
make -f Makefile.local run
```

---

# 4. Makefile.deploy

O `Makefile.deploy` é usado para atualizar e compilar o projeto implantado em `/opt`.

Ele deve ser executado a partir do ambiente local de desenvolvimento:

```bash
cd ~/cobol/curso-gnucobol/opentrials-cobol
```

Configuração usada:

```makefile
REPO_DIR    := /opt/opentrials-cobol
APP_DIR     := /opt/opentrials-cobol/opentrials-cobol
DEPLOY_USER := rebecapp
LOCAL_MAKE  := Makefile.local
```

## Ver configuração do deploy

```bash
make -f Makefile.deploy show-config
```

Saída esperada:

```text
REPO_DIR    = /opt/opentrials-cobol
APP_DIR     = /opt/opentrials-cobol/opentrials-cobol
DEPLOY_USER = rebecapp
LOCAL_MAKE  = Makefile.local
```

## Ver status do repositório em /opt

```bash
make -f Makefile.deploy status
```

Esse comando executa o Git como `rebecapp`:

```bash
sudo -u rebecapp git -C /opt/opentrials-cobol status --short
```

## Fazer apenas git pull em /opt

```bash
make -f Makefile.deploy pull
```

Equivalente a:

```bash
sudo -u rebecapp git -C /opt/opentrials-cobol pull
```

## Compilar o deploy sem git pull

```bash
make -f Makefile.deploy compile
```

Equivalente a:

```bash
sudo -u rebecapp make -C /opt/opentrials-cobol/opentrials-cobol -f Makefile.local all
```

## Fazer deploy completo

```bash
make -f Makefile.deploy deploy
```

Esse é o comando principal.

Ele faz:

```text
1. git pull em /opt/opentrials-cobol
2. compilação em /opt/opentrials-cobol/opentrials-cobol
3. geração dos módulos .so
4. geração dos binários COBOL
```

Exemplo de saída correta:

```text
============================================================
Starting deploy
Repository : /opt/opentrials-cobol
Application: /opt/opentrials-cobol/opentrials-cobol
User       : rebecapp
============================================================
sudo -u rebecapp git -C /opt/opentrials-cobol pull
Already up to date.
sudo -u rebecapp make -C /opt/opentrials-cobol/opentrials-cobol -f Makefile.local all
make: Entrando no diretório '/opt/opentrials-cobol/opentrials-cobol'
Build finished successfully.
make: Saindo do diretório '/opt/opentrials-cobol/opentrials-cobol'
============================================================
Deploy finished successfully.
============================================================
```

## Testar configuração no deploy

```bash
make -f Makefile.deploy test-config
```

Esse comando testa o arquivo:

```text
/opt/opentrials-cobol/opentrials-cobol/codes/db.conf
```

## Testar login no deploy

```bash
make -f Makefile.deploy test-login
```

## Rodar aplicação do deploy

```bash
make -f Makefile.deploy run
```

## Limpar binários e temporários no deploy

```bash
make -f Makefile.deploy clean
```

---

# 5. Permissões esperadas em /opt

O diretório de deploy deve pertencer ao usuário técnico:

```bash
sudo chown -R rebecapp:rebecapp /opt/opentrials-cobol
```

Confira:

```bash
ls -ld /opt/opentrials-cobol
ls -ld /opt/opentrials-cobol/.git
```

O ideal é aparecer:

```text
rebecapp rebecapp /opt/opentrials-cobol
rebecapp rebecapp /opt/opentrials-cobol/.git
```

O Git no deploy deve ser executado assim:

```bash
sudo -u rebecapp git -C /opt/opentrials-cobol status
sudo -u rebecapp git -C /opt/opentrials-cobol pull
```

Evite rodar `git pull` como `diego` dentro de `/opt`.

---

# 6. Arquivo db.conf no deploy

O `db.conf` não vem do Git. Ele deve ser criado manualmente no deploy:

```bash
sudo -u rebecapp cp /opt/opentrials-cobol/opentrials-cobol/codes/db.conf.example \
  /opt/opentrials-cobol/opentrials-cobol/codes/db.conf

sudo -u rebecapp vim /opt/opentrials-cobol/opentrials-cobol/codes/db.conf
```

Exemplo:

```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=rebec_cobol
DB_USER=diego
DB_SCHEMA=rebec_cobol
```

A senha do banco deve ficar em `~/.pgpass` do usuário que executa o `psql`.

Para o usuário `rebecapp`:

```bash
sudo -u rebecapp vim /home/rebecapp/.pgpass
sudo -u rebecapp chmod 600 /home/rebecapp/.pgpass
```

Formato:

```text
localhost:5432:rebec_cobol:diego:SENHA_AQUI
```

---

# 7. Arquivos ignorados no deploy

Como a raiz Git em `/opt` é:

```text
/opt/opentrials-cobol
```

o arquivo:

```text
/opt/opentrials-cobol/.git/info/exclude
```

deve conter:

```gitignore
# Local deploy ignores
opentrials-cobol/codes/bin/
opentrials-cobol/codes/*.tmp
opentrials-cobol/codes/db.conf
opentrials-cobol/*.tmp

opentrials-cobol/sources/RBR-ictrp-ALL.xml
opentrials-cobol/sources/import_failed_trials_*.log

__pycache__/
*.pyc
```

Teste:

```bash
sudo -u rebecapp git -C /opt/opentrials-cobol status --short
```

Não devem aparecer:

```text
opentrials-cobol/codes/bin/
opentrials-cobol/codes/db.conf
opentrials-cobol/codes/*.tmp
```

---

# 8. Fluxo recomendado

## Desenvolvimento local

```bash
cd ~/cobol/curso-gnucobol/opentrials-cobol

make -f Makefile.local all
make -f Makefile.local test-config
make -f Makefile.local test-login
make -f Makefile.local run
```

Depois de alterar arquivos:

```bash
git status --short
git add arquivo_alterado
git commit -m "mensagem do commit"
git push origin main
```

## Deploy

Depois do push:

```bash
make -f Makefile.deploy deploy
```

Depois teste:

```bash
make -f Makefile.deploy test-config
make -f Makefile.deploy test-login
make -f Makefile.deploy run
```

---

# 9. Problemas comuns

## Erro: Could not open db.conf

Causa: binário executado de dentro de `codes/bin/`.

Solução: execute a partir de `codes/` ou use o Makefile.

```bash
make -f Makefile.local run
```

ou:

```bash
make -f Makefile.deploy run
```

## Erro: detected dubious ownership

Causa: tentativa de rodar Git em `/opt` com usuário diferente do dono.

Solução:

```bash
sudo chown -R rebecapp:rebecapp /opt/opentrials-cobol
sudo -u rebecapp git -C /opt/opentrials-cobol status
```

## Erro: Makefile.local not found

Causa: o `Makefile.local` ainda não chegou ao deploy ou o `APP_DIR` está errado.

Confira:

```bash
ls /opt/opentrials-cobol/opentrials-cobol/Makefile.local
```

Se não existir, faça commit e push localmente:

```bash
git add Makefile.local Makefile.deploy
git commit -m "build: add local and deploy Makefiles"
git push origin main
```

Depois:

```bash
make -f Makefile.deploy pull
```

## Warning: _FORTIFY_SOURCE redefined

Pode aparecer durante a compilação:

```text
warning: "_FORTIFY_SOURCE" redefined
```

Se o build terminar com:

```text
Build finished successfully.
```

então a compilação funcionou.
