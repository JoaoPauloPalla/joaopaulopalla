# Setup Dev — Debian 13 Trixie

Script Bash para configuração automatizada de um ambiente de desenvolvimento no **Debian 13 (Trixie)**.

## Instalações

1. Python 3.14.7 via pyenv
2. Node.js LTS via NVM
3. .NET SDK 10
4. Docker Engine + Docker Compose
5. PostgreSQL
6. Mosquitto MQTT

O script é idempotente: verifica se cada componente já está instalado e funcionando antes de instalar.

---

## Requisitos

- Debian 13 Trixie
- Usuário normal com acesso a `sudo`
- Conexão com a Internet

O script não deve ser executado como `root`.

## Instalação do script

```bash
chmod +x setup-dev.sh
./setup-dev.sh
```

O script solicita confirmação antes de iniciar:

```text
Deseja iniciar a instalação? [s/N]:
```

Digite `s` para continuar.

---

## Menu

```text
1 - Python 3.14.7 via pyenv
2 - Node.js LTS via NVM
3 - .NET SDK 10
4 - Docker Engine + Docker Compose
5 - PostgreSQL
6 - Mosquitto MQTT

0 - Instalar TODAS
q - Sair
```

Quando um componente já estiver instalado e funcionando, ele aparece como `[instalado]`.

Após cada etapa:

- `c` — continuar
- `r` — repetir a instalação
- `p` — parar o script

A opção `0` executa todas as instalações na ordem Python, Node.js, .NET, Docker, PostgreSQL e Mosquitto.

---

# 1. Python 3.14.7 + pyenv

A versão é definida por:

```bash
PYTHON_VERSION="3.14.7"
```

### Dependências

```text
build-essential
curl
git
wget
ca-certificates
gnupg
libssl-dev
zlib1g-dev
libbz2-dev
libreadline-dev
libsqlite3-dev
libncurses-dev
xz-utils
tk-dev
libffi-dev
liblzma-dev
uuid-dev
```

### pyenv

Se `~/.pyenv` não existir:

```bash
curl https://pyenv.run | bash
```

O script adiciona ao `~/.bashrc`:

```bash
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
```

### Python

```bash
pyenv install 3.14.7
pyenv global 3.14.7
```

### Validação

```bash
python --version
pyenv --version
/usr/bin/python3 --version
```

O Python do pyenv é independente do Python do sistema.

---

# 2. Node.js LTS + NVM

A versão do NVM utilizada é:

```bash
NVM_VERSION="v0.40.3"
```

### Dependências

```text
curl
ca-certificates
git
```

### NVM

Instalador utilizado:

```text
https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh
```

Diretório:

```text
~/.nvm
```

### Node.js

```bash
nvm install --lts
nvm alias default 'lts/*'
nvm use --lts
```

### Validação

```bash
node --version
npm --version
nvm --version
```

---

# 3. .NET SDK 10

O .NET é instalado através do repositório oficial da Microsoft.

### Dependências

```text
wget
ca-certificates
gnupg
```

### Repositório Microsoft

O script utiliza:

```text
https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb
```

Pacote:

```text
packages-microsoft-prod
```

### Instalação

```bash
sudo apt install -y dotnet-sdk-10.0
```

### Validação

```bash
dotnet --version
dotnet --list-sdks
dotnet --list-runtimes
```

---

# 4. Docker Engine + Docker Compose

O Docker é instalado a partir do repositório oficial do Docker.

### Dependências

```text
ca-certificates
curl
gnupg
```

### Chave GPG

```text
/etc/apt/keyrings/docker.asc
```

### Repositório

```text
https://download.docker.com/linux/debian
```

Distribuição:

```text
trixie
```

Componente:

```text
stable
```

### Pacotes

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

### Grupo Docker

O usuário atual é adicionado ao grupo:

```bash
sudo usermod -aG docker "$USER"
```

É necessário fazer logout/login depois da instalação para que a alteração de grupo tenha efeito.

Depois:

```bash
docker ps
```

deve funcionar sem `sudo`.

### Inicialização automática

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

### Validação

```bash
docker --version
docker compose version
sudo systemctl is-active docker
```

---

# 5. PostgreSQL

O PostgreSQL utiliza o repositório PGDG.

### Dependências

```text
wget
ca-certificates
gnupg
```

### Repositório PGDG

O script verifica:

```text
/etc/apt/sources.list.d/pgdg.sources
/etc/apt/sources.list.d/pgdg.list
```

Se necessário, instala `postgresql-common` e utiliza:

```text
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
```

### Pacotes

```text
postgresql
postgresql-client
postgresql-contrib
```

### Inicialização automática

```bash
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### Validação

```bash
psql --version
sudo systemctl is-active postgresql
```

O script também testa a conexão executando:

```sql
SELECT version();
```

como usuário `postgres`.

Para abrir o cliente:

```bash
sudo -u postgres psql
```

---

# 6. Mosquitto MQTT

Instala o broker MQTT e seus clientes.

### Dependências

```text
ca-certificates
```

### Pacotes

```text
mosquitto
mosquitto-clients
```

Os clientes fornecem:

- `mosquitto_pub` — publica mensagens MQTT
- `mosquitto_sub` — recebe mensagens MQTT

### Exemplo de publicação

```bash
mosquitto_pub -h localhost -t teste -m "hello"
```

### Exemplo de assinatura

```bash
mosquitto_sub -h localhost -t teste
```

### Inicialização automática

```bash
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
```

### Validação

```bash
dpkg -s mosquitto
command -v mosquitto_pub
command -v mosquitto_sub
sudo systemctl is-active mosquitto
```

Logs:

```bash
sudo journalctl -u mosquitto -n 10 --no-pager
```

---

# Dependências gerais

Cada instalação instala somente as dependências necessárias.

A função `ensure_dependencies()`:

1. executa `apt update`;
2. instala os pacotes solicitados;
3. retorna erro se o APT falhar.

---

# Verificação de instalação

| Componente | Verificação |
|---|---|
| Python | Python específico do pyenv |
| Node.js | NVM + Node ativo |
| .NET | `dotnet --version` na versão 10 |
| Docker | Docker + Compose + serviço ativo |
| PostgreSQL | `psql` + serviço + conexão |
| Mosquitto | pacote + clientes + serviço ativo |

---

# Idempotência

O script pode ser executado várias vezes.

Componentes já instalados e funcionando aparecem como `[instalado]` e não precisam ser reinstalados.

Isso permite utilizar o script para:

- configuração inicial;
- reinstalação de uma máquina;
- recuperação de uma instalação;
- instalação individual;
- execução repetida.

---

# Serviços

Os serviços abaixo são configurados para iniciar automaticamente no boot:

| Serviço | Boot | Iniciado pelo script |
|---|---:|---:|
| Docker | Sim | Sim |
| PostgreSQL | Sim | Sim |
| Mosquitto | Sim | Sim |

Verificar:

```bash
systemctl is-enabled docker
systemctl is-enabled postgresql
systemctl is-enabled mosquitto
```

Esperado:

```text
enabled
enabled
enabled
```

Verificar estado atual:

```bash
systemctl is-active docker
systemctl is-active postgresql
systemctl is-active mosquitto
```

Esperado:

```text
active
active
active
```

---

# Comandos úteis

## Python

```bash
python --version
pyenv --version
```

## Node.js

```bash
node --version
npm --version
nvm --version
```

## .NET

```bash
dotnet --version
dotnet --list-sdks
dotnet --list-runtimes
```

## Docker

```bash
docker --version
docker compose version
docker ps
```

## PostgreSQL

```bash
psql --version
systemctl status postgresql
sudo -u postgres psql
```

## Mosquitto

```bash
systemctl status mosquitto
dpkg-query -W -f='${Version}\n' mosquitto
```

---

# Logs

## Docker

```bash
sudo journalctl -u docker --no-pager
sudo journalctl -u docker -n 50 --no-pager
```

## PostgreSQL

```bash
sudo journalctl -u postgresql --no-pager
sudo journalctl -u postgresql -n 50 --no-pager
```

## Mosquitto

```bash
sudo journalctl -u mosquitto --no-pager
sudo journalctl -u mosquitto -n 50 --no-pager
```

---

# Troubleshooting

## O script não executa

```bash
chmod +x setup-dev.sh
./setup-dev.sh
```

## Docker não funciona sem sudo

Faça logout/login após a instalação:

```bash
logout
```

Depois:

```bash
docker ps
```

## PostgreSQL não está ativo

```bash
systemctl status postgresql
sudo systemctl start postgresql
systemctl is-active postgresql
```

## Mosquitto não está ativo

```bash
systemctl status mosquitto
sudo systemctl start mosquitto
sudo journalctl -u mosquitto -n 50 --no-pager
```

---

# Segurança e permissões

O script deve ser executado como usuário normal.

**Não execute como `root`.**

Operações que exigem privilégios administrativos utilizam `sudo`, incluindo:

- instalação de pacotes;
- configuração de repositórios;
- instalação de chaves;
- gerenciamento de serviços;
- alteração de grupos;
- operações do PostgreSQL;
- configuração do Docker.

---

# Estrutura

```text
setup-dev.sh
│
├── Configurações
│   ├── Versão Python
│   └── Versão NVM
│
├── Funções auxiliares
│   ├── header
│   ├── success
│   ├── error
│   ├── warning
│   ├── info
│   ├── pause_after_step
│   ├── retry_install
│   └── ensure_dependencies
│
├── Verificação
│   ├── python_installed
│   ├── node_installed
│   ├── dotnet_installed
│   ├── docker_installed
│   ├── postgres_installed
│   └── mosquitto_installed
│
├── Menu
│
├── Instalações
│   ├── install_python
│   ├── install_node
│   ├── install_dotnet
│   ├── install_docker
│   ├── install_postgres
│   └── install_mosquitto
│
├── Execução
│   ├── run_installation
│   └── run_all_installations
│
├── Resumo
│   └── show_final_summary
│
└── Menu principal
```

---

# Objetivo

Transformar uma instalação limpa do **Debian 13 Trixie** em um ambiente de desenvolvimento contendo:

```text
Python
Node.js
.NET
Docker
PostgreSQL
MQTT
```

com instalação modular, detecção automática de componentes instalados, validação após cada etapa, gerenciamento dos serviços, inicialização automática e resumo final das versões.
