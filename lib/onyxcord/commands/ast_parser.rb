# frozen_string_literal: true

require_relative 'ast_parser/nodes'
require_relative 'ast_parser/lexer'
require_relative 'ast_parser/parser'
require_relative 'ast_parser/executor'

module OnyxCord::Commands
  # AST-based command chain parser and executor.
  # Provides a Lexer -> Parser -> Executor pipeline as an alternative to the legacy parser.
  #
  # Usage:
  #   AstParser.execute(chain_string, bot, event)
  #
  module AstParser
    # Parse and execute a command chain string using the AST pipeline.
    # @param chain [String] The command chain to parse and execute.
    # @param bot [Commands::Bot] The bot to execute against.
    # @param event [CommandEvent] The event to execute with.
    # @return [String] The result of execution.
    def self.execute(chain, bot, event)
      attributes = bot.attributes

      # Pre-flight budget check on input size
      max_input = attributes[:max_chain_input_bytes] || (16 * 1024)
      if chain.bytesize > max_input
        event.respond "Chain input exceeds maximum size (#{max_input} bytes)!"
        return ''
      end

      # Lexer -> Tokens
      lexer = Lexer.new(chain, attributes)
      tokens = lexer.tokenize

      # Parser -> AST
      parser = Parser.new(tokens, attributes)

      # Pre-flight execution count check
      estimated = parser.estimated_executions
      max_expanded = attributes[:max_expanded_executions] || 100
      if estimated > max_expanded
        event.respond "Command chain would execute too many commands (#{estimated} > #{max_expanded})!"
        return ''
      end

      root = parser.parse

      # Executor -> Result
      executor = Executor.new(root, bot)
      executor.execute(event)
    rescue ExecutionBudgetExceeded => e
      event.respond e.message
      ''
    end
  end
end
