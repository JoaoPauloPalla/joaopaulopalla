
#!/usr/bin/env bash

set -u
set -eo pipefail

# ============================================================
# Debian 13 Trixie - Ambiente de Desenvolvimento
#
# Instalações disponíveis:
#   1 - Python 3.14 via pyenv
#   2 - Node.js LTS via NVM
#   3 - .NET SDK 10
#   4 - Docker Engine + Docker Compose
#   5 - PostgreSQL
#   6 - Mosquitto MQTT
#
# Fluxo:
#   - Menu inicial para escolher uma instalação ou todas
#   - Antes de cada instalação verifica se já está instalada
#   - Se não estiver, instala dependências e depois o pacote
#   - Após cada instalação:
#       c = continuar
#       r = repetir
#       p = parar
# ============================================================

PYTHON_VERSION="3.14.7"
NVM_VERSION="v0.40.3"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# Funções auxiliares
# ------------------------------------------------------------

header() {
    echo
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

pause_after_step() {
    local step="$1"

    echo
    echo -e "${YELLOW}Etapa concluída: ${step}${NC}"
    echo
    echo "  [c] Continuar"
    echo "  [r] Repetir esta instalação"
    echo "  [p] Parar o script"
    echo

    while true; do
        read -r -p "Escolha [c/r/p]: " answer

        case "$answer" in
            c|C)
                return 0
                ;;
            r|R)
                return 1
                ;;
            p|P)
                echo
                warning "Instalação interrompida pelo usuário."
                exit 0
                ;;
            *)
                echo "Opção inválida. Use c, r ou p."
                ;;
        esac
    done
}

retry_install() {
    read -r -p "Tentar novamente? [s/N]: " retry
    [[ "$retry" =~ ^[sS]$ ]]
}

ensure_dependencies() {
    info "Atualizando lista de pacotes..."

    if ! sudo apt update; then
        error "Falha ao atualizar o APT."
        return 1
    fi

    if [[ "$#" -gt 0 ]]; then
        info "Instalando dependências..."

        if ! sudo apt install -y "$@"; then
            error "Falha ao instalar dependências."
            return 1
        fi
    fi
}

# ============================================================
# VERIFICAÇÃO DE INSTALAÇÕES
# ============================================================

python_installed() {
    [[ -x "$HOME/.pyenv/versions/$PYTHON_VERSION/bin/python" ]]
}

node_installed() {
    [[ -s "$HOME/.nvm/nvm.sh" ]] || return 1

    set +u

    export NVM_DIR="$HOME/.nvm"

    # shellcheck disable=SC1090
    source "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true

    local current
    current="$(nvm current 2>/dev/null || true)"

    set -u

    [[ "$current" != "none" && -n "$current" ]]
}

dotnet_installed() {
    command -v dotnet >/dev/null 2>&1 &&
        dotnet --version 2>/dev/null | grep -q '^10\.'
}

docker_installed() {
    command -v docker >/dev/null 2>&1 &&
        docker compose version >/dev/null 2>&1 &&
        sudo systemctl is-active --quiet docker
}

postgres_installed() {
    command -v psql >/dev/null 2>&1 &&
        sudo systemctl is-active --quiet postgresql &&
        sudo -u postgres psql -c "SELECT 1;" >/dev/null 2>&1
}

mosquitto_installed() {
    dpkg -s mosquitto >/dev/null 2>&1 &&
    command -v mosquitto_pub >/dev/null 2>&1 &&
    command -v mosquitto_sub >/dev/null 2>&1 &&
    sudo systemctl is-active --quiet mosquitto
}

installation_status() {
    local id="$1"

    case "$id" in
        1) python_installed ;;
        2) node_installed ;;
        3) dotnet_installed ;;
        4) docker_installed ;;
        5) postgres_installed ;;
        6) mosquitto_installed ;;
        *) return 1 ;;
    esac
}

# ============================================================
# MENU
# ============================================================

show_installation_menu() {
    header "INSTALAÇÕES DISPONÍVEIS"

    printf "  1 - Python %s via pyenv" "$PYTHON_VERSION"

    if python_installed; then
        echo -e " ${GREEN}[instalado]${NC}"
    else
        echo
    fi

    printf "  2 - Node.js LTS via NVM"

    if node_installed; then
        echo -e " ${GREEN}[instalado]${NC}"
    else
        echo
    fi

    printf "  3 - .NET SDK 10"

    if dotnet_installed; then
        echo -e " ${GREEN}[instalado]${NC}"
    else
        echo
    fi

    printf "  4 - Docker Engine + Docker Compose"

    if docker_installed; then
        echo -e " ${GREEN}[instalado]${NC}"
    else
        echo
    fi

    printf "  5 - PostgreSQL"

    if postgres_installed; then
        echo -e " ${GREEN}[instalado]${NC}"
    else
        echo
    fi

    printf "  6 - Mosquitto MQTT"

    if mosquitto_installed; then
        echo -e " ${GREEN}[instalado]${NC}"
    else
        echo
    fi

    echo
    echo "  0 - Instalar TODAS"
    echo "  q - Sair"
    echo
}

# ============================================================
# PYTHON
# ============================================================

install_python() {
    while true; do

        header "PYTHON $PYTHON_VERSION / PYENV"

        if python_installed; then

            info "Python $PYTHON_VERSION já está instalado."

        else

            info "Python $PYTHON_VERSION não está instalado."

            if ! ensure_dependencies \
                build-essential \
                curl \
                git \
                wget \
                ca-certificates \
                gnupg \
                libssl-dev \
                zlib1g-dev \
                libbz2-dev \
                libreadline-dev \
                libsqlite3-dev \
                libncurses-dev \
                xz-utils \
                tk-dev \
                libffi-dev \
                liblzma-dev \
                uuid-dev; then

                retry_install || exit 1
                continue
            fi

            if [[ ! -d "$HOME/.pyenv" ]]; then

                info "Instalando pyenv..."

                if curl https://pyenv.run | bash; then
                    success "pyenv instalado."
                else
                    error "Falha ao instalar pyenv."

                    retry_install || exit 1
                    continue
                fi

            else

                info "pyenv já está instalado."

            fi

        fi

        # ----------------------------------------------------
        # Configuração do pyenv
        # ----------------------------------------------------

        if ! grep -q 'export PATH="$HOME/.pyenv/bin:$PATH"' "$HOME/.bashrc"; then

            cat >> "$HOME/.bashrc" <<'EOF'

# pyenv
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
EOF

        fi

        export PATH="$HOME/.pyenv/bin:$PATH"

        set +u

        if [[ -f "$HOME/.pyenv/bin/pyenv" ]]; then
            eval "$("$HOME/.pyenv/bin/pyenv" init -)" 2>/dev/null || true
        fi

        set -u

        if ! command -v pyenv >/dev/null 2>&1; then

            error "pyenv não está disponível nesta sessão."

            set +u
            source "$HOME/.bashrc" 2>/dev/null || true
            set -u

        fi

        if ! command -v pyenv >/dev/null 2>&1; then

            error "Não foi possível carregar pyenv."

            retry_install || exit 1
            continue

        fi

        # ----------------------------------------------------
        # Instala Python
        # ----------------------------------------------------

        if ! python_installed; then

            info "Instalando Python $PYTHON_VERSION..."

            if ! pyenv install "$PYTHON_VERSION"; then

                error "Falha ao instalar Python $PYTHON_VERSION."

                retry_install || exit 1
                continue

            fi

        fi

        pyenv global "$PYTHON_VERSION"

        # ----------------------------------------------------
        # Validação
        # ----------------------------------------------------

        if python --version 2>&1 | grep -q "Python $PYTHON_VERSION"; then

            success "Python $PYTHON_VERSION validado."

            echo
            echo "Python do sistema:"
            /usr/bin/python3 --version

            echo
            echo "Python do usuário:"
            python --version

            echo
            echo "pyenv:"
            pyenv --version

            if pause_after_step "Python $PYTHON_VERSION"; then
                return 0
            fi

        else

            error "A versão esperada do Python não foi encontrada."

            retry_install || exit 1

        fi

    done
}

# ============================================================
# NODE.JS
# ============================================================

install_node() {
    while true; do

        header "NODE.JS LTS / NVM"

        export NVM_DIR="$HOME/.nvm"

        # ----------------------------------------------------
        # Dependências
        # ----------------------------------------------------

        if ! node_installed; then

            info "Node.js/NVM não estão instalados."

            if ! ensure_dependencies \
                curl \
                ca-certificates \
                git; then

                retry_install || exit 1
                continue
            fi

        else

            info "NVM/Node.js já estão instalados."

        fi

        # ----------------------------------------------------
        # NVM
        # ----------------------------------------------------

        if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then

            info "Instalando NVM $NVM_VERSION..."

            set +u

            if curl -o- \
                "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
                | bash; then

                success "NVM instalado."

            else

                set -u

                error "Falha ao instalar NVM."

                retry_install || exit 1
                continue

            fi

            set -u

        fi

        if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then

            error "NVM não foi encontrado em $NVM_DIR."

            retry_install || exit 1
            continue

        fi

        # ----------------------------------------------------
        # Carregar NVM
        # ----------------------------------------------------

        set +u

        # shellcheck disable=SC1090
        source "$NVM_DIR/nvm.sh"

        set -u

        if ! command -v nvm >/dev/null 2>&1; then

            error "O comando nvm não foi carregado."

            retry_install || exit 1
            continue

        fi

        # ----------------------------------------------------
        # Node LTS
        # ----------------------------------------------------

        set +u

        if ! nvm ls --no-colors 'lts/*' 2>/dev/null | grep -q "v"; then

            info "Instalando Node.js LTS..."

            if ! nvm install --lts; then

                set -u

                error "Falha ao instalar Node.js LTS."

                retry_install || exit 1
                continue

            fi

        fi

        nvm alias default 'lts/*'
        nvm use --lts

        NODE_VERSION="$(node --version 2>/dev/null || true)"
        NPM_VERSION="$(npm --version 2>/dev/null || true)"
        NVM_INSTALLED_VERSION="$(nvm --version 2>/dev/null || true)"

        set -u

        # ----------------------------------------------------
        # Validação
        # ----------------------------------------------------

        if [[ -n "$NODE_VERSION" &&
              -n "$NPM_VERSION" &&
              -n "$NVM_INSTALLED_VERSION" ]]; then

            success "Node.js: $NODE_VERSION"
            success "npm: $NPM_VERSION"
            success "NVM: $NVM_INSTALLED_VERSION"

            if pause_after_step "Node.js LTS"; then
                return 0
            fi

        else

            error "A validação do Node.js falhou."

            retry_install || exit 1

        fi

    done
}

# ============================================================
# .NET
# ============================================================

install_dotnet() {
    while true; do

        header ".NET SDK 10"

        if dotnet_installed; then

            info ".NET SDK 10 já está instalado."

        else

            info ".NET SDK 10 não está instalado."

            if ! ensure_dependencies \
                wget \
                ca-certificates \
                gnupg; then

                retry_install || exit 1
                continue

            fi

            # ------------------------------------------------
            # Repositório Microsoft
            # ------------------------------------------------

            if ! dpkg -s packages-microsoft-prod >/dev/null 2>&1; then

                TMP_DEB="/tmp/packages-microsoft-prod.deb"

                info "Configurando repositório oficial da Microsoft..."

                if wget -q \
                    https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb \
                    -O "$TMP_DEB" &&
                    sudo dpkg -i "$TMP_DEB"; then

                    rm -f "$TMP_DEB"

                    success "Repositório Microsoft configurado."

                else

                    rm -f "$TMP_DEB"

                    error "Falha ao configurar repositório Microsoft."

                    retry_install || exit 1
                    continue

                fi

            else

                info "Repositório Microsoft já configurado."

            fi

            sudo apt update

            # ------------------------------------------------
            # Instalação
            # ------------------------------------------------

            info "Instalando .NET SDK 10..."

            if ! sudo apt install -y dotnet-sdk-10.0; then

                error "Falha ao instalar .NET SDK."

                retry_install || exit 1
                continue

            fi

        fi

        # ----------------------------------------------------
        # Validação
        # ----------------------------------------------------

        if command -v dotnet >/dev/null 2>&1 &&
            dotnet --version | grep -q '^10\.'; then

            success ".NET SDK 10 validado."

            echo
            echo "Versão:"
            dotnet --version

            echo
            echo "SDKs instalados:"
            dotnet --list-sdks

            echo
            echo "Runtimes instalados:"
            dotnet --list-runtimes

            if pause_after_step ".NET SDK 10"; then
                return 0
            fi

        else

            error "SDK .NET 10 não foi encontrado."

            retry_install || exit 1

        fi

    done
}

# ============================================================
# DOCKER
# ============================================================

install_docker() {
    while true; do

        header "DOCKER ENGINE + DOCKER COMPOSE"

        if docker_installed; then

            info "Docker já está instalado e ativo."

        else

            info "Docker não está instalado ou não está ativo."

            if ! ensure_dependencies \
                ca-certificates \
                curl \
                gnupg; then

                retry_install || exit 1
                continue

            fi

            # ------------------------------------------------
            # Chave GPG
            # ------------------------------------------------

            sudo install -m 0755 -d /etc/apt/keyrings

            if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then

                info "Instalando chave GPG do Docker..."

                if sudo curl -fsSL \
                    https://download.docker.com/linux/debian/gpg \
                    -o /etc/apt/keyrings/docker.asc; then

                    sudo chmod a+r /etc/apt/keyrings/docker.asc

                    success "Chave GPG instalada."

                else

                    error "Falha ao instalar chave GPG."

                    retry_install || exit 1
                    continue

                fi

            else

                info "Chave GPG do Docker já existe."

            fi

            # ------------------------------------------------
            # Repositório
            # ------------------------------------------------

            if [[ ! -f /etc/apt/sources.list.d/docker.sources ]]; then

                sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

                success "Repositório Docker configurado."

            else

                info "Repositório Docker já configurado."

            fi

            sudo apt update

            # ------------------------------------------------
            # Instalação
            # ------------------------------------------------

            info "Instalando Docker..."

            if ! sudo apt install -y \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin; then

                error "Falha ao instalar Docker."

                retry_install || exit 1
                continue

            fi

            # ------------------------------------------------
            # Configuração
            # ------------------------------------------------

            sudo usermod -aG docker "$USER" || true

            sudo systemctl enable docker
            sudo systemctl start docker

        fi

        # ----------------------------------------------------
        # Validação
        # ----------------------------------------------------

        VALID=true

        if command -v docker >/dev/null 2>&1; then
            success "Docker: $(docker --version)"
        else
            error "Comando docker não encontrado."
            VALID=false
        fi

        if docker compose version >/dev/null 2>&1; then
            success "Docker Compose: $(docker compose version)"
        else
            error "Docker Compose não encontrado."
            VALID=false
        fi

        if sudo systemctl is-active --quiet docker; then
            success "Serviço Docker está ativo."
        else
            error "Serviço Docker não está ativo."
            VALID=false
        fi

        if [[ "$VALID" == true ]]; then

            warning "A alteração do grupo docker será efetiva em uma nova sessão."

            if pause_after_step "Docker + Docker Compose"; then
                return 0
            fi

        else

            retry_install || exit 1

        fi

    done
}

# ============================================================
# POSTGRESQL
# ============================================================

install_postgres() {
    while true; do

        header "POSTGRESQL"

        if postgres_installed; then

            info "PostgreSQL já está instalado e ativo."

        else

            info "PostgreSQL não está instalado ou não está ativo."

            if ! ensure_dependencies \
                wget \
                ca-certificates \
                gnupg; then

                retry_install || exit 1
                continue

            fi

            # ------------------------------------------------
            # Verificar PGDG
            # ------------------------------------------------

            PGDG_REPO_CONFIGURED=false

            if [[ -f /etc/apt/sources.list.d/pgdg.sources ]] ||
               [[ -f /etc/apt/sources.list.d/pgdg.list ]]; then

                if grep -Rqs \
                    "apt.postgresql.org/pub/repos/apt" \
                    /etc/apt/sources.list.d/ \
                    2>/dev/null; then

                    PGDG_REPO_CONFIGURED=true

                fi

            fi

            # ------------------------------------------------
            # Configurar PGDG
            # ------------------------------------------------

            if [[ "$PGDG_REPO_CONFIGURED" == false ]]; then

                info "Instalando postgresql-common..."

                if ! sudo apt update ||
                   ! sudo apt install -y postgresql-common; then

                    error "Falha ao instalar postgresql-common."

                    retry_install || exit 1
                    continue

                fi

                if [[ -x /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh ]]; then

                    info "Configurando repositório oficial PostgreSQL..."

                    if ! sudo \
                        /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh; then

                        error "Falha ao configurar o repositório PGDG."

                        retry_install || exit 1
                        continue

                    fi

                else

                    error "Script oficial apt.postgresql.org.sh não foi encontrado."

                    retry_install || exit 1
                    continue

                fi

            else

                info "Repositório PostgreSQL PGDG já está configurado."

            fi

            sudo apt update

            # ------------------------------------------------
            # Instalação
            # ------------------------------------------------

            info "Instalando PostgreSQL..."

            if ! sudo apt install -y \
                postgresql \
                postgresql-client \
                postgresql-contrib; then

                error "Falha ao instalar PostgreSQL."

                retry_install || exit 1
                continue

            fi

            sudo systemctl enable postgresql
            sudo systemctl start postgresql

        fi

        # ----------------------------------------------------
        # Validação
        # ----------------------------------------------------

        VALID=true

        if command -v psql >/dev/null 2>&1; then
            success "psql encontrado."
        else
            error "psql não encontrado."
            VALID=false
        fi

        if sudo systemctl is-active --quiet postgresql; then
            success "Serviço PostgreSQL está ativo."
        else
            error "Serviço PostgreSQL não está ativo."
            VALID=false
        fi

        if sudo -u postgres psql \
            -c "SELECT version();" >/dev/null 2>&1; then

            success "Conexão com PostgreSQL validada."

        else

            error "Não foi possível conectar ao PostgreSQL."
            VALID=false

        fi

        if [[ "$VALID" == true ]]; then

            echo
            echo "Versão:"
            sudo -u postgres psql --version

            echo
            echo "Serviço:"
            sudo systemctl status postgresql \
                --no-pager \
                -l | head -n 12

            if pause_after_step "PostgreSQL"; then
                return 0
            fi

        else

            retry_install || exit 1

        fi

    done
}

# ============================================================
# MOSQUITTO
# ============================================================

install_mosquitto() {
    while true; do

        header "MOSQUITTO MQTT"

        if mosquitto_installed; then

            info "Mosquitto já está instalado e ativo."

        else

            info "Mosquitto não está instalado ou não está ativo."

            if ! ensure_dependencies ca-certificates; then
                retry_install || exit 1
                continue
            fi

            info "Instalando Mosquitto..."

            if ! sudo apt install -y \
                mosquitto \
                mosquitto-clients; then

                error "Falha ao instalar Mosquitto."

                retry_install || exit 1
                continue

            fi

            sudo systemctl enable mosquitto

            if ! sudo systemctl start mosquitto; then

                if ! sudo systemctl is-active --quiet mosquitto; then

                    error "Não foi possível iniciar o Mosquitto."

                    sudo journalctl \
                        -u mosquitto \
                        --no-pager \
                        -n 20

                    retry_install || exit 1
                    continue

                fi

            fi

        fi
        # ----------------------------------------------------
        # Validação
        # ----------------------------------------------------

        VALID=true

        # Verifica se o pacote Mosquitto está instalado
        if dpkg -s mosquitto >/dev/null 2>&1; then
            success "Pacote Mosquitto instalado."
        else
            error "Pacote Mosquitto não está instalado."
            VALID=false
        fi

        # Verifica o cliente mosquitto_pub
        if command -v mosquitto_pub >/dev/null 2>&1; then
            success "mosquitto_pub encontrado."
        else
            error "mosquitto_pub não encontrado."
            VALID=false
        fi

        # Verifica o cliente mosquitto_sub
        if command -v mosquitto_sub >/dev/null 2>&1; then
            success "mosquitto_sub encontrado."
        else
            error "mosquitto_sub não encontrado."
            VALID=false
        fi

        # Verifica se o serviço está ativo
        if sudo systemctl is-active --quiet mosquitto; then
            success "Serviço Mosquitto está ativo."
        else
            error "Serviço Mosquitto não está ativo."
            VALID=false
        fi

        # Mostra logs recentes para facilitar diagnóstico
        if [[ "$VALID" == true ]]; then

            echo
            echo "Logs recentes:"
            sudo journalctl -u mosquitto -n 10 --no-pager

            echo

            if pause_after_step "Mosquitto MQTT"; then
                return 0
            fi

        else

            retry_install || exit 1

        fi

    done
}

# ============================================================
# EXECUTAR INSTALAÇÃO
# ============================================================

run_installation() {

    case "$1" in

        1)
            install_python
            ;;

        2)
            install_node
            ;;

        3)
            install_dotnet
            ;;

        4)
            install_docker
            ;;

        5)
            install_postgres
            ;;

        6)
            install_mosquitto
            ;;

        *)
            error "Instalação inválida: $1"
            return 1
            ;;

    esac
}

# ============================================================
# INSTALAR TODAS
# ============================================================

run_all_installations() {

    for id in 1 2 3 4 5 6; do

        run_installation "$id"

    done
}

# ============================================================
# RESUMO FINAL
# ============================================================

show_final_summary() {

    header "RESUMO FINAL"

    echo "Versões instaladas:"
    echo

    echo "Python:"
    python --version 2>/dev/null || true

    echo
    echo "Node.js:"
    node --version 2>/dev/null || true

    echo
    echo "npm:"
    npm --version 2>/dev/null || true

    echo
    echo ".NET:"
    dotnet --version 2>/dev/null || true

    echo
    echo "Docker:"
    docker --version 2>/dev/null || true

    echo
    echo "Docker Compose:"
    docker compose version 2>/dev/null || true

    echo
    echo "PostgreSQL:"
    psql --version 2>/dev/null || true

    echo
    echo "Mosquitto:"
    dpkg-query -W -f='${Version}\n' mosquitto 2>/dev/null || true

    echo
    echo "============================================================"
    echo " Ambiente configurado."
    echo "============================================================"
    echo

    echo "Se o usuário docker foi alterado, faça logout/login"
    echo "ou abra uma nova sessão antes de usar Docker sem sudo."

    echo
}

# ============================================================
# VERIFICAÇÃO INICIAL
# ============================================================

header "VERIFICAÇÃO INICIAL"

if [[ $EUID -eq 0 ]]; then

    error "Não execute este script como root."

    echo
    echo "Execute como seu usuário normal:"
    echo
    echo "    ./setup-dev.sh"

    exit 1

fi

if [[ ! -f /etc/debian_version ]]; then

    error "Este script foi desenvolvido para Debian."

    exit 1

fi

DEBIAN_VERSION=$(cat /etc/debian_version)

info "Debian detectado: $DEBIAN_VERSION"
info "Usuário: $USER"
info "Home: $HOME"

echo

read -r -p "Deseja iniciar a instalação? [s/N]: " start

case "$start" in

    s|S)
        ;;

    *)
        echo "Instalação cancelada."
        exit 0
        ;;

esac

# ============================================================
# MENU PRINCIPAL
# ============================================================

while true; do

    show_installation_menu

    read -r -p "Escolha uma instalação [0-6/q]: " choice

    case "$choice" in

        0)
            run_all_installations
            show_final_summary
            exit 0
            ;;

        1|2|3|4|5|6)
            run_installation "$choice"
            ;;

        q|Q)
            echo "Saindo."
            exit 0
            ;;

        *)
            error "Opção inválida."
            ;;

    esac

done
