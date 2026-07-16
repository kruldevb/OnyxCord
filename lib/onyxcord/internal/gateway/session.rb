# frozen_string_literal: true

module OnyxCord
  module Internal
    module Gateway
      class Session
        attr_reader :session_id, :resume_gateway_url

        def initialize(session_id, resume_gateway_url)
          @session_id = session_id
          @resume_gateway_url = resume_gateway_url
          @state = :active
        end

        def suspend
          @state = :suspended if @state == :active
        end

        def suspended?
          @state == :suspended
        end

        def resume
          @state = :active if @state == :suspended
        end

        def invalidate
          @state = :invalid
        end

        def invalid?
          @state == :invalid
        end

        def active?
          @state == :active
        end

        def should_resume?
          suspended? && !invalid?
        end
      end
    end
  end
end
