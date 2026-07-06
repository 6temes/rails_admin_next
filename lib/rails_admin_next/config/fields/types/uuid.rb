# frozen_string_literal: true

require "rails_admin_next/config/fields/types/string"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Uuid < RailsAdminNext::Config::Fields::Types::String
          RailsAdminNext::Config::Fields::Types.register(self)
        end
      end
    end
  end
end
