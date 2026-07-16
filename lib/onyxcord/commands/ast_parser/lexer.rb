# frozen_string_literal: true

module OnyxCord
  module Commands
    module AstParser
      # Token types produced by the lexer
      module TokenTypes
        LITERAL = :literal
        CHAIN_DELIMITER = :chain_delimiter
        SUB_CHAIN_START = :sub_chain_start
        SUB_CHAIN_END = :sub_chain_end
        QUOTE_START = :quote_start
        QUOTE_END = :quote_end
        PREVIOUS = :previous
        CHAIN_ARGS_DELIM = :chain_args_delim
        SPACE = :space
        NEWLINE = :newline
        ESCAPE = :escape
      end

      # A token with type, value, and position
      Token = Struct.new(:type, :value, :position)

      # Converts a command chain string into tokens.
      class Lexer
        def initialize(chain, attributes)
          @chain = chain
          @attributes = attributes
          @pos = 0
          @tokens = []
          @quoted = false
          @escaped = false
        end

        # Tokenize the chain and return an array of Token objects.
        # @return [Array<Token>]
        def tokenize
          @chain.each_char.with_index do |char, index|
            @pos = index
            process_char(char)
          end

          flush_literal if @current_literal && !@current_literal.empty?
          @tokens
        end

        private

        def process_char(char)
          if @escaped
            @escaped = false
            add_literal(char)
            return
          end

          if char == '\\'
            @escaped = true
            return
          end

          if @quoted
            process_quoted_char(char)
          else
            process_unquoted_char(char)
          end
        end

        def process_quoted_char(char)
          if char == @attributes[:quote_end]
            @quoted = false
            @tokens << Token.new(TokenTypes::QUOTE_END, char, @pos)
            return
          end

          case char
          when @attributes[:chain_delimiter]
            add_literal("\ue001")
          when @attributes[:previous]
            add_literal("\ue003")
          when ' '
            add_literal("\ue002")
          when "\n"
            add_literal("\ue004")
          else
            add_literal(char)
          end
        end

        def process_unquoted_char(char)
          case char
          when @attributes[:quote_start]
            flush_literal
            @quoted = true
            @tokens << Token.new(TokenTypes::QUOTE_START, char, @pos)
          when @attributes[:sub_chain_start]
            flush_literal
            @tokens << Token.new(TokenTypes::SUB_CHAIN_START, char, @pos)
          when @attributes[:sub_chain_end]
            flush_literal
            @tokens << Token.new(TokenTypes::SUB_CHAIN_END, char, @pos)
          when @attributes[:chain_delimiter]
            flush_literal
            @tokens << Token.new(TokenTypes::CHAIN_DELIMITER, char, @pos)
          when @attributes[:chain_args_delim]
            flush_literal
            @tokens << Token.new(TokenTypes::CHAIN_ARGS_DELIM, char, @pos)
          when @attributes[:previous]
            flush_literal
            @tokens << Token.new(TokenTypes::PREVIOUS, char, @pos)
          when ' '
            flush_literal
            @tokens << Token.new(TokenTypes::SPACE, char, @pos)
          when "\n"
            flush_literal
            @tokens << Token.new(TokenTypes::NEWLINE, char, @pos)
          else
            add_literal(char)
          end
        end

        def add_literal(char)
          @current_literal ||= +""
          @current_literal << char
        end

        def flush_literal
          return unless @current_literal && !@current_literal.empty?

          @tokens << Token.new(TokenTypes::LITERAL, @current_literal.freeze, @pos - @current_literal.length + 1)
          @current_literal = nil
        end
      end
    end
  end
end
