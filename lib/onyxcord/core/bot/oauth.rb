# frozen_string_literal: true

module OnyxCord
  class Bot
    module OAuth
      # Creates a new application to do OAuth authorization with. This allows you to use OAuth to authorize users using
      # Discord. For information how to use this, see the docs: https://discord.com/developers/docs/topics/oauth2
      # @param name [String] What your application should be called.
      # @param redirect_uris [Array<String>] URIs that Discord should redirect your users to after authorizing.
      # @return [Array(String, String)] your applications' client ID and client secret to be used in OAuth authorization.
      def create_oauth_application(name, redirect_uris)
        response = JSON.parse(REST.create_oauth_application(@token, name, redirect_uris))
        [response['id'], response['secret']]
      end

      # Changes information about your OAuth application
      # @param name [String] What your application should be called.
      # @param redirect_uris [Array<String>] URIs that Discord should redirect your users to after authorizing.
      # @param description [String] A string that describes what your application does.
      # @param icon [String, nil] A data URI for your icon image (for example a base 64 encoded image), or nil if no icon
      #   should be set or changed.
      def update_oauth_application(name, redirect_uris, description = '', icon = nil)
        REST.update_oauth_application(@token, name, redirect_uris, description, icon)
      end
    end
  end
end
