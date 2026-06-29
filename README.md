# OnyxCord

[![Gem](https://img.shields.io/gem/v/onyxcord.svg)](https://rubygems.org/gems/onyxcord)
[![Gem](https://img.shields.io/gem/dt/onyxcord.svg)](https://rubygems.org/gems/onyxcord)

OnyxCord is a Ruby library for Discord bots, interactions, webhooks, modern modals, and Components V2.

Community Discord: https://discord.gg/Jy2tpCUtzM

Languages: [English](#english) | [Portugues](#portugues) | [Espanol](#espanol)

## English

OnyxCord is a Ruby implementation of the Discord API based on `discordrb`, updated with a lighter raw-first core, modern modal components, webhook helpers, and Discord Components V2 support.

```txt
Simple to start, deep enough to control.
```

### Highlights

- Friendly Ruby API for Discord bots.
- Traditional object events for productivity.
- Raw gateway events for performance and lower allocation.
- **Modern async runtime** built on `async` gem with non-blocking gateway, REST and event dispatch.
- **New modern slash command DSL** with `bot.slash`, `execute`, and `bot.sync_application_commands!`.
- Components V2 support with `Text Display`, `Container`, `Section`, `Media Gallery`, `File`, `Separator`, and `Thumbnail`.
- Modern modal components, including `Label`, `Text Display`, modal selects, file upload, radio group, checkbox group, and checkbox.
- Webhooks with embeds, files, and components.
- Runtime helpers, rate limiting, and event execution designed for modern OnyxCord bots.

### Installation

With Bundler:

```ruby
gem 'onyxcord'
```

Then:

```sh
bundle install
```

Or install directly:

```sh
gem install onyxcord
```

### First Bot

```ruby
require 'onyxcord'

bot = OnyxCord::Bot.new(
  token: ENV.fetch('DISCORD_TOKEN'),
  intents: %i[servers server_messages direct_messages message_content],
  mode: :hybrid
)

bot.message(content: 'ping') do |event|
  event.respond!(content: 'pong')
end

bot.application_command(:ping) do |event|
  event.respond(content: 'Pong via Slash Command!')
end

bot.run
```

### Components V2

OnyxCord automatically applies the `IS_COMPONENTS_V2` flag when you use V2 components. You can also enable it explicitly with `components_v2: true`.

```ruby
bot.message(content: '!panel') do |event|
  event.send_message!(content: nil, components_v2: true) do |_builder, view|
    view.text_display(content: '## OnyxCord Panel')
    view.text_display(content: 'Choose an action below.')

    view.row do |row|
      row.button(style: :primary, label: 'Open', custom_id: 'open_panel')
      row.button(style: :secondary, label: 'Help', custom_id: 'help_panel')
    end
  end
end
```

### Modern Modals

```ruby
bot.application_command(:feedback) do |event|
  event.show_modal(title: 'Feedback', custom_id: 'feedback_modal') do |modal|
    modal.label(label: 'Message') do |label|
      label.text_input(
        style: :paragraph,
        custom_id: 'message',
        required: true,
        placeholder: 'Tell us what you think...'
      )
    end

    modal.label(label: 'Category') do |label|
      label.string_select(custom_id: 'category', required: true) do |menu|
        menu.option(label: 'Bug', value: 'bug')
        menu.option(label: 'Idea', value: 'idea')
        menu.option(label: 'Other', value: 'other')
      end
    end
  end
end
```

### Modern Command DSL

```ruby
bot.slash :ban, description: 'Ban a member', default_member_permissions: [:ban_members] do
  user :member, 'Member to ban', required: true
  string :reason, 'Ban reason', max_length: 512

  execute do |ctx|
    ctx.defer(ephemeral: true)
    member = ctx.options[:member]
    reason = ctx.options[:reason] || 'No reason provided'
    ctx.guild.ban(member, reason: reason)
    ctx.edit_original(content: 'Member banned.')
  end
end

bot.sync_application_commands!(server_id: ENV.fetch('DISCORD_SERVER_ID'))
```

### Community

Join the Discord server for support, updates, examples, and feedback: https://discord.gg/Jy2tpCUtzM

## Portugues

OnyxCord e uma biblioteca Ruby para criar bots, integracoes, webhooks e experiencias interativas no Discord.

O projeto foi feito com base no `discordrb`, respeitando a base que tornou bots em Ruby simples de comecar, mas trazendo uma direcao nova para a comunidade: core mais leve, modo raw-first, suporte aos novos componentes de modal e Components V2 do Discord.

```txt
Simples para comecar, profundo para controlar.
```

### Destaques

- API Ruby amigavel para bots do Discord.
- Eventos tradicionais com objetos para quem quer produtividade.
- Eventos raw para quem quer performance e menos alocacao.
- **Runtime async moderno** baseado na gem `async`: gateway, REST e dispatch de eventos nao-bloqueantes.
- **Nova DSL moderna de slash commands** com `bot.slash`, `execute` e `bot.sync_application_commands!`.
- Components V2 com `Text Display`, `Container`, `Section`, `Media Gallery`, `File`, `Separator` e `Thumbnail`.
- Novos componentes de modal, incluindo `Label`, `Text Display`, selects em modal, upload, radio group, checkbox group e checkbox.
- Webhooks com embeds, arquivos e componentes.
- Rate limiter e executor de eventos preparados para o core moderno do OnyxCord.

### Instalacao

Com Bundler:

```ruby
gem 'onyxcord'
```

Depois:

```sh
bundle install
```

Ou direto pelo RubyGems:

```sh
gem install onyxcord
```

### Primeiro Bot

```ruby
require 'onyxcord'

bot = OnyxCord::Bot.new(
  token: ENV.fetch('DISCORD_TOKEN'),
  intents: %i[servers server_messages direct_messages message_content],
  mode: :hybrid
)

bot.message(content: 'ping') do |event|
  event.respond!(content: 'pong')
end

bot.application_command(:ping) do |event|
  event.respond(content: 'Pong via Slash Command!')
end

bot.run
```

### Components V2

O OnyxCord aplica automaticamente a flag `IS_COMPONENTS_V2` quando voce usa componentes V2. Voce tambem pode deixar explicito com `components_v2: true`.

```ruby
bot.message(content: '!painel') do |event|
  event.send_message!(content: nil, components_v2: true) do |_builder, view|
    view.text_display(content: '## Painel OnyxCord')
    view.text_display(content: 'Escolha uma acao abaixo.')

    view.row do |row|
      row.button(style: :primary, label: 'Abrir', custom_id: 'open_panel')
      row.button(style: :secondary, label: 'Ajuda', custom_id: 'help_panel')
    end
  end
end
```

### Modais Modernos

```ruby
bot.application_command(:feedback) do |event|
  event.show_modal(title: 'Feedback', custom_id: 'feedback_modal') do |modal|
    modal.label(label: 'Mensagem') do |label|
      label.text_input(
        style: :paragraph,
        custom_id: 'message',
        required: true,
        placeholder: 'Conte o que voce achou...'
      )
    end

    modal.label(label: 'Categoria') do |label|
      label.string_select(custom_id: 'category', required: true) do |menu|
        menu.option(label: 'Bug', value: 'bug')
        menu.option(label: 'Ideia', value: 'idea')
        menu.option(label: 'Outro', value: 'other')
      end
    end
  end
end
```

### DSL Moderna de Comandos

```ruby
bot.slash :ban, description: 'Bane um membro', default_member_permissions: [:ban_members] do
  user :member, 'Membro que sera banido', required: true
  string :reason, 'Motivo do banimento', max_length: 512

  execute do |ctx|
    ctx.defer(ephemeral: true)
    member = ctx.options[:member]
    reason = ctx.options[:reason] || 'Sem motivo informado'
    ctx.guild.ban(member, reason: reason)
    ctx.edit_original(content: 'Membro banido com sucesso.')
  end
end

bot.sync_application_commands!(server_id: ENV.fetch('DISCORD_SERVER_ID'))
```

### Comunidade

Entre no servidor do Discord para suporte, atualizacoes, exemplos e feedback: https://discord.gg/Jy2tpCUtzM

## Espanol

OnyxCord es una biblioteca Ruby para crear bots, integraciones, webhooks y experiencias interactivas en Discord.

El proyecto esta basado en `discordrb`, manteniendo la idea que hizo simples los bots en Ruby, pero con una direccion moderna para la comunidad: nucleo mas ligero, modo raw-first, componentes modernos de modal y soporte para Components V2 de Discord.

```txt
Simple para empezar, profundo para controlar.
```

### Caracteristicas

- API Ruby amigavel para bots de Discord.
- Eventos tradicionales con objetos para productividad.
- Eventos raw para rendimiento y menos asignaciones.
- **Runtime async moderno** basado en la gem `async`: gateway, REST y dispatch de eventos no bloqueantes.
- **Nueva DSL moderna de slash commands** con `bot.slash`, `execute` y `bot.sync_application_commands!`.
- Components V2 con `Text Display`, `Container`, `Section`, `Media Gallery`, `File`, `Separator` y `Thumbnail`.
- Componentes modernos de modal, incluyendo `Label`, `Text Display`, selects en modal, subida de archivos, radio group, checkbox group y checkbox.
- Webhooks con embeds, archivos y componentes.
- Rate limiter y executor de eventos preparados para el core moderno de OnyxCord.

### Instalacion

Con Bundler:

```ruby
gem 'onyxcord'
```

Despues:

```sh
bundle install
```

O directamente con RubyGems:

```sh
gem install onyxcord
```

### Primer Bot

```ruby
require 'onyxcord'

bot = OnyxCord::Bot.new(
  token: ENV.fetch('DISCORD_TOKEN'),
  intents: %i[servers server_messages direct_messages message_content],
  mode: :hybrid
)

bot.message(content: 'ping') do |event|
  event.respond!(content: 'pong')
end

bot.application_command(:ping) do |event|
  event.respond(content: 'Pong via Slash Command!')
end

bot.run
```

### Components V2

OnyxCord aplica automaticamente la flag `IS_COMPONENTS_V2` cuando usas componentes V2. Tambien puedes activarla de forma explicita con `components_v2: true`.

```ruby
bot.message(content: '!panel') do |event|
  event.send_message!(content: nil, components_v2: true) do |_builder, view|
    view.text_display(content: '## Panel OnyxCord')
    view.text_display(content: 'Elige una accion abajo.')

    view.row do |row|
      row.button(style: :primary, label: 'Abrir', custom_id: 'open_panel')
      row.button(style: :secondary, label: 'Ayuda', custom_id: 'help_panel')
    end
  end
end
```

### Modales Modernos

```ruby
bot.application_command(:feedback) do |event|
  event.show_modal(title: 'Feedback', custom_id: 'feedback_modal') do |modal|
    modal.label(label: 'Mensaje') do |label|
      label.text_input(
        style: :paragraph,
        custom_id: 'message',
        required: true,
        placeholder: 'Cuentanos que piensas...'
      )
    end

    modal.label(label: 'Categoria') do |label|
      label.string_select(custom_id: 'category', required: true) do |menu|
        menu.option(label: 'Bug', value: 'bug')
        menu.option(label: 'Idea', value: 'idea')
        menu.option(label: 'Otro', value: 'other')
      end
    end
  end
end
```

### DSL Moderna de Comandos

```ruby
bot.slash :ban, description: 'Banear a un miembro', default_member_permissions: [:ban_members] do
  user :member, 'Miembro a banear', required: true
  string :reason, 'Motivo del baneo', max_length: 512

  execute do |ctx|
    ctx.defer(ephemeral: true)
    member = ctx.options[:member]
    reason = ctx.options[:reason] || 'Sin motivo'
    ctx.guild.ban(member, reason: reason)
    ctx.edit_original(content: 'Miembro baneado.')
  end
end

bot.sync_application_commands!(server_id: ENV.fetch('DISCORD_SERVER_ID'))
```

### Comunidad

Unete al servidor de Discord para soporte, actualizaciones, ejemplos y feedback: https://discord.gg/Jy2tpCUtzM

## Dependencies

For normal bots:

- Ruby 3.3 or newer.
- Bundler is recommended.
- Build tools for native extensions, especially on Windows.

For voice features:

- `libsodium`
- `libopus`
- `FFmpeg`

Voice dependencies are only needed when your bot joins voice channels, plays audio, or works with voice packets. Text bots, commands, interactions, modals, webhooks, and Components V2 do not need `libsodium`.

## Examples

The `examples/` directory contains ready-to-use examples:

- `ping.rb`: simple ping/pong bot.
- `commands.rb`: classic commands.
- `slash_commands.rb`: slash commands.
- `components.rb`: Components V2.
- `modals.rb`: modern modals.
- `select_menus.rb`: select menus.
- `webhooks.rb`: webhooks.
- `voice_send.rb`: voice sending.

## Development

```sh
bundle install
bundle exec rspec spec
```

If `libsodium` is not installed, voice tests may fail. To test the rest:

```sh
bundle exec rspec $(find spec -name '*_spec.rb' ! -name 'sodium_spec.rb' | sort)
```

## Credits

OnyxCord was created from the foundation of `discordrb`, an important Ruby library for the Discord bot community.

## License

Open source under the MIT license.
