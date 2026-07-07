# frozen_string_literal: true

require "rails_admin_next/config/fields/types/datetime"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Date < RailsAdminNext::Config::Fields::Types::Datetime
          RailsAdminNext::Config::Fields::Types.register(self)

          def parse_value(value)
            ::Date.parse(value) if value.present?
          end

          register_instance_option :date_format do
            :long
          end

          register_instance_option :i18n_scope do
            %i[date formats]
          end

          register_instance_option :html_attributes do
            {
              required: required?
            }
          end

          # The native <input type="date"> control accepts and emits %Y-%m-%d only.
          def form_value
            value&.strftime("%Y-%m-%d") || form_default_value
          end
        end
      end
    end
  end
end
