# Relatorio geral da OnyxCord

Data da analise: 2026-06-23

Escopo analisado:
- Gem Ruby `onyxcord` e `onyxcord-webhooks`.
- Areas principais: REST API, gateway WebSocket, cache, executor de eventos, comandos/interactions, voice e webhooks.
- Teste executado: `bundle exec rspec`.

Resultado da validacao atual:
- `bundle exec rspec`: 456 exemplos, 0 falhas, 3 pendentes.
- Cobertura reportada pelo SimpleCov: 60,84% de linhas.
- `gem build onyxcord.gemspec`: sucesso, gerou `onyxcord-1.1.2.gem`.
- `gem build onyxcord-webhooks.gemspec`: sucesso, gerou `onyxcord-webhooks-1.1.2.gem`.

Status das correcoes aplicadas:
- Corrigido retry REST `202` preservando route e major parameter.
- Application commands agora executam pelo `EventExecutor`, sem `Thread.new` direto nesse caminho.
- Adicionado `event_queue_size` com `SizedQueue` opcional.
- Adicionados `runtime_stats`, `cache_stats`, `prune_cache!` e `OnyxCord::API.rate_limiter_stats`.
- Rate limiter REST agora tem `stats`, `prune!` e limpeza automatica de bookkeeping antigo.
- Voice fecha melhor recursos de UDP/WebSocket/thread, e `play_dca` usa `File.open` com bloco.
- Dependencias principais receberam upper bounds conservadores.
- Warning de spec em `spec/bot_spec.rb:114` foi corrigido.

## Resumo executivo

A lib ja tem algumas decisoes boas para performance:
- O modo padrao do bot agora e `hybrid`, equilibrando handlers raw com eventos em objeto.
- O cache padrao global esta em `:none`, o que ajuda a reduzir RAM para bots pequenos.
- Ja existe `EventExecutor::Pool`, evitando uma thread nova para cada evento comum.
- O rate limiter REST ja centraliza buckets, global limit e `retry_after`.
- O gateway usa zlib stream, economizando trafego e CPU em payloads grandes.

Os maiores ganhos agora estao em 5 frentes:
1. Eliminar threads soltas em interactions e waits.
2. Colocar limite/backpressure no executor de eventos.
3. Colocar estrategia de limite/limpeza nos caches e nos mapas do rate limiter.
4. Corrigir um bug provavel no retry de resposta REST `202`.
5. Fechar recursos de voz/arquivos/sockets de forma garantida.

## Prioridade alta

### 1. Corrigir retry de REST `202` em `OnyxCord::API.request`

Arquivo: `lib/onyxcord/api.rb:141-154`

Problema:
- Quando Discord retorna `202` com codigo `110000`, o metodo tenta repetir a request.
- A chamada atual usa `return request(*key, type, *attributes)`.
- Na maior parte da API, `key` e um `Symbol`, entao `*key` tende a quebrar com `TypeError` ou chamar `request` com parametros errados.

Impacto:
- Endpoints baseados em Elasticsearch podem falhar justamente no fluxo em que deveriam aguardar e tentar de novo.

Sugestao:
- Trocar para `return request(key, major_parameter, type, *attributes)`.
- Adicionar spec cobrindo response `202` com `retry_after`.

### 2. Application commands criam `Thread.new` fora do executor

Arquivo: `lib/onyxcord/bot.rb:1679-1704`

Problema:
- O fluxo de `INTERACTION_CREATE` para command cria uma thread direta por comando.
- Isso ignora `EventExecutor::Pool`, ignora `event_workers` e remove qualquer controle de concorrencia.
- Tambem ha logs temporarios com prefixo `>>>` em caminho quente.
- O rescue usa `rescue Exception`, que captura sinais de sistema e saidas do processo.

Impacto:
- Em pico de interactions, o processo pode criar muitas threads, consumindo RAM e escalonamento de CPU.
- Logs verbosos em production aumentam I/O e custo de CPU.

Sugestao:
- Executar handler via `@event_executor.post`.
- Usar `rescue StandardError`.
- Trocar logs `info` temporarios por `debug` ou remover.
- Nomear a thread dentro do bloco do executor, como ja acontece em `call_event`.

### 3. Fila de eventos sem limite

Arquivo: `lib/onyxcord/event_executor.rb:28-42`

Problema:
- `Queue.new` e ilimitada.
- Se os handlers forem mais lentos que os eventos recebidos, a fila cresce sem backpressure.

Impacto:
- Pode virar crescimento progressivo de RAM em servidores grandes ou bots com handlers pesados.

Sugestao:
- Adicionar opcao `event_queue_size`, usando `SizedQueue`.
- Expor comportamento configuravel: bloquear, rejeitar com log, ou executar inline em emergencia.
- Medir tamanho da fila em debug/telemetria.

## Prioridade media

### 4. Rate limiter guarda mutexes e buckets para sempre

Arquivo: `lib/onyxcord/rate_limiter/rest.rb:10-47`

Problema:
- `@route_buckets` e `@bucket_mutexes` crescem conforme novas rotas/major parameters aparecem.
- Para bots que tocam muitos canais, guilds, mensagens ou webhooks, isso pode acumular.

Impacto:
- RAM pequena por item, mas permanente.

Sugestao:
- Guardar `last_used_at` por bucket e limpar entradas antigas.
- Alternativa simples: limitar por LRU.
- Adicionar metodo `prune!` chamado ocasionalmente em `record_response`.

### 5. Cache full pode crescer sem limite

Arquivo: `lib/onyxcord/cache.rb:16-29`

Problema:
- Caches de users, channels, pm_channels, thread_members e server_previews sao Hashes sem TTL/max size.
- O default global e `:none`, mas quem usa `:full` pode segurar muitos objetos.

Impacto:
- Em bots grandes, memoria cresce com o tempo e dificilmente volta.

Sugestao:
- Manter `:none` como default.
- Adicionar opcoes por cache: `max_users`, `max_channels`, `max_messages`, `ttl`.
- Oferecer `bot.prune_cache!` e `bot.cache_stats`.
- Considerar guardar payload cru em modo leve, criando objeto sob demanda.

### 6. `request_chunks` cria buckets por guild sem limpeza

Arquivo: `lib/onyxcord/cache.rb:235-253`

Problema:
- `@request_members_rl[id]` guarda mutex/time por guild e nunca remove.

Impacto:
- Baixo por guild, mas permanente em bots que entram/saem de muitos servidores.

Sugestao:
- Remover no evento de saida de guild.
- Limpar buckets nao usados ha alguns minutos/horas.

### 7. Voice pode deixar arquivo aberto em `play_dca`

Arquivo: `lib/onyxcord/voice/voice_bot.rb:264-299`

Problema:
- `File.open(file)` nao usa bloco nem `ensure`.
- Se erro ocorrer durante validacao ou playback, o descritor pode ficar aberto.

Impacto:
- Vazamento de file descriptor em uso repetido de voz.

Sugestao:
- Usar `File.open(file) do |input_stream| ... end` ou `ensure input_stream&.close`.

### 8. Voice WebSocket nao fecha/junta thread explicitamente

Arquivo: `lib/onyxcord/voice/network.rb:321-344`

Problema:
- `destroy` apenas seta `@heartbeat_running = false`.
- Nao fecha o WebSocket, nao fecha UDP e nao faz join da thread.

Impacto:
- Possivel sobra de thread/socket em reconexoes ou destroy repetido.

Sugestao:
- Implementar close de `@client`, close de UDP socket e `@thread.join` com timeout curto.
- Adicionar spec com fake socket/client garantindo cleanup.

### 9. Busy wait com `sleep` em pontos sensiveis

Arquivos:
- `lib/onyxcord/voice/network.rb:338`
- `lib/onyxcord/voice/voice_bot.rb:315`
- `lib/onyxcord/bot.rb:413`

Problema:
- Loops `sleep until` e `sleep while` sao simples, mas acordam periodicamente sem evento real.

Impacto:
- Baixo em poucos bots, mas piora com muitas conexoes/threads.

Sugestao:
- Usar `ConditionVariable` para readiness/pausa.
- Para voice playback, manter cuidado para nao prejudicar o timing de audio.

## Prioridade baixa / limpeza

### 10. Webhooks nao usam o rate limiter central

Arquivo: `lib/onyxcord/webhooks/client.rb`

Problema:
- Chamadas usam `RestClient.post/patch/delete` direto.
- Isso e simples, mas nao aproveita `OnyxCord::RateLimiter::Rest`.

Impacto:
- Clientes de webhook intensivos podem bater 429 com menos controle.

Sugestao:
- Criar transport compartilhado leve para webhooks.
- Ou criar um rate limiter dedicado por webhook URL.

### 11. Dependencias abertas demais

Arquivos:
- `onyxcord.gemspec`
- `onyxcord-webhooks.gemspec`

Problema:
- Algumas dependencias permitem qualquer versao acima do minimo, como `rest-client >= 2.0.0`, `websocket-client-simple >= 0.9.0`, `ffi >= 1.9.24` e `opus-ruby` sem limite.

Impacto:
- Atualizacao futura pode quebrar performance ou compatibilidade.

Sugestao:
- Definir upper bounds conservadores, por exemplo `< 3` quando fizer sentido.
- Rodar CI com Ruby 3.3 e 3.4 se a gem prometer suporte moderno.

### 12. Arquivo `bot.rb` esta grande demais

Arquivo: `lib/onyxcord/bot.rb` tem cerca de 1971 linhas.

Problema:
- O arquivo mistura boot, REST helpers, dispatch, cache orchestration, interactions, voice e commands.

Impacto:
- Dificulta otimizar sem regressao.

Sugestao:
- Extrair aos poucos:
  - `Bot::Interactions`
  - `Bot::Dispatch`
  - `Bot::Voice`
  - `Bot::ApplicationCommands`
- Fazer isso depois das correcoes de runtime, para nao misturar refactor com bugfix.

## Otimizacoes praticas sugeridas

### Perfil leve recomendado para usuarios

Documentar no README um preset para bots pequenos:

```ruby
OnyxCord.configure do |config|
  config.mode = :raw
  config.cache = :none
  config.event_executor = :pool
  config.event_workers = 2
end
```

Para bots medios:

```ruby
OnyxCord.configure do |config|
  config.mode = :hybrid
  config.cache = :minimal
  config.event_workers = 4
end
```

### Medir antes/depois

Criar specs/benchmarks simples para:
- `INTERACTION_CREATE` com 1000 commands simulados.
- `MESSAGE_CREATE` em modo `raw`, `hybrid` e `object`.
- crescimento de `@users`, `@channels`, `@thread_members`.
- fila do executor quando handler dorme 50ms.

### Instrumentacao leve

Adicionar metodos opcionais:
- `bot.runtime_stats`
- `bot.cache_stats`
- `bot.event_queue_size`
- `OnyxCord::API.rate_limiter_stats`

Isso ajuda a diagnosticar RAM e lentidao sem profiler externo.

## Plano de acao recomendado

1. Corrigir `API.request` no retry `202` e adicionar spec.
2. Remover threads soltas dos application commands e usar `@event_executor`.
3. Remover logs `>>>` ou rebaixar para `debug`.
4. Trocar `Queue` por `SizedQueue` configuravel.
5. Adicionar `cache_stats` e `prune_cache!`.
6. Fechar corretamente recursos de voice (`File.open`, UDP, WS, thread).
7. Adicionar limpeza/LRU no rate limiter REST.
8. Depois disso, refatorar `bot.rb` em modulos menores.

## Conclusao

A OnyxCord ja esta no caminho certo para ser pratica no modo padrao `hybrid` e ainda leve quando o usuario escolher `raw` com cache `:none`. O maior risco atual nao e um unico algoritmo pesado, e sim crescimento sem limite: threads por interaction, fila ilimitada, caches sem TTL e mapas internos que nao expiram. Corrigir esses pontos deve reduzir RAM em carga real, deixar o bot mais previsivel em pico e facilitar otimizar depois sem mexer na API publica.
