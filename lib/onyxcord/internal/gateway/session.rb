# frozen_string_literal: true

module OnyxCord
  module Internal
    module Gateway
      class Session
        attr_reader :session_id, :resume_gateway_url
        attr_accessor :sequence

        def initialize(session_id, resume_gateway_url)
          @session_id = session_id
          @sequence = 0
          @suspended = false
          @invalid = false
          @resume_gateway_url = resume_gateway_url
        end

        def suspend
          @suspended = true
        end

        def suspended?
          @suspended
        end

        def resume
          @suspended = false
        end

        def invalidate
          @invalid = true
          @resume_gateway_url = nil
        end

        def invalid?
          @invalid
        end

        def should_resume?
          suspended? && !invalid?
        end
      end
    end
  end
end
