# frozen_string_literal: true

require "rails_admin_next/config/fields/types/numeric"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Integer < RailsAdminNext::Config::Fields::Types::Numeric
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)

          register_instance_option :sort_reverse? do
            serial?
          end
        end
      end
    end
  end
end
