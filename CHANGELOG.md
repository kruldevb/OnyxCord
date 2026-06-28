# Changelog

## 1.1.5 - 2026-06-28

### Melhorias

- Attachment uploads agora enviam metadata (`id`, `filename`) no payload JSON e usam chaves `files[N]` no multipart body, seguindo a especificacao da API do Discord.
- Novos helpers `attachment_payload` e `multipart_body` adicionados nativamente em `API::Channel`, `API::Interaction` e `API::Webhook`.
- Metodos afetados: `Channel.create_message`, `Channel.start_thread_in_forum_or_media_channel`, `Interaction.create_interaction_response`, `Webhook.token_edit_message` e `Webhook.token_execute_webhook`.

### Correcoes

- Corrigido `Channel.create_message` para sanitizar o parametro `tts`, forçando `false` quando o valor nao e booleano.

## 1.1.4 - 2026-06-28

### Melhorias

- `MediaGallery` agora aceita URLs diretas e hashes no builder, como `media_gallery('https://...')`, alem do formato em bloco.
- `FileComponent`/`file_display` agora aceita a URL do attachment como primeiro argumento, como `file_display('attachment://arquivo.txt')`.

### Correcoes

- Parser de `MediaGallery` e `FileUpload` ficou mais tolerante quando o payload nao traz `items` ou `values`.

### Validacao

- `bundle exec rspec spec/components_v2_spec.rb`: 13 exemplos, 0 falhas.

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
