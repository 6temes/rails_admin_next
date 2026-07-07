# frozen_string_literal: true

require "rails_admin_next/config/fields/types/numeric"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Decimal < RailsAdminNext::Config::Fields::Types::Numeric
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)

          register_instance_option :html_attributes do
            {
              required: required?,
              step: "any"
            }
          end
        end
      end
    end
  end
end
