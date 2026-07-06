# frozen_string_literal: true

require "rails_admin_next/config/fields/base"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Numeric < RailsAdminNext::Config::Fields::Base
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)

          register_instance_option :filter_operators do
            %w[default between] + (required? ? [] : %w[_separator _not_null _null])
          end

          register_instance_option :view_helper do
            :number_field
          end
        end
      end
    end
  end
end
