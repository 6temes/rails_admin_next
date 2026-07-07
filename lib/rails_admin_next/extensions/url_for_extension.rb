# frozen_string_literal: true

module RailsAdminNext
  module Extensions
    module UrlForExtension
      def url_for(options, *)
        case options[:id]
        when Array
          options[:id] = RailsAdminNext.config.composite_keys_serializer.serialize(options[:id])
        end
        super
      end
    end
  end
end
