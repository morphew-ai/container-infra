# Container Infra

Infraestrutura de containers Apple Container para desenvolvimento local.

## O que é este projeto?

Repositório centralizado para gerenciar containers de desenvolvimento usando [Apple Container](https://github.com/apple/container) no macOS.

## Estrutura

```
container-infra/
├── .claude/
│   ├── settings.local.json       # Permissões unificadas
│   └── skills/
│       └── apple-container-infra/
│           └── SKILL.md          # Skill para Claude Code
├── container-postgres/           # PostgreSQL 17
│   ├── pg-dev.sh
│   ├── .env.example
│   └── README.md
├── container-redis/              # Redis 7
│   ├── redis-dev.sh
│   └── README.md
├── container-litellm/            # LiteLLM Proxy
│   ├── litellm-dev.sh
│   ├── config.yaml
│   ├── .env.example
│   └── README.md
└── container-{service}/          # Futuros containers
```

## Containers Disponíveis

| Container | Serviço | Porta | String de Conexão |
|-----------|---------|-------|-------------------|
| container-postgres | PostgreSQL 17 | 5432 | `postgresql://postgres:postgres@192.168.64.1:5432` |
| container-redis | Redis 7 | 6379 | `redis://192.168.64.1:6379` |
| container-litellm | LiteLLM Proxy | 4000 | `http://192.168.64.1:4000/v1` |

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Uso Rápido

```bash
# PostgreSQL
cd container-postgres
./pg-dev.sh start

# Redis
cd container-redis
./redis-dev.sh start

# LiteLLM (requer PostgreSQL e Redis rodando)
cd container-litellm
cp .env.example .env
# Edite .env com suas API keys
./litellm-dev.sh start
```

## Criando Novos Containers

Use a skill `apple-container-infra` no Claude Code:

```
Crie container-qdrant seguindo a skill apple-container-infra
```

## Padrões do Projeto

Todos os containers seguem:

- **Secrets externos** via `.env` (nunca no script)
- **Config montado como volume** (read-only)
- **Volumes separados** para data e config
- **Imagens com versão específica** (não `:latest`)
- **Gateway IP** `192.168.64.1` para comunicação entre containers

## Auditoria

Para verificar se um container segue os padrões:

```
Audite o container-postgres seguindo a skill apple-container-infra
```

## Referências

- [Apple Container](https://github.com/apple/container)
- [Apple Container Issue #333](https://github.com/apple/container/issues/333) - Volume mounting issue