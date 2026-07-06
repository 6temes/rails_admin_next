# frozen_string_literal: true

require "rails_admin_next/config/fields/base"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Inet < RailsAdminNext::Config::Fields::Base
          RailsAdminNext::Config::Fields::Types.register(self)
        end
      end
    end
  end
end
