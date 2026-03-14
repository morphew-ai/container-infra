# container-litellm

LiteLLM Proxy para desenvolvimento local usando Apple containers.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado
- PostgreSQL (container-postgres) rodando
- Redis (container-redis) rodando

## Instalação

```bash
# Crie o arquivo .env
cp .env.example .env
# Edite .env com suas API keys
```

## Uso

```bash
# Iniciar LiteLLM
./litellm-dev.sh start

# Verificar status
./litellm-dev.sh status

# Listar modelos
./litellm-dev.sh models

# Testar conexão
./litellm-dev.sh test
```

### Endpoint

```
http://localhost:4000/v1
```

Para comunicação entre containers, use o IP do gateway:
```
http://192.168.64.1:4000/v1
```

### Autenticação

```bash
Authorization: Bearer sk-litellm-dev-key
```

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Cria banco e inicia o container |
| `stop` | Para o container |
| `status` | Mostra status do container |
| `logs` | Exibe logs do LiteLLM |
| `shell` | Abre shell no container |
| `reset` | Remove container (mantém banco e cache) |
| `models` | Lista modelos disponíveis |
| `test` | Testa conexão com o proxy |

## Modelos Configurados

| Model Name | Provider | Tipo |
|------------|----------|------|
| `lmstudio` | LMStudio | Local |
| `qwen3.5-plus` | Alibaba DashScope | Cloud |
| `glm-5` | Alibaba DashScope | Cloud |
| `minimax-m2.5` | Alibaba DashScope | Cloud |
| `kimi-k2.5` | Alibaba DashScope | Cloud |

## Exemplos de Uso

### OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key="sk-litellm-dev-key"
)

response = client.chat.completions.create(
    model="qwen3.5-plus",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

### Claude SDK

```python
from anthropic import Anthropic

client = Anthropic(
    base_url="http://localhost:4000/v1",
    api_key="sk-litellm-dev-key"
)
```

### curl

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-litellm-dev-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.5-plus",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Configuração

### config.yaml

Define os modelos e providers disponíveis.

### .env

Variáveis de ambiente:
- `LITELLM_MASTER_KEY` - Chave de autenticação do proxy
- `LITELLM_SALT_KEY` - Chave para criptografar API keys no banco
- `ALIBABA_API_KEY` - API key do Alibaba DashScope
- `DATABASE_URL` - Conexão com PostgreSQL

## Dependências

O LiteLLM depende dos seguintes containers:

- **PostgreSQL** (postgres-dev): Armazena logs de requisições
- **Redis** (redis-dev): Cache de responses

## Referências

- [Apple Container](https://github.com/apple/container)
- [LiteLLM Documentation](https://docs.litellm.ai/docs/proxy_server)
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)