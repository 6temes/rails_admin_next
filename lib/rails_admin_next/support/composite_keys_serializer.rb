# frozen_string_literal: true

module RailsAdminNext
  module Support
    module CompositeKeysSerializer
      # "_" joins the keys, so it is escaped as "~" plus its hex byte. "~" is escaped too so the
      # escape cannot be forged, and both are URL-unreserved. Every other value serializes as-is,
      # keeping existing links valid.
      ESCAPED = /[_~]/
      ESCAPE = /~(\h\h)/

      def self.serialize(keys)
        keys.map { |key| key&.to_s&.gsub(ESCAPED) { format("~%02X", it.ord) } }.join("_")
      end

      def self.deserialize(string)
        string.split("_", -1).map { |key| key.gsub(ESCAPE) { $1.hex.chr } }
      end
    end
  end
end
