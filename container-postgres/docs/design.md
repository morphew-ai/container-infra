# Design: PostgreSQL 17 no Apple Container

**Data:** 2026-03-11
**Status:** Aprovado

## Contexto

Instalação de PostgreSQL para desenvolvimento local usando Apple containers (https://github.com/apple/container).

### Issue Conhecido

O Apple container usa virtiofs para mounts. O PostgreSQL tenta fazer `chmod/chown` no mount point, e volumes nomeados contêm um diretório `lost+found` que impede a inicialização do PostgreSQL.

**Solução:** Montar no diretório pai `/var/lib/postgresql` em vez de `/var/lib/postgresql/data`. O PostgreSQL criará automaticamente o subdiretório `data` dentro do volume.

## Requisitos

| Item | Decisão |
|------|---------|
| Uso | Desenvolvimento local |
| Versão | PostgreSQL 17 |
| Persistência | Volume nomeado |
| Porta | 5432 |
| Rede | Standalone |
| Recursos | Defaults |

## Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                    macOS Host                        │
│                                                      │
│  ┌──────────────┐      ┌─────────────────────────┐  │
│  │ pg-dev.sh    │      │   Apple Container       │  │
│  │ (script)     │──────│   Runtime               │  │
│  └──────────────┘      └──────────┬──────────────┘  │
│                                   │                  │
│                        ┌──────────▼──────────┐       │
│                        │  Container          │       │
│                        │  "postgres-dev"     │       │
│                        │                     │       │
│                        │  PostgreSQL 17      │       │
│                        │  Porta: 5432        │       │
│                        └──────────┬──────────┘       │
│                                   │                  │
│                        ┌──────────▼──────────┐       │
│                        │  Volume Nomeado     │       │
│                        │  "postgres-data"    │       │
│                        └─────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

## Componentes

### Container `postgres-dev`

- Imagem: `postgres:17-alpine`
- Nome: `postgres-dev`
- Porta: `5432:5432`
- Variáveis de ambiente:
  - `POSTGRES_USER=postgres`
  - `POSTGRES_PASSWORD=postgres`
  - `POSTGRES_DB=postgres`

### Volume `postgres-data`

- Tipo: Volume nomeado (gerenciado pelo Apple container)
- Mount point: `/var/lib/postgresql` (PostgreSQL cria `data/` automaticamente)

### Script `pg-dev.sh`

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container PostgreSQL |
| `stop` | Para o container |
| `status` | Mostra status do container |
| `logs` | Exibe logs do PostgreSQL |
| `shell` | Abre psql no container |
| `reset` | Remove container e volume (zera tudo) |
| `backup <file>` | Exporta dados para arquivo |
| `restore <file>` | Restaura dados de arquivo |

## Conexão

**String de conexão:**
```
postgresql://postgres:postgres@localhost:5432/postgres
```

**Via psql no host:**
```bash
psql -h localhost -U postgres -d postgres
```

**Via container:**
```bash
container exec -it postgres-dev psql -U postgres
```

## Comando de Criação

```bash
container run -d \
  --name postgres-dev \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  -v postgres-data:/var/lib/postgresql \
  postgres:17-alpine
```

## Fluxo de Trabalho

### Setup Inicial

```bash
container volume create postgres-data
./pg-dev.sh start
./pg-dev.sh status
```

### Uso Diário

```bash
./pg-dev.sh start
# trabalhar...
./pg-dev.sh stop  # opcional
```

### Backup

```bash
./pg-dev.sh backup backup_$(date +%Y%m%d).sql
```

### Reset

```bash
./pg-dev.sh reset
```

## Referências

- https://github.com/apple/container
- https://github.com/apple/container/issues/333 (issue de permissão)