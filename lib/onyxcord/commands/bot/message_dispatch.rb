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
        @logger.warn("Received a message (id=#{message.id}) with nil author! Ignoring")
        return
      end

      chain = trigger?(message)
      return message unless chain

      if chain.start_with?(' ') && !@attributes[:spaces_allowed]
        debug('Chain starts with a space')
        return message
      end

      if chain.strip.empty?
        debug('Chain is empty')
        return message
      end

      max_input = @attributes[:max_chain_input_bytes] || (16 * 1024)
      if chain.bytesize > max_input
        debug("Chain input #{chain.bytesize}b exceeds max #{max_input}b, ignoring")
        return message
      end

      event = OnyxCord::Commands::CommandEvent.new(message, self)
      execute_chain(chain, event)

      message
    end

    # Check whether a message should trigger command execution, and if it does, return the raw chain.
    # Returns on first matching prefix for arrays.
    def trigger?(message)
      content = message.content
      if @prefix.is_a?(String)
        standard_prefix_trigger(content, @prefix)
      elsif @prefix.is_a?(Array)
        @prefix.each do |p|
          result = standard_prefix_trigger(content, p)
          return result if result
        end
        nil
      elsif @prefix.respond_to?(:call)
        @prefix.call(message)
      end
    end

    def standard_prefix_trigger(message, prefix)
      return nil unless message.start_with?(prefix)

      message[prefix.length..]
    end
  end
end
