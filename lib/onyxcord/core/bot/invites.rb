# frozen_string_literal: true

module OnyxCord
  class Bot
    module Invites
      # Makes the bot join an invite to a server.
      # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
      def accept_invite(invite)
        resolved = invite(invite).code
        REST::Invite.accept(token, resolved)
      end

      # Creates an OAuth invite URL that can be used to invite this bot to a particular server.
      # @param server [Server, nil] The server the bot should be invited to, or nil if a general invite should be created.
      # @param permission_bits [String, Integer] Permission bits that should be appended to invite url.
      # @param redirect_uri [String] Redirect URI that should be appended to invite url.
      # @param scopes [Array<String>] Scopes that should be appended to invite url.
      # @return [String] the OAuth invite URL.
      def invite_url(server: nil, permission_bits: nil, redirect_uri: nil, scopes: ['bot'])
        @client_id ||= bot_application.id

        query = URI.encode_www_form({
          client_id: @client_id,
          guild_id: server&.id,
          permissions: permission_bits,
          redirect_uri: redirect_uri,
          scope: scopes.join(' ')
        }.compact)

        "https://discord.com/oauth2/authorize?#{query}"
      end

      # Revokes an invite to a server. Will fail unless you have the *Manage Server* permission.
      # It is recommended that you use {Invite#delete} instead.
      # @param code [String, Invite] The invite to revoke. For possible formats see {#resolve_invite_code}.
      def delete_invite(code)
        invite = resolve_invite_code(code)
        REST::Invite.delete(token, invite)
      end
    end
  end
end
