# OnyxProfiler Integration for OnyxCord

O OnyxProfiler foi integrado ao OnyxCord para fornecer observabilidade e profiling da sua aplicação Discord.

## Configuração

### 1. Arquivo de Configuração

O arquivo `onyxprofiler.config` já foi criado na raiz do projeto com as seguintes configurações:

```yaml
dashboard_url: http://localhost:3000
api_key: onyx_pk_5a7d8e36516948e0b26728d651f5c066
project: onyxcord
service: gateway
environment: production
enabled: true
buffer_size: 500
batch_size: 25
```

### 2. Variáveis de Ambiente (Opcional)

Você pode sobrescrever as configurações usando variáveis de ambiente:

- `ONYX_PROFILER_DASHBOARD_URL` - URL da dashboard
- `ONYX_PROFILER_API_KEY` - Chave de API
- `ONYX_PROFILER_PROJECT` - Nome do projeto
- `ONYX_PROFILER_SERVICE` - Nome do serviço
- `ONYX_PROFILER_ENVIRONMENT` - Ambiente (production, development, etc.)
- `ONYX_PROFILER_ENABLED` - Habilitar/desabilitar profiler
- `ONYX_PROFILER_BUFFER_SIZE` - Tamanho do buffer de eventos
- `ONYX_PROFILER_BATCH_SIZE` - Tamanho do batch para envio

## Uso

### Inicialização Automática

O OnyxProfiler é configurado automaticamente quando o arquivo `onyxprofiler.config` existe no diretório de trabalho. Não é necessário código adicional.

### Instrumentação Manual

Para instrumentar código personalizado:

```ruby
require 'onyxcord'

# Instrumentar uma operação específica
OnyxCord::Profiler.instrument('cache.fetch', key: 'users') do
  cache.fetch('users')
end

# Com metadados adicionais
OnyxCord::Profiler.instrument('database.query', 
  table: 'users', 
  operation: 'select'
) do
  User.where(active: true)
end
```

### Instrumentação Automática

O OnyxCord já possui instrumentação automática nos seguintes pontos:

- **Gateway Events**: Todos os eventos do gateway Discord são instrumentados automaticamente
- **Bot Dispatch**: O processamento de eventos no bot é instrumentado

### Flush de Eventos

Para enviar eventos manualmente para a dashboard:

```ruby
# Enviar eventos para o exporter configurado
OnyxCord::Profiler.flush_to

# Apenas limpar o buffer sem enviar
OnyxCord::Profiler.flush
```

## Dashboard

Acesse a dashboard em `http://localhost:3000` para visualizar:

- Métricas de performance
- Tempo de execução de eventos
- Análise de bottlenecks
- Ranking por arquivo/classe/método
- Queries lentas
- Uso de memória
- Estatísticas de GC

## Exemplo Completo

```ruby
require 'onyxcord'

bot = OnyxCord::Bot.new(token: 'YOUR_TOKEN')

# Evento ready - já instrumentado automaticamente
bot.ready do
  puts "Bot está online!"
  
  # Instrumentação manual adicional
  OnyxCord::Profiler.instrument('bot.ready.custom') do
    # Seu código de inicialização
    setup_commands
  end
end

# Message event - já instrumentado automaticamente
bot.message do |event|
  OnyxCord::Profiler.instrument('message.handler', 
    command: event.content
  ) do
    # Seu handler de mensagem
    handle_message(event)
  end
end

bot.run
```

## Troubleshooting

### Profiler não está configurando

Verifique se o arquivo `onyxprofiler.config` existe no diretório onde seu bot está rodando.

### Eventos não aparecendo na dashboard

1. Verifique se a dashboard está rodando em `http://localhost:3000`
2. Confirme que a API key está correta
3. Verifique se `ONYX_PROFILER_ENABLED` não está definido como `false`

### Performance impact

O OnyxProfiler é projetado para ter impacto mínimo na performance. Se necessário, você pode:

- Aumentar o `buffer_size` para enviar eventos em batches maiores
- Desabilitar o profiler em produção usando `ONYX_PROFILER_ENABLED=false`
- Ajustar o `batch_size` para controlar a frequência de envios

## Integração com OnyxProfiler

O OnyxCord usa a integração `OnyxProfiler::Integrations::OnyxCord` quando disponível, que fornece instrumentação específica para bots Discord.

Para mais informações sobre o OnyxProfiler, visite: https://github.com/kruldevb/OnyxProfiler
