# frozen_string_literal: true

class OnyxCord::Commands::Bot
  module MessageDispatch
    private

    # Internal handler for MESSAGE_CREATE that is overwritten to allow for command handling
    def create_message(data)
      message = OnyxCord::Message.new(data, self)
      return message if message.from_bot? && !@should_parse_self
      return message if message.webhook? && !@attributes[:webhook_commands]

      unless message.author
        OnyxCord::LOGGER.warn("Received a message (#{message.inspect}) with nil author! Ignoring, please report this if you can")
        return
      end

      event = OnyxCord::Commands::CommandEvent.new(message, self)

      chain = trigger?(message)
      return message unless chain

      # Don't allow spaces between the prefix and the command
      if chain.start_with?(' ') && !@attributes[:spaces_allowed]
        debug('Chain starts with a space')
        return message
      end

      if chain.strip.empty?
        debug('Chain is empty')
        return message
      end

      execute_chain(chain, event)

      # Return the message so it doesn't get parsed again during the rest of the dispatch handling
      message
    end

    # Check whether a message should trigger command execution, and if it does, return the raw chain

    def trigger?(message)
      if @prefix.is_a? String
        standard_prefix_trigger(message.content, @prefix)
      elsif @prefix.is_a? Array
        @prefix.map { |e| standard_prefix_trigger(message.content, e) }.reduce { |m, e| m || e }
      elsif @prefix.respond_to? :call
        @prefix.call(message)
      end
    end

    def standard_prefix_trigger(message, prefix)
      return nil unless message.start_with? prefix

      message[prefix.length..]
    end
  end
end
