# Changelog

## 2.0.8 - 2026-06-28

### Correcoes de gateway

- Forca WebSocket do Gateway e do cliente generico em HTTP/1.1 para evitar `Async::WebSocket::ConnectionError: Failed to negotiate connection!` ao conectar no Discord.
- Desativa extensoes WebSocket no handshake para evitar close `Error while decoding payload` no Gateway do Discord.
- Remove o empacotamento separado `onyxcord-webhooks`; webhooks continuam incluidos diretamente na gem `onyxcord`.

## 2.0.6 - 2026-06-28

### Correcoes de empacotamento

- Incluidos na gem os arquivos da infraestrutura async que ficaram fora do pacote `2.0.5`: `onyxcord/async/runtime` e `onyxcord/rate_limiter/async_rest`.
- Incluidos na gem os arquivos da DSL moderna de application commands: `onyxcord/application_commands` e seus componentes internos.
- Corrige `LoadError: cannot load such file -- onyxcord/async/runtime` ao usar a gem publicada.

## 2.0.5 - 2026-06-28

### Async Runtime (Infraestrutura nao-bloqueante)

- **`OnyxCord::AsyncRuntime`**: modulo central que gerencia o reactor `async` com `run`, `async` e `sleep`, reaproveitando reactor existente quando disponivel.
- **`EventExecutor::AsyncPool`**: novo pool de workers baseado em `Async::Queue` e fibers, sem threads.
- **Gateway**: `run_async` nao cria mais `Thread.new` — usa `@task = AsyncRuntime.async { run }`. Todos os `sleep` trocados por `AsyncRuntime.sleep`.
- **WebSocket**: usa `AsyncRuntime.async` em vez de `Async do` solto na classe.
- **API REST**: `request` agora delega para `request_async` automaticamente quando dentro de um reactor. `request_async` usa rate limiter async, `AsyncRuntime.sleep`, e retry com limite em 502.
- **Rate Limiter Async**: novo `OnyxCord::RateLimiter::AsyncRest` que evita `mutex.synchronize { sleep }` bloqueante.
- **Bot**: `run`/`stop`/`join` refatorados para o runtime async. `send_temporary_message` e `voice_connect` usam sleeps async.
- Compatibilidade sync mantida: a API publica continua funcionando de forma sincrona quando chamada fora de um reactor.

### Modern Application Commands DSL

- **`bot.slash`, `bot.user_command`, `bot.message_command`**: nova DSL para comandos modernos com definicao e handler unificados.
- **`bot.sync_application_commands!`**: sincroniza todos os commands registrados com a API do Discord de uma vez.
- **`bot.bulk_overwrite_global_application_commands`** e **`bot.bulk_overwrite_guild_application_commands`**: wrappers para bulk overwrite.
- **`ApplicationCommands::Context`**: wrapper com `respond`, `defer`, `edit_original`, `delete_original`, `followup` e acesso a `options`, `guild`, `channel`, `user`.
- **`Interaction#edit_original`**, **`Interaction#delete_original`**, **`Interaction#followup`**: novos aliases dos metodos originais.
- API legacy (`register_application_command` + `application_command`) mantida com compatibilidade total.

### Exemplo da nova DSL

```ruby
bot.slash :ban, description: "Bane um membro", default_member_permissions: [:ban_members] do
  user :member, "Membro que sera banido", required: true
  string :reason, "Motivo do banimento", max_length: 512

  execute do |ctx|
    ctx.defer(ephemeral: true)
    member = ctx.options[:member]
    reason = ctx.options[:reason] || "Sem motivo informado"
    ctx.guild.ban(member, reason: reason)
    ctx.edit_original(content: "Membro banido com sucesso.")
  end
end

bot.sync_application_commands!(server_id: ENV.fetch('DISCORD_SERVER_ID'))
```

### Validacao

- `bundle exec rspec`: 460 exemplos, 0 falhas, 3 pendentes.
- `ruby -c lib/onyxcord/**/*.rb`: todos os arquivos com sintaxe OK.
- `gem build onyxcord.gemspec`: sucesso.

## 2.0.0 - 2026-06-28

### Arquitetura & Performance (Major Refactoring)

- **Runtime 100% Async**: A infraestrutura de threads (`Thread.new`) foi substituída pelo modelo de fibers do Ruby usando a gem `async`. Gateway, heartbeats, fila REST, worker de eventos e comandos agora executam de forma não-bloqueante no reator Async.
- **REST Moderno via HTTPX**: Substituída a gem legada `rest-client` pela `httpx`, trazendo suporte nativo a conexões persistentes (Keep-Alive), HTTP/2, multipart uploads nativos e retries automáticos em erros 502.
- **Gateway via Async-WebSocket**: Substituída a implementação de raw TCP sockets + `websocket-client-simple` por `async-websocket`, proporcionando um event loop de gateway extremamente rápido e escalável.
- **Parse JSON via Oj**: A gem `oj` foi integrada em modo de compatibilidade (`mode: :compat`), acelerando transparentemente todas as serializações e deserializações de pacotes do Discord na lib inteira.
- **Cache Inteligente LRU**: Os caches em memória (usuários, canais, servidores, membros) agora utilizam `LruRedux::ThreadSafeCache`. Os tamanhos padrão foram aumentados (`users: 50_000`, `channels: 10_000`, `servers: 1_000`, `members: 100_000`) e podem ser customizados via `OnyxCord.configure { |c| c.cache_sizes.users = 100_000 }`.
- **Fusão do Webhooks**: A funcionalidade da gem separada `onyxcord-webhooks` foi integrada diretamente no núcleo da gem `onyxcord`; nao ha mais pacote separado para publicar.
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

## 1.1.7 - 2026-06-28

### Melhorias

- Atualizada a descricao publicada no RubyGems para mostrar o convite da comunidade Discord: `https://discord.gg/Jy2tpCUtzM`.
- README mantem as secoes em ingles, portugues e espanhol com o link da comunidade.

### Validacao

- `ruby -c onyxcord.gemspec`: sucesso.

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
