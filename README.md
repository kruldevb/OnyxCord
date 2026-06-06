# OnyxCord

[![Gem](https://img.shields.io/gem/v/onyxcord.svg)](https://rubygems.org/gems/onyxcord)
[![Gem](https://img.shields.io/gem/dt/onyxcord.svg)](https://rubygems.org/gems/onyxcord)

OnyxCord é uma biblioteca Ruby para criar bots, integrações, webhooks e experiências interativas no Discord.

O projeto foi feito com base no `discordrb`, respeitando a base que tornou bots em Ruby simples de começar, mas trazendo uma direção nova para a comunidade: core mais leve, modo raw-first, suporte aos novos componentes de modal e suporte aos Components V2 do Discord.

A ideia é simples:

```txt
Simples para começar, profundo para controlar.
```

## Destaques

- API Ruby amigável para bots do Discord.
- Eventos tradicionais com objetos para quem quer produtividade.
- Eventos raw para quem quer performance e menos alocação.
- Components V2 com `Text Display`, `Container`, `Section`, `Media Gallery`, `File`, `Separator` e `Thumbnail`.
- Novos componentes de modal, incluindo `Label`, `Text Display`, selects em modal, upload, radio group e checkbox group.
- Webhooks com embeds, arquivos e componentes.
- Rate limiter e executor de eventos preparados para o core moderno do OnyxCord.

## Instalação

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

No Windows, use uma instalação Ruby com DevKit para compilar dependências nativas quando necessário.

## Primeiro bot

Crie um arquivo `bot.rb`:

```ruby
require 'onyxcord'

bot = OnyxCord::Bot.new(
  token: ENV.fetch('DISCORD_TOKEN'),
  intents: %i[servers server_messages direct_messages message_content]
)

bot.message(content: 'ping') do |event|
  event.respond!(content: 'pong')
end

bot.run
```

Execute:

```sh
ruby bot.rb
```

## Eventos raw

Para bots que precisam de performance, o OnyxCord pode trabalhar direto com o payload do Gateway:

```ruby
require 'onyxcord'

bot = OnyxCord::Bot.new(
  token: ENV.fetch('DISCORD_TOKEN'),
  mode: :raw,
  intents: :minimal
)

bot.raw(:MESSAGE_CREATE) do |payload|
  puts payload['d']['content']
end

bot.raw(/MESSAGE_/) do |payload|
  puts "evento: #{payload['t']}"
end

bot.raw do |payload|
  puts "op: #{payload['op']}"
end

bot.run
```

Use `mode: :raw` quando quiser evitar criação de objetos pesados por padrão. Use `mode: :object` quando quiser o caminho mais compatível com a API tradicional.

## Components V2

Components V2 usam a flag `IS_COMPONENTS_V2` (`1 << 15`, valor `32768`). No OnyxCord, essa flag é aplicada automaticamente quando você usa componentes V2, mas você também pode deixar explícito com `components_v2: true`.

Importante: em mensagens V2, o Discord desativa `content`, `embeds`, `poll` e stickers tradicionais. O conteúdo visual deve ser enviado como componentes.

```ruby
bot.message(content: '!painel') do |event|
  event.send_message!(content: nil, components_v2: true) do |_builder, view|
    view.text_display(content: '## Painel OnyxCord')
    view.text_display(content: 'Escolha uma ação abaixo.')

    view.row do |row|
      row.button(
        style: :primary,
        label: 'Abrir',
        custom_id: 'open_panel'
      )

      row.button(
        style: :secondary,
        label: 'Ajuda',
        custom_id: 'help_panel'
      )
    end
  end
end

bot.button(custom_id: 'open_panel') do |event|
  event.respond(content: 'Painel aberto!', ephemeral: true)
end
```

## Container V2

Containers funcionam como uma estrutura visual rica para agrupar textos, botões, imagens e arquivos:

```ruby
bot.message(content: '!status') do |event|
  event.send_message!(content: nil) do |_builder, view|
    view.container(color: '#8b5cf6') do |container|
      container.text_display(content: '### Status do servidor')
      container.separator(divider: true, spacing: :small)

      container.section do |section|
        section.text_display(content: 'Tudo funcionando normalmente.')
        section.button(
          style: :success,
          label: 'Atualizar',
          custom_id: 'refresh_status'
        )
      end
    end
  end
end
```

Ao usar `container`, `section`, `text_display`, `media_gallery`, `file_display`, `separator` ou `thumbnail`, o OnyxCord detecta Components V2 e envia a flag correta.

## Modais modernos

O OnyxCord também suporta os componentes novos de modal:

```ruby
bot.register_application_command(
  :feedback,
  'Enviar feedback',
  server_id: ENV.fetch('DISCORD_SERVER_ID')
)

bot.application_command(:feedback) do |event|
  event.show_modal(title: 'Feedback', custom_id: 'feedback_modal') do |modal|
    modal.label(label: 'Mensagem') do |label|
      label.text_input(
        style: :paragraph,
        custom_id: 'message',
        required: true,
        placeholder: 'Conte o que você achou...'
      )
    end

    modal.label(label: 'Categoria') do |label|
      label.string_select(custom_id: 'category', required: true) do |menu|
        menu.option(label: 'Bug', value: 'bug')
        menu.option(label: 'Ideia', value: 'idea')
        menu.option(label: 'Outro', value: 'other')
      end
    end

    modal.text_display(content: 'Obrigado por ajudar a melhorar a comunidade.')
  end
end

bot.modal_submit(custom_id: 'feedback_modal') do |event|
  categoria = event.values('category')&.first
  mensagem = event.value('message')

  event.respond(
    content: "Feedback recebido em #{categoria}: #{mensagem}",
    ephemeral: true
  )
end
```

## Webhooks

Também existe um cliente de webhooks:

```ruby
require 'onyxcord/webhooks'

client = OnyxCord::Webhooks::Client.new(
  url: ENV.fetch('DISCORD_WEBHOOK_URL')
)

client.execute do |builder|
  builder.content = 'Mensagem enviada por webhook.'

  builder.add_embed do |embed|
    embed.title = 'OnyxCord'
    embed.description = 'Webhook funcionando.'
    embed.timestamp = Time.now
  end
end
```

Webhook com Components V2:

```ruby
client.execute(components_v2: true) do |builder, view|
  builder.content = nil

  view.text_display(content: '## Atualização da comunidade')
  view.text_display(content: 'Nova versão do OnyxCord disponível.')
end
```

Quando componentes são enviados por webhook, o OnyxCord adiciona `with_components=true` na URL automaticamente.

## Dependências

Para bots normais:

- Ruby 3.2 ou superior.
- Bundler recomendado.
- Build tools para extensões nativas, principalmente no Windows.

Para recursos de voz:

- `libsodium`
- `libopus`
- `FFmpeg`

Você só precisa dessas dependências de voz se o bot for entrar em canais de voz, tocar áudio ou trabalhar com pacotes de voz. Bots de texto, comandos, interactions, modais, webhooks e Components V2 funcionam sem `libsodium`.

## Exemplos

A pasta `examples/` contém exemplos prontos:

- `ping.rb`: bot simples de ping/pong.
- `commands.rb`: comandos tradicionais.
- `slash_commands.rb`: slash commands.
- `components.rb`: Components V2.
- `modals.rb`: modais modernos.
- `select_menus.rb`: menus de seleção.
- `webhooks.rb`: webhooks.
- `voice_send.rb`: envio de voz.

## Desenvolvimento

Para trabalhar no OnyxCord localmente:

```sh
bundle install
bundle exec rspec spec
```

Se `libsodium` não estiver instalado, os testes de voz podem falhar. Para testar o restante:

```sh
bundle exec rspec $(find spec -name '*_spec.rb' ! -name 'sodium_spec.rb' | sort)
```

## Créditos

OnyxCord foi criado a partir da base do `discordrb`, uma biblioteca Ruby importante para a comunidade de bots no Discord.

Este projeto continua essa ideia com uma proposta atualizada:

- manter Ruby acessível para bots do Discord;
- modernizar o core;
- adicionar suporte aos novos componentes do Discord;
- entregar uma base aberta para a comunidade evoluir.

## Licença

Distribuído como open source sob a licença MIT.
