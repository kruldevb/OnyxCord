# frozen_string_literal: true

module OnyxCord
  # Utility class for wrapping paginated endpoints.
  #
  # A Paginator wraps a block that, given the previous page, returns the next.
  # Iterating consumes the configuration. Each call to {#each} yields every
  # item across pages in the requested direction until the configured `limit`
  # is reached, the block returns an empty/nil result, or the consumer stops
  # early.
  #
  # The configuration block (page fetcher) is single-use: a single
  # {Enumerator} lifecycle consumes each page at most once. Calling {#each}
  # again raises {OnyxCord::Paginator::InvalidStateError} so the caller is
  # aware that the next page has changed.
  #
  # If you want independent enumeration, call {#each} on a fresh paginator
  # instance, or use {Enumerable#take}, {#first}, etc. on the first
  # enumerator (which captures the partial result before consuming more).
  class Paginator
    include Enumerable

    # Maximum number of repeated pages we will tolerate, to detect
    # non-progressing paginated endpoints.
    REPEATED_PAGE_LIMIT = 10

    class Error < StandardError
    end
    class InvalidStateError < Error
      def initialize(msg = 'Paginator has already been enumerated')
        super
      end
    end
    class NoProgressError < Error
      def initialize(msg = 'Pagination produced repeated results; aborting')
        super
      end
    end

    # @return [Integer] the total amount of elements that have been fetched so far in the current enumeration.
    #   When no enumeration has run, this is 0.
    attr_reader :amount_fetched

    # Creates a new {Paginator}.
    # @param limit [Integer, nil] the maximum number of items to yield before stopping.
    # @param direction [:up, :down] the iteration order.
    # @yield [Array, nil] the last page yielded (or nil for the first call).
    #   The block returns the next page.
    def initialize(limit, direction, &block)
      raise ArgumentError, 'block must be supplied' unless block

      raise ArgumentError, "direction must be :up or :down, got #{direction.inspect}" unless %i[up down].include?(direction.to_sym)

      unless limit.nil? || (limit.is_a?(Integer) && !limit.negative?)
        raise ArgumentError, "limit must be nil or a non-negative Integer, got #{limit.inspect}"
      end

      @limit = limit
      @direction = direction.to_sym
      @block = block
      @amount_fetched = 0
      @enumerated = false
    end

    # Yields every item produced by the wrapped request, until it returns
    # no more results, the configured `limit` is reached, or the consumer
    # stops early.
    #
    # When no block is given, returns an +Enumerator+ that can be walked
    # lazily via +Enumerator#lazy+.
    def each
      return enum_for(:each) unless block_given?

      raise InvalidStateError if @enumerated
      @enumerated = true

      # Capture local state; multiple parallel enumerators would require
      # semantically distinct sources of truth, so we disallow a second pass.
      fetched = 0
      last_page = nil
      repeats = 0
      last_signature = nil

      loop do
        break if @limit && fetched >= @limit

        begin
          page = @block.call(last_page)
        rescue LocalJumpError, StopIteration
          # Consumer break propagated here unexpectedly; treat as completion.
          break
        end

        break if page == nil || (page.respond_to?(:empty?) && page.empty?)

        signature = page_signature(page)
        if signature == last_signature
          repeats += 1
          raise NoProgressError if repeats >= REPEATED_PAGE_LIMIT
        else
          repeats = 0
          last_signature = signature
        end

        items = case @direction
                when :down then page.each
                when :up   then page.reverse_each
                end

        items.each do |item|
          break if @limit && fetched >= @limit

          consumer_returned = false

          begin
            begin
              yield item
              consumer_returned = false
            ensure
              @amount_fetched += 1
              fetched += 1
            end
          rescue LocalJumpError
            consumer_returned = true
          end

          return fetched if consumer_returned
          break if @limit && fetched >= @limit
        end

        last_page = page
        break if @limit && fetched >= @limit
      end

      fetched
    end

    private

    # Build a deterministic "signature" of a page to detect when the wrapped
    # API returns the same data over and over, which would otherwise loop
    # forever.
    def page_signature(page)
      if page.is_a?(Array)
        a = page.first(5)
        a.empty? ? :empty : a
      else
        arr = page.to_a
        arr.empty? ? :empty : arr.first(5)
      end
    end
  end
end