# Changelog

## 1.1.3 - 2026-06-23

### Melhorias

- Alterado o modo padrao do bot para `:hybrid`, mantendo suporte a handlers raw e eventos em objeto sem configuracao extra.
- Adicionado `event_queue_size` para permitir fila de eventos com limite via `SizedQueue`.
- Application commands agora usam o `EventExecutor`, evitando criacao direta de threads por interaction.
- Adicionados `runtime_stats`, `cache_stats`, `prune_cache!` e `OnyxCord::API.rate_limiter_stats` para diagnostico de memoria e runtime.
- Rate limiter REST agora expoe `stats`, `prune!` e limpeza automatica de bookkeeping antigo.
- Voice recebeu limpeza mais segura de UDP, WebSocket, threads e leitura DCA com fechamento garantido de arquivo.
- Dependencias principais receberam upper bounds conservadores para reduzir risco de quebra em releases futuras.

### Correcoes

- Corrigido retry de respostas REST `202` para reutilizar a rota e o major parameter originais.
- Removidos logs temporarios de interaction no caminho quente de dispatch.
- Corrigido warning de spec causado por expectativa em cache de usuarios nulo.

### Validacao

- `bundle exec rspec`: 456 exemplos, 0 falhas, 3 pendentes.
- RuboCop nos arquivos alterados: sem offenses.
- `gem build onyxcord.gemspec`: sucesso.
- `gem build onyxcord-webhooks.gemspec`: sucesso.
