# frozen_string_literal: true

module OnyxCord
  class Bot
    module OAuth
      # Creates a new application to do OAuth authorization with.
      # @deprecated This method requires a bearer token that this bot class does not manage.
      #   Use the Discord Developer Portal or a dedicated OAuth2 flow instead.
      # @param name [String] What your application should be called.
      # @param redirect_uris [Array<String>] URIs that Discord should redirect your users to after authorizing.
      # @return [Array(String, String)] your applications' client ID and client secret.
      def create_oauth_application(name, redirect_uris)
        raise NotImplementedError,
              'create_oauth_application requires a bearer token not managed by this bot. ' \
              'Use the Discord Developer Portal or implement a dedicated OAuth2 flow.'
      end

      # Changes information about your OAuth application
      # @deprecated This method requires a bearer token that this bot class does not manage.
      # @param name [String] What your application should be called.
      # @param redirect_uris [Array<String>] URIs that Discord should redirect your users to after authorizing.
      # @param description [String] A string that describes what your application does.
      # @param icon [String, nil] A data URI for your icon image.
      def update_oauth_application(name, redirect_uris, description = '', icon = nil)
        raise NotImplementedError,
              'update_oauth_application requires a bearer token not managed by this bot.'
      end
    end
  end
end
