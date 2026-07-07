# frozen_string_literal: true

require "rails_admin_next/config/fields/types/text"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Serialized < RailsAdminNext::Config::Fields::Types::Text
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)

          register_instance_option :formatted_value do
            RailsAdminNext.yaml_dump(value) unless value.nil?
          end

          def parse_value(value)
            value.present? ? (RailsAdminNext.yaml_load(value) || nil) : nil
          end

          def parse_input(params)
            params[name] = parse_value(params[name]) if params[name].is_a?(::String)
          end
        end
      end
    end
  end
end
