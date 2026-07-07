# frozen_string_literal: true

module RailsAdminNext
  class Version
    # Releases are cut by publishing a Release-Drafter draft: the gem-push workflow stamps
    # the tag's version over these constants at build time, so the in-repo values are only
    # the floor a local `gem build` produces.
    MAJOR = 1
    MINOR = 0
    PATCH = 0
    PRE = nil

    class << self
      # @return [String]
      def to_s
        [MAJOR, MINOR, PATCH, PRE].compact.join(".")
      end
    end
  end
end
