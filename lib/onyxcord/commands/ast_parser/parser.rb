# frozen_string_literal: true

module OnyxCord
  module Commands
    module AstParser
      # Raised when the parser encounters a budget limit before execution
      class ExecutionBudgetExceeded < RuntimeError; end

      # Builds an AST from tokens produced by the Lexer.
      class Parser
        def initialize(tokens, attributes)
          @tokens = tokens
          @attributes = attributes
          @pos = 0
        end

        # Parse tokens into an AST.
        # @return [ChainNode] the root chain node
        def parse
          chain_args = parse_chain_args
          commands = parse_chain_commands

          root = ChainNode.new(commands)
          chain_args ? ChainArgsNode.new(chain_args, root) : root
        end

        # Calculate the total expanded execution count (for budget pre-check).
        # @return [Integer]
        def estimated_executions
          count = 0
          @tokens.each do |token|
            if token.type == TokenTypes::LITERAL && token.value.start_with?('repeat:')
              n = token.value.sub('repeat:', '').to_i
              count += [@attributes[:max_chain_repeat] || 25, n].min
            else
              count += 1
            end
          end
          [count, @attributes[:max_expanded_executions] || 100].min
        end

        private

        def parse_chain_args
          delim = @attributes[:chain_args_delim]
          return nil if delim.nil? || delim.empty?

          delim_index = nil
          depth = 0
          quoted = false

          @tokens.each_with_index do |token, i|
            if token.type == TokenTypes::QUOTE_START
              quoted = true
              next
            end
            if token.type == TokenTypes::QUOTE_END
              quoted = false
              next
            end
            next if quoted

            if token.type == TokenTypes::SUB_CHAIN_START
              depth += 1
            elsif token.type == TokenTypes::SUB_CHAIN_END
              depth -= 1
            elsif token.type == TokenTypes::CHAIN_ARGS_DELIM && depth.zero?
              delim_index = i
              break
            end
          end

          return nil unless delim_index

          args_tokens = @tokens[0...delim_index]
          @pos = delim_index + 1

          args = []
          current_arg = []
          args_tokens.each do |token|
            if token.type == TokenTypes::SPACE || token.type == TokenTypes::NEWLINE
              args << current_arg.join unless current_arg.empty?
              current_arg = []
            else
              current_arg << token.value
            end
          end
          args << current_arg.join unless current_arg.empty?

          args
        end

        def parse_chain_commands
          commands = []
          current_cmd_tokens = []
          depth = 0
          quoted = false

          remaining = @tokens[@pos..]
          return commands unless remaining

          remaining.each do |token|
            case token.type
            when TokenTypes::QUOTE_START
              quoted = true
              current_cmd_tokens << token
            when TokenTypes::QUOTE_END
              quoted = false
              current_cmd_tokens << token
            when TokenTypes::SUB_CHAIN_START
              depth += 1
              current_cmd_tokens << token
            when TokenTypes::SUB_CHAIN_END
              depth -= 1
              current_cmd_tokens << token
            when TokenTypes::CHAIN_DELIMITER
              if depth.zero? && !quoted
                cmd = build_command(current_cmd_tokens)
                commands << cmd if cmd
                current_cmd_tokens = []
              else
                current_cmd_tokens << token
              end
            else
              current_cmd_tokens << token
            end
          end

          commands << build_command(current_cmd_tokens) unless current_cmd_tokens.empty?
          commands
        end

        def build_command(tokens)
          return nil if tokens.empty?

          if tokens.first.type == TokenTypes::SUB_CHAIN_START && tokens.last.type == TokenTypes::SUB_CHAIN_END
            inner = tokens[1..-2]
            sub_parser = Parser.new(inner, @attributes)
            return SubchainNode.new(sub_parser.parse)
          end

          name_tokens = []
          arg_tokens_list = []
          current_args = []
          in_args = false
          depth = 0
          quoted = false

          tokens.each do |token|
            case token.type
            when TokenTypes::CHAIN_DELIMITER
              # Should not appear inside build_command (handled by parse_chain_commands)
              # but if it does, treat as literal
              current_args << token
            when TokenTypes::QUOTE_START
              quoted = true
              current_args << token
            when TokenTypes::QUOTE_END
              quoted = false
              current_args << token
            when TokenTypes::SUB_CHAIN_START
              depth += 1
              current_args << token
            when TokenTypes::SUB_CHAIN_END
              depth -= 1
              current_args << token
            when TokenTypes::SPACE
              if !quoted && depth.zero? && !in_args && !name_tokens.empty?
                in_args = true
              else
                current_args << token
              end
            when TokenTypes::PREVIOUS
              current_args << PreviousNode.new(token.position)
            else
              if in_args || depth > 0 || quoted
                current_args << token
              else
                name_tokens << token
              end
            end
          end

          name = name_tokens.map(&:value).join
          return nil if name.empty?

          arguments = parse_arguments(current_args)
          CommandNode.new(name.to_sym, arguments)
        end

        def parse_arguments(tokens)
          args = []
          current = []

          tokens.each do |token|
            if token.is_a?(Token) && (token.type == TokenTypes::SPACE || token.type == TokenTypes::NEWLINE)
              unless current.empty?
                args << reconstruct_value(current)
                current = []
              end
            else
              current << token
            end
          end
          args << reconstruct_value(current) unless current.empty?
          args
        end

        def reconstruct_value(tokens)
          tokens.filter_map do |t|
            next if t.is_a?(Token) && (t.type == TokenTypes::QUOTE_START || t.type == TokenTypes::QUOTE_END)

            val = t.is_a?(Node) ? t : t.value
            val = val.gsub("\ue002", ' ').gsub("\ue001", @attributes[:chain_delimiter]).gsub("\ue003", @attributes[:previous]).gsub("\ue004", "\n") if val.is_a?(String)
            val
          end.join
        end
      end
    end
  end
end
