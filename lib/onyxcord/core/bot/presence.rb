# frozen_string_literal: true

module OnyxCord
  class Bot
    module Presence
      # Updates presence status.
      # @param status [String] The status the bot should show up as. Can be `online`, `dnd`, `idle`, or `invisible`
      # @param activity [String, nil] The name of the activity to be played/watched/listened to/stream name on the stream.
      # @param url [String, nil] The Twitch URL to display as a stream. nil for no stream.
      # @param since [Integer] When this status was set.
      # @param afk [true, false] Whether the bot is AFK.
      # @param activity_type [Integer] The type of activity status to display.
      #   Can be 0 (Playing), 1 (Streaming), 2 (Listening), 3 (Watching), or 5 (Competing).
      # @see Gateway#send_status_update
      def update_status(status, activity, url, since = 0, afk = false, activity_type = 0)
        gateway_check

        @activity = activity
        @status = status
        @streamurl = url
        type = url ? 1 : activity_type

        activity_obj = activity || url ? { 'name' => activity, 'url' => url, 'type' => type } : nil
        @gateway.send_status_update(status, since, activity_obj, afk)

        # Update the status in the cache
        profile.update_presence('status' => status.to_s, 'activities' => [activity_obj].compact)
      end

      # Sets the currently playing game to the specified game.
      # @param name [String] The name of the game to be played.
      # @return [String] The game that is being played now.
      def game=(name)
        gateway_check
        update_status(@status, name, nil)
      end

      alias_method :playing=, :game=

      # Sets the current listening status to the specified name.
      # @param name [String] The thing to be listened to.
      # @return [String] The thing that is now being listened to.
      def listening=(name)
        gateway_check
        update_status(@status, name, nil, nil, nil, 2)
      end

      # Sets the current watching status to the specified name.
      # @param name [String] The thing to be watched.
      # @return [String] The thing that is now being watched.
      def watching=(name)
        gateway_check
        update_status(@status, name, nil, nil, nil, 3)
      end

      # Sets the currently online stream to the specified name and Twitch URL.
      # @param name [String] The name of the stream to display.
      # @param url [String] The url of the current Twitch stream.
      # @return [String] The stream name that is being displayed now.
      def stream(name, url)
        gateway_check
        update_status(@status, name, url)
        name
      end

      # Sets the currently competing status to the specified name.
      # @param name [String] The name of the game to be competing in.
      # @return [String] The game that is being competed in now.
      def competing=(name)
        gateway_check
        update_status(@status, name, nil, nil, nil, 5)
      end

      # Sets status to online.
      def online
        gateway_check
        update_status(:online, @activity, @streamurl)
      end

      alias_method :on, :online

      # Sets status to idle.
      def idle
        gateway_check
        update_status(:idle, @activity, nil)
      end

      alias_method :away, :idle

      # Sets the bot's status to DnD (red icon).
      def dnd
        gateway_check
        update_status(:dnd, @activity, nil)
      end

      # Sets the bot's status to invisible (appears offline).
      def invisible
        gateway_check
        update_status(:invisible, @activity, nil)
      end
    end
  end
end
