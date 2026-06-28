# Changelog

## 2.0.0 - 2026-06-28

### Arquitetura & Performance (Major Refactoring)

- **Runtime 100% Async**: A infraestrutura de threads (`Thread.new`) foi substituída pelo modelo de fibers do Ruby usando a gem `async`. Gateway, heartbeats, fila REST, worker de eventos e comandos agora executam de forma não-bloqueante no reator Async.
- **REST Moderno via HTTPX**: Substituída a gem legada `rest-client` pela `httpx`, trazendo suporte nativo a conexões persistentes (Keep-Alive), HTTP/2, multipart uploads nativos e retries automáticos em erros 502.
- **Gateway via Async-WebSocket**: Substituída a implementação de raw TCP sockets + `websocket-client-simple` por `async-websocket`, proporcionando um event loop de gateway extremamente rápido e escalável.
- **Parse JSON via Oj**: A gem `oj` foi integrada em modo de compatibilidade (`mode: :compat`), acelerando transparentemente todas as serializações e deserializações de pacotes do Discord na lib inteira.
- **Cache Inteligente LRU**: Os caches em memória (usuários, canais, servidores, membros) agora utilizam `LruRedux::ThreadSafeCache`. Os tamanhos padrão foram aumentados (`users: 50_000`, `channels: 10_000`, `servers: 1_000`, `members: 100_000`) e podem ser customizados via `OnyxCord.configure { |c| c.cache_sizes.users = 100_000 }`.
- **Fusão do Webhooks**: A funcionalidade da gem separada `onyxcord-webhooks` foi integrada diretamente no núcleo da gem `onyxcord`. A gem `onyxcord-webhooks` agora atua apenas como um shim de transição deprecado.
- **Alvo Ruby ≥ 3.4**: Atualizada a versão mínima requerida do Ruby para aproveitar as otimizações modernas do interpretador e fibras.

## 1.1.8 - 2026-06-28

### Correcoes

- `Components::Label` agora delega `custom_id`, `value` e `values` para o componente interativo interno, mantendo compatibilidade com codigo legado de modal que itera por `event.components`.
- Modais modernos continuam preservando `label`, `description` e `component`, enquanto `event.value(custom_id)`, `event.values(custom_id)` e acesso direto em `event.components` funcionam de forma consistente.

### Validacao

- `bundle exec rspec spec/components_v2_spec.rb`: sucesso.
- `bundle exec rspec`: 460 exemplos, 0 falhas, 3 pendentes.
- `ruby -c lib/onyxcord/data/component.rb`: sucesso.
- `ruby -c spec/components_v2_spec.rb`: sucesso.
- `gem build onyxcord.gemspec`: sucesso.
- `gem build onyxcord-webhooks.gemspec`: sucesso.

## 1.1.7 - 2026-06-28

### Melhorias

- Atualizada a descricao publicada no RubyGems para mostrar o convite da comunidade Discord: `https://discord.gg/Jy2tpCUtzM`.
- README mantem as secoes em ingles, portugues e espanhol com o link da comunidade.

### Validacao

- `ruby -c onyxcord.gemspec`: sucesso.
- `ruby -c onyxcord-webhooks.gemspec`: sucesso.

## 1.1.6 - 2026-06-28

### Melhorias

- Adicionado suporte aos novos componentes de modal do Discord: `Label`, `File Upload`, `Radio Group`, `Checkbox Group` e `Checkbox`.
- Modais agora preservam o `id` do componente `Label` ao gerar o payload.
- Parser de componentes agora expoe `label` e `description` em `Components::Label`.

### Validacao

- `bundle exec rspec spec/components_v2_spec.rb`: 15 exemplos, 0 falhas.
- `ruby -c lib/onyxcord/webhooks/modal.rb`: sucesso.
- `ruby -c lib/onyxcord/data/component.rb`: sucesso.
- `ruby -c spec/components_v2_spec.rb`: sucesso.

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
