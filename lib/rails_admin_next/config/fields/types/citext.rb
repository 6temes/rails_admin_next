# frozen_string_literal: true

require "rails_admin_next/config/fields/types/text"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Citext < Text
          RailsAdminNext::Config::Fields::Types.register(:citext, self)
        end
      end
    end
  end
end
