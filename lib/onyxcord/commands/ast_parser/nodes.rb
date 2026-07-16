# frozen_string_literal: true

module OnyxCord
  module Commands
    module AstParser
      # Base class for all AST nodes
      class Node
        attr_reader :position

        def initialize(position = nil)
          @position = position
        end
      end

      # A single command with its arguments
      class CommandNode < Node
        attr_reader :name, :arguments

        def initialize(name, arguments = [], position = nil)
          super(position)
          @name = name
          @arguments = arguments
        end
      end

      # A chain of commands separated by chain_delimiter
      class ChainNode < Node
        attr_reader :commands

        def initialize(commands = [], position = nil)
          super(position)
          @commands = commands
        end
      end

      # A sub-chain enclosed in sub_chain_start/sub_chain_end
      class SubchainNode < Node
        attr_reader :chain

        def initialize(chain, position = nil)
          super(position)
          @chain = chain
        end
      end

      # A repeat expression: repeat:N <chain>
      class RepeatNode < Node
        attr_reader :count, :chain

        def initialize(count, chain, position = nil)
          super(position)
          @count = count
          @chain = chain
        end
      end

      # A literal string token (command name or argument)
      class LiteralNode < Node
        attr_reader :value

        def initialize(value, position = nil)
          super(position)
          @value = value
        end
      end

      # The previous result placeholder
      class PreviousNode < Node; end

      # Chain arguments (before chain_args_delim)
      class ChainArgsNode < Node
        attr_reader :args, :chain

        def initialize(args, chain, position = nil)
          super(position)
          @args = args
          @chain = chain
        end
      end
    end
  end
end
