# frozen_string_literal: true

require "rails_admin_next/config/fields/types/datetime"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Timestamp < RailsAdminNext::Config::Fields::Types::Datetime
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)
        end
      end
    end
  end
end
