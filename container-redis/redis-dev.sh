#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="redis-dev"
VOLUME_NAME="redis-data"
PORT=6379
IMAGE="redis:7-alpine"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|backup|restore|info}"
    echo ""
    echo "Comandos:"
    echo "  start         Inicia o container Redis"
    echo "  stop          Para o container"
    echo "  status        Mostra status do container"
    echo "  logs          Exibe logs do Redis"
    echo "  shell         Abre redis-cli no container"
    echo "  reset         Remove container e volume (CUIDADO: apaga todos os dados)"
    echo "  backup <file> Exporta dados para arquivo RDB"
    echo "  restore <file> Restaura dados de arquivo RDB"
    echo "  info          Mostra informações do Redis"
    echo ""
    echo "String de conexão: redis://localhost:$PORT"
}

check_container_running() {
    container list --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"
}

check_volume_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_NAME$"
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando Redis..."

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
    if ! check_volume_exists; then
        echo "Criando volume '$VOLUME_NAME'..."
        container volume create "$VOLUME_NAME"
    fi

    # Criar e iniciar container
    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT":6379 \
        -v "$VOLUME_NAME":/data \
        "$IMAGE"

    echo ""
    echo "Redis iniciado com sucesso!"
    echo "String de conexão: redis://localhost:$PORT"
    echo ""
    echo "Aguarde alguns segundos para o Redis inicializar completamente."
}

cmd_stop() {
    echo "Parando Redis..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Redis:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "String de conexão: redis://localhost:$PORT"
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

    container exec -it "$CONTAINER_NAME" redis-cli
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
    container volume delete "$VOLUME_NAME" 2>/dev/null || true

    echo "Reset completo. Use '$0 start' para criar um novo banco."
}

cmd_backup() {
    local backup_file="$1"

    if [ -z "$backup_file" ]; then
        echo "Erro: Especifique o arquivo de backup."
        echo "Uso: $0 backup <arquivo.rdb>"
        return 1
    fi

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    echo "Forçando save do Redis..."
    container exec "$CONTAINER_NAME" redis-cli BGSAVE

    # Aguardar o save completar
    sleep 2

    echo "Copiando dump.rdb para '$backup_file'..."
    container exec "$CONTAINER_NAME" cat /data/dump.rdb > "$backup_file"
    echo "Backup concluído: $backup_file"
}

cmd_restore() {
    local backup_file="$1"

    if [ -z "$backup_file" ]; then
        echo "Erro: Especifique o arquivo de backup."
        echo "Uso: $0 restore <arquivo.rdb>"
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

    echo "Parando Redis para restauração..."
    container exec "$CONTAINER_NAME" redis-cli SHUTDOWN NOSAVE 2>/dev/null || true

    # Aguardar container parar
    sleep 2

    echo "Copiando '$backup_file' para o container..."
    cat "$backup_file" | container exec -i "$CONTAINER_NAME" sh -c 'cat > /data/dump.rdb'

    echo "Reiniciando container..."
    container start "$CONTAINER_NAME"

    echo "Restauração concluída."
}

cmd_info() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    echo "Informações do Redis:"
    echo ""
    container exec "$CONTAINER_NAME" redis-cli INFO server
    echo ""
    echo "Estatísticas:"
    container exec "$CONTAINER_NAME" redis-cli INFO stats | grep -E "(total_connections|total_commands|keyspace)"
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
    info)
        cmd_info
        ;;
    *)
        print_usage
        exit 1
        ;;
esac