#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="postgres-dev"
VOLUME_DATA="postgres-data"
PORT=5432
IMAGE="postgres:17-alpine"

# Arquivos externos
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|backup|restore|add-service|list-services}"
    echo ""
    echo "Comandos:"
    echo "  start         Inicia o container PostgreSQL"
    echo "  stop          Para o container"
    echo "  status        Mostra status do container"
    echo "  logs          Exibe logs do PostgreSQL"
    echo "  shell         Abre psql no container"
    echo "  reset         Remove container e volume (CUIDADO: apaga todos os dados)"
    echo "  backup <file> Exporta dados para arquivo SQL"
    echo "  restore <file> Restaura dados de arquivo SQL"
    echo "  add-service <name>  Cria usuário e banco para um serviço"
    echo "  list-services       Lista todos os bancos e usuários"
    echo ""
    echo "String de conexão: postgresql://\$POSTGRES_USER:\$POSTGRES_PASSWORD@localhost:$PORT/\$POSTGRES_DB"
}

check_container_running() {
    container list --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"
}

check_volume_data_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_DATA$"
}

check_env_file() {
    if [ ! -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        echo "❌ Arquivo '$ENV_FILE' não encontrado."
        echo "   cp .env.example .env"
        return 1
    fi
    return 0
}

get_env_var() {
    grep "^$1=" "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2-
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando PostgreSQL..."

    # Verificar arquivo .env
    check_env_file || return 1

    # Ler variáveis do .env
    POSTGRES_USER=$(get_env_var "POSTGRES_USER")
    POSTGRES_PASSWORD=$(get_env_var "POSTGRES_PASSWORD")
    POSTGRES_DB=$(get_env_var "POSTGRES_DB")

    # Verificar se container já existe e está rodando
    if check_container_running; then
        echo "Container '$CONTAINER_NAME' já está rodando."
        return 0
    fi

    # Verificar se container existe mas está parado
    if container list -a --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"; then
        echo "Container '$CONTAINER_NAME' existe mas está parado. Iniciando..."
        container start "$CONTAINER_NAME"
        echo "Container iniciado!"
        return 0
    fi

    # Criar volume se não existir
    if ! check_volume_data_exists; then
        echo "Criando volume '$VOLUME_DATA'..."
        container volume create "$VOLUME_DATA"
    fi

    # Criar e iniciar container
    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        -e POSTGRES_USER="$POSTGRES_USER" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -p "$PORT":5432 \
        -v "$VOLUME_DATA":/var/lib/postgresql \
        "$IMAGE"

    echo ""
    echo "PostgreSQL iniciado com sucesso!"
    echo "String de conexão: postgresql://$POSTGRES_USER:****@localhost:$PORT/$POSTGRES_DB"
    echo "Inter-container: postgresql://$POSTGRES_USER:****@192.168.64.1:$PORT/$POSTGRES_DB"
    echo ""
    echo "Aguarde alguns segundos para o PostgreSQL inicializar completamente."
}

cmd_stop() {
    echo "Parando PostgreSQL..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do PostgreSQL:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        if [ -f "$SCRIPT_DIR/$ENV_FILE" ]; then
            POSTGRES_USER=$(get_env_var "POSTGRES_USER")
            POSTGRES_DB=$(get_env_var "POSTGRES_DB")
            echo "String de conexão: postgresql://$POSTGRES_USER:****@localhost:$PORT/$POSTGRES_DB"
            echo "Inter-container: postgresql://$POSTGRES_USER:****@192.168.64.1:$PORT/$POSTGRES_DB"
        fi
    else
        echo "Container: $CONTAINER_NAME"
        echo "Status: PARADO ou NÃO EXISTE"
    fi

    echo ""
    echo "Volume '$VOLUME_DATA':"
    if check_volume_data_exists; then
        container volume list
    else
        echo "  Não existe"
    fi
}

cmd_logs() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 1
    fi

    container logs -f "$CONTAINER_NAME"
}

cmd_shell() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    POSTGRES_USER=$(get_env_var "POSTGRES_USER")
    POSTGRES_DB=$(get_env_var "POSTGRES_DB")
    container exec -it "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
}

cmd_reset() {
    echo "⚠️  ATENÇÃO: Isso vai remover o container e todos os dados!"
    read -p "Tem certeza? (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Operação cancelada."
        return 0
    fi

    echo "Removendo container..."
    container stop "$CONTAINER_NAME" 2>/dev/null || true
    container delete "$CONTAINER_NAME" 2>/dev/null || true

    echo "Removendo volume..."
    container volume delete "$VOLUME_DATA" 2>/dev/null || true

    echo "Reset completo. Use '$0 start' para criar um novo banco."
}

cmd_backup() {
    local backup_file="$1"

    if [ -z "$backup_file" ]; then
        echo "Erro: Especifique o arquivo de backup."
        echo "Uso: $0 backup <arquivo.sql>"
        return 1
    fi

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    POSTGRES_USER=$(get_env_var "POSTGRES_USER")
    POSTGRES_DB=$(get_env_var "POSTGRES_DB")

    echo "Criando backup em '$backup_file'..."
    container exec "$CONTAINER_NAME" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$backup_file"
    echo "Backup concluído: $backup_file"
}

cmd_restore() {
    local backup_file="$1"

    if [ -z "$backup_file" ]; then
        echo "Erro: Especifique o arquivo de backup."
        echo "Uso: $0 restore <arquivo.sql>"
        return 1
    fi

    if [ ! -f "$backup_file" ]; then
        echo "Erro: Arquivo '$backup_file' não encontrado."
        return 1
    fi

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    POSTGRES_USER=$(get_env_var "POSTGRES_USER")
    POSTGRES_DB=$(get_env_var "POSTGRES_DB")

    echo "Restaurando dados de '$backup_file'..."
    container exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" "$POSTGRES_DB" < "$backup_file"
    echo "Restauração concluída."
}

cmd_add_service() {
    local service_name="$1"

    if [ -z "$service_name" ]; then
        echo "Erro: Especifique o nome do serviço."
        echo "Uso: $0 add-service <nome-do-servico>"
        echo ""
        echo "Exemplo:"
        echo "  $0 add-service litellm"
        echo "  $0 add-service myapp"
        return 1
    fi

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    # Gerar senha aleatória se não especificada
    local db_password=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)
    local db_user="${service_name}"
    local db_name="${service_name}"

    POSTGRES_USER=$(get_env_var "POSTGRES_USER")

    echo "Criando serviço '$service_name'..."
    echo ""
    echo "  Usuário: $db_user"
    echo "  Senha:   $db_password"
    echo "  Banco:   $db_name"
    echo ""

    # Criar usuário
    container exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE USER $db_user WITH PASSWORD '$db_password';" 2>/dev/null || {
        echo "⚠️  Usuário '$db_user' já existe. Atualizando senha..."
        container exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "ALTER USER $db_user WITH PASSWORD '$db_password';"
    }

    # Criar banco
    container exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE DATABASE $db_name OWNER $db_user;" 2>/dev/null || {
        echo "⚠️  Banco '$db_name' já existe."
    }

    # Grant privilégios
    container exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"

    echo ""
    echo "✅ Serviço '$service_name' criado com sucesso!"
    echo ""
    echo "Strings de conexão:"
    echo "  Localhost:     postgresql://$db_user:$db_password@localhost:$PORT/$db_name"
    echo "  Inter-container: postgresql://$db_user:$db_password@192.168.64.1:$PORT/$db_name"
    echo ""
    echo "💡 Adicione ao seu .env:"
    echo "   $(echo $service_name | tr '[:lower:]' '[:upper:]')_DATABASE_URL=postgresql://$db_user:$db_password@192.168.64.1:$PORT/$db_name"
}

cmd_list_services() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    POSTGRES_USER=$(get_env_var "POSTGRES_USER")

    echo "Bancos de dados:"
    echo ""
    container exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "\l" | grep -v template | grep -v postgres
    echo ""
    echo "Usuários:"
    echo ""
    container exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "\du" | grep -v postgres
}

# ============================================
# Main
# ============================================
case "$1" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    shell)
        cmd_shell
        ;;
    reset)
        cmd_reset
        ;;
    backup)
        cmd_backup "$2"
        ;;
    restore)
        cmd_restore "$2"
        ;;
    add-service)
        cmd_add_service "$2"
        ;;
    list-services)
        cmd_list_services
        ;;
    *)
        print_usage
        exit 1
        ;;
esac