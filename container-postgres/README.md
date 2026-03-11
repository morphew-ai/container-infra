# container-postgres

PostgreSQL 17 para desenvolvimento local usando Apple containers.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Instalação

```bash
# Clone o repositório
git clone https://github.com/morphew-ai/container-infra.git
cd container-infra/container-postgres

# Configure o ambiente
cp .env.example .env
# Edite .env com suas credenciais

# Torne o script executável
chmod +x postgres-dev.sh
```

## Uso

```bash
# Iniciar PostgreSQL
./postgres-dev.sh start

# Verificar status
./postgres-dev.sh status

# Conectar ao banco
./postgres-dev.sh shell
```

### Strings de Conexão

| Contexto | String |
|----------|--------|
| Localhost | `postgresql://postgres:postgres@localhost:5432/postgres` |
| Inter-container | `postgresql://postgres:postgres@192.168.64.1:5432/postgres` |

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container PostgreSQL |
| `stop` | Para o container |
| `status` | Mostra status do container |
| `logs` | Exibe logs do PostgreSQL |
| `shell` | Abre psql no container |
| `reset` | Remove container e volume (apaga todos os dados) |
| `backup <file>` | Exporta dados para arquivo SQL |
| `restore <file>` | Restaura dados de arquivo SQL |

## Configuração

Edite o arquivo `.env` para configurar credenciais:

```bash
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
```

## Persistência

Os dados são persistidos em um volume nomeado gerenciado pelo Apple container. O volume sobrevive a reinicializações do container.

## Nota Técnica

O Apple container usa virtiofs para volumes. O PostgreSQL não pode inicializar diretamente em `/var/lib/postgresql/data` devido ao diretório `lost+found` presente nos volumes nomeados. A solução é montar em `/var/lib/postgresql` e deixar o PostgreSQL criar o subdiretório `data/`.

Ver [issue #333](https://github.com/apple/container/issues/333) para mais detalhes.

## Referências

- [Apple Container](https://github.com/apple/container)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)