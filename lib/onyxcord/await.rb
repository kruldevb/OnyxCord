# frozen_string_literal: true

module OnyxCord
  # Awaits are a way to register new, temporary event handlers on the fly. Awaits can be
  # registered using {Bot#add_await}, {User#await}, {Message#await} and {Channel#await}.
  #
  # Awaits contain a block that will be called before the await event will be triggered.
  # If this block returns anything that is not `false` exactly, the await will be deleted.
  # If no block is present, the await will also be deleted. This is an easy way to make
  # temporary events that are only temporary under certain conditions.
  #
  # When `reusable: true` is set, the await persists after firing and can trigger multiple times.
  # Use {Bot#cancel_await} to programmatically remove a reusable await.
  #
  # Besides the given block, an {OnyxCord::Events::AwaitEvent} will also be executed with the key and
  # the type of the await that was triggered. It's possible to register multiple events
  # that trigger on the same await.
  class Await
    # The key that uniquely identifies this await.
    # @return [Symbol] The unique key.
    attr_reader :key

    # The class of the event that this await listens for.
    # @return [Class] The event class.
    attr_reader :type

    # The attributes of the event that will be listened for.
    # @return [Hash] A hash of attributes.
    attr_reader :attributes

    # Whether this await persists after firing.
    # @return [true, false]
    attr_reader :reusable

    # Makes a new await. For internal use only.
    # @!visibility private
    def initialize(bot, key, type, attributes, block = nil, reusable: false)
      @bot = bot
      @key = key
      @type = type
      @attributes = attributes
      @block = block
      @reusable = reusable
      @handler_class = EventContainer.handler_class(type)
    end

    # Checks whether the await can be triggered by the given event, and if it can, execute the block
    # and return its result along with this await's key.
    # @param event [Event] An event to check for.
    # @return [Array] This await's key and whether or not it should be deleted. If there was no match, both are nil.
    def match(event)
      return [nil, nil] unless event.instance_of?(@type)

      dummy_handler = @handler_class.new(@attributes, @bot)
      return [nil, nil] unless dummy_handler.matches?(event)

      should_delete = if @reusable
                        false
                      elsif @block && @block.call(event) != false
                        true
                      elsif !@block
                        true
                      else
                        false
                      end

      [@key, should_delete]
    end
  end
end
