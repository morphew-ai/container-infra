#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="litellm-dev"
VOLUME_NAME="litellm-config"
PORT=4000
IMAGE="ghcr.io/berriai/litellm:main-stable"
CONFIG_FILE="config.yaml"
ENV_FILE=".env"
POSTGRES_CONTAINER="postgres-dev"
REDIS_CONTAINER="redis-dev"
DB_NAME="litellm"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|models|test}"
    echo ""
    echo "Comandos:"
    echo "  start         Cria banco, volume e inicia o container LiteLLM"
    echo "  stop          Para o container"
    echo "  status        Mostra status do container"
    echo "  logs          Exibe logs do LiteLLM"
    echo "  shell         Abre shell no container"
    echo "  reset         Remove container e volume (CUIDADO: apaga config)"
    echo "  models        Lista modelos disponíveis"
    echo "  test          Testa conexão com o proxy"
    echo ""
    echo "Endpoint: http://localhost:$PORT/v1"
}

check_container_running() {
    container list --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"
}

check_volume_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_NAME$"
}

check_dependencies() {
    # Verificar se PostgreSQL está rodando
    if ! container list --quiet 2>/dev/null | grep -q "^$POSTGRES_CONTAINER$"; then
        echo "❌ PostgreSQL container '$POSTGRES_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-postgres && ./pg-dev.sh start"
        return 1
    fi

    # Verificar se Redis está rodando
    if ! container list --quiet 2>/dev/null | grep -q "^$REDIS_CONTAINER$"; then
        echo "❌ Redis container '$REDIS_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-redis && ./redis-dev.sh start"
        return 1
    fi

    return 0
}

check_env_file() {
    if [ ! -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        echo "❌ Arquivo '$ENV_FILE' não encontrado."
        echo "   Copie .env.example para .env e configure as variáveis:"
        echo "   cp .env.example .env"
        return 1
    fi
    return 0
}

check_config_file() {
    if [ ! -f "$SCRIPT_DIR/$CONFIG_FILE" ]; then
        echo "❌ Arquivo '$CONFIG_FILE' não encontrado."
        return 1
    fi
    return 0
}

create_database() {
    echo "Verificando banco de dados '$DB_NAME'..."

    # Verificar se o banco já existe
    if container exec "$POSTGRES_CONTAINER" psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "Banco '$DB_NAME' já existe."
        return 0
    fi

    echo "Criando banco '$DB_NAME'..."
    container exec "$POSTGRES_CONTAINER" psql -U postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
    echo "Banco '$DB_NAME' criado com sucesso."
}

create_volume_and_copy_config() {
    # Criar volume se não existir
    if ! check_volume_exists; then
        echo "Criando volume '$VOLUME_NAME'..."
        container volume create "$VOLUME_NAME"
    fi

    # Copiar config.yaml para o volume usando um container temporário
    echo "Copiando configuração para o volume..."
    cat "$SCRIPT_DIR/$CONFIG_FILE" | container run --rm -i \
        -v "$VOLUME_NAME":/config \
        alpine:latest \
        sh -c "cat > /config/config.yaml"

    echo "Configuração copiada com sucesso."
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando LiteLLM Proxy..."

    # Verificar dependências
    if ! check_dependencies; then
        return 1
    fi

    # Verificar arquivos necessários
    if ! check_env_file; then
        return 1
    fi

    if ! check_config_file; then
        return 1
    fi

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

    # Criar banco de dados se não existir
    create_database

    # Criar volume e copiar configuração
    create_volume_and_copy_config

    # Ler variáveis do .env
    LITELLM_MASTER_KEY=$(grep LITELLM_MASTER_KEY "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)
    LITELLM_SALT_KEY=$(grep LITELLM_SALT_KEY "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)
    ALIBABA_API_KEY=$(grep ALIBABA_API_KEY "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)
    DATABASE_URL=$(grep DATABASE_URL "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)
    REDIS_HOST=$(grep REDIS_HOST "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)
    REDIS_PORT=$(grep REDIS_PORT "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)

    # Criar e iniciar container
    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT":4000 \
        -v "$VOLUME_NAME":/app/config \
        -e LITELLM_MASTER_KEY="$LITELLM_MASTER_KEY" \
        -e LITELLM_SALT_KEY="$LITELLM_SALT_KEY" \
        -e ALIBABA_API_KEY="$ALIBABA_API_KEY" \
        -e DATABASE_URL="$DATABASE_URL" \
        -e REDIS_HOST="$REDIS_HOST" \
        -e REDIS_PORT="$REDIS_PORT" \
        "$IMAGE" \
        --config /app/config/config.yaml

    echo ""
    echo "LiteLLM Proxy iniciado com sucesso!"
    echo "Endpoint: http://localhost:$PORT/v1"
    echo ""
    echo "Aguarde alguns segundos para o LiteLLM inicializar completamente."
    echo "Use '$0 logs' para ver os logs."
}

cmd_stop() {
    echo "Parando LiteLLM Proxy..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do LiteLLM Proxy:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "Endpoint: http://localhost:$PORT/v1"
    else
        echo "Container: $CONTAINER_NAME"
        echo "Status: PARADO ou NÃO EXISTE"
    fi

    echo ""
    echo "Volume '$VOLUME_NAME':"
    if check_volume_exists; then
        container volume list
    else
        echo "  Não existe"
    fi

    echo ""
    echo "Dependências:"
    echo -n "  PostgreSQL ($POSTGRES_CONTAINER): "
    if container list --quiet 2>/dev/null | grep -q "^$POSTGRES_CONTAINER$"; then
        echo "✅ Rodando"
    else
        echo "❌ Parado"
    fi

    echo -n "  Redis ($REDIS_CONTAINER): "
    if container list --quiet 2>/dev/null | grep -q "^$REDIS_CONTAINER$"; then
        echo "✅ Rodando"
    else
        echo "❌ Parado"
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

    container exec -it "$CONTAINER_NAME" /bin/sh
}

cmd_reset() {
    echo "⚠️  ATENÇÃO: Isso vai remover o container e o volume de configuração!"
    read -p "Tem certeza? (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Operação cancelada."
        return 0
    fi

    echo "Removendo container..."
    container stop "$CONTAINER_NAME" 2>/dev/null || true
    container delete "$CONTAINER_NAME" 2>/dev/null || true

    echo "Removendo volume..."
    container volume delete "$VOLUME_NAME" 2>/dev/null || true

    echo "Reset completo. Use '$0 start' para criar um novo container."
}

cmd_models() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    echo "Modelos disponíveis:"
    echo ""

    # Buscar modelos da API do LiteLLM
    local response
    response=$(curl -s http://localhost:$PORT/v1/models \
        -H "Authorization: Bearer $(grep LITELLM_MASTER_KEY "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)" 2>/dev/null)

    if [ -n "$response" ]; then
        echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | while read -r model; do
            echo "  - $model"
        done
    else
        echo "  Não foi possível obter a lista de modelos."
        echo "  Verifique se o LiteLLM está rodando com: $0 logs"
    fi
}

cmd_test() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    echo "Testando conexão com LiteLLM Proxy..."
    echo ""

    # Testar endpoint /v1/models
    echo "1. Listando modelos..."
    local models_response
    models_response=$(curl -s -w "\n%{http_code}" http://localhost:$PORT/v1/models \
        -H "Authorization: Bearer $(grep LITELLM_MASTER_KEY "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)" 2>/dev/null)

    local http_code
    http_code=$(echo "$models_response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        echo "   ✅ Endpoint /v1/models OK"
    else
        echo "   ❌ Endpoint /v1/models falhou (HTTP $http_code)"
        return 1
    fi

    echo ""
    echo "2. Testando chat completion com modelo 'qwen3.5-plus'..."
    local chat_response
    chat_response=$(curl -s -w "\n%{http_code}" http://localhost:$PORT/v1/messages \
        -H "Authorization: Bearer $(grep LITELLM_MASTER_KEY "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2)" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "qwen3.5-plus",
            "messages": [{"role": "user", "content": "Say hello in one word"}],
            "max_tokens": 10
        }' 2>/dev/null)

    http_code=$(echo "$chat_response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        echo "   ✅ Chat completion OK"
        echo ""
        echo "   Resposta:"
        echo "$chat_response" | sed '$d' | python3 -m json.tool 2>/dev/null || echo "$chat_response"
    else
        echo "   ❌ Chat completion falhou (HTTP $http_code)"
        echo "$chat_response"
        return 1
    fi

    echo ""
    echo "✅ Todos os testes passaram!"
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
    models)
        cmd_models
        ;;
    test)
        cmd_test
        ;;
    *)
        print_usage
        exit 1
        ;;
esac