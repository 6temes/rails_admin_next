# frozen_string_literal: true

require "rails_admin_next/config/fields/types/text"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Serialized < RailsAdminNext::Config::Fields::Types::Text
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)

          # The YAML is admin-supplied, so loading permits no class beyond the scalars a
          # plain value needs. Dumping strips Hash/Array subclasses (a store's
          # HashWithIndifferentAccess) so what the form shows can be loaded back.
          PERMITTED_CLASSES = [::Date, ::Symbol, ::Time].freeze

          register_instance_option :formatted_value do
            YAML.dump(plain(value)) unless value.nil?
          end

          def parse_value(value)
            value.present? ? (YAML.safe_load(value, permitted_classes: PERMITTED_CLASSES) || nil) : nil
          end

          def parse_input(params)
            params[name] = parse_value(params[name]) if params[name].is_a?(::String)
          end

          private

          def plain(object)
            case object
            when Hash then object.to_h { |key, value| [plain(key), plain(value)] }
            when Array then object.map { plain(it) }
            else object
            end
          end
        end
      end
    end
  end
end
