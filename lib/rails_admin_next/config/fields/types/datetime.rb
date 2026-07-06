# frozen_string_literal: true

require "rails_admin_next/config/fields/base"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Datetime < RailsAdminNext::Config::Fields::Base
          RailsAdminNext::Config::Fields::Types.register(self)

          def parse_value(value)
            ::Time.zone.parse(value) if value.present?
          end

          def parse_input(params)
            params[name] = parse_value(params[name]) if params[name]
          end

          register_instance_option :filter_operators do
            %w[default between today yesterday this_week last_week] + (required? ? [] : %w[_separator _not_null _null])
          end

          register_instance_option :date_format do
            :long
          end

          register_instance_option :i18n_scope do
            %i[time formats]
          end

          register_instance_option :strftime_format do
            ::I18n.t(date_format, scope: i18n_scope, raise: true)
          rescue ::I18n::ArgumentError
            "%B %d, %Y %H:%M"
          end

          register_instance_option :html_attributes do
            {
              required: required?,
              step: 1
            }
          end

          register_instance_option :sort_reverse? do
            true
          end

          register_instance_option :queryable? do
            false
          end

          register_instance_option :formatted_value do
            time = value || default_value
            if time
              ::I18n.l(time, format: strftime_format)
            else
              "".html_safe
            end
          end

          register_instance_option :partial do
            :form_datetime
          end

          # Picker-only legacy option; native HTML5 inputs render per the browser locale, so it is ignored.
          register_deprecated_instance_option :momentjs_format do
            RailsAdminNext.deprecator.warn("The momentjs_format configuration option is deprecated and ignored; date/time fields now use native HTML5 inputs.")
          end

          # The native <input type="datetime-local" step="1"> control accepts and emits ISO 8601 only.
          def form_value
            value&.in_time_zone&.strftime("%Y-%m-%dT%H:%M:%S") || form_default_value
          end
        end
      end
    end
  end
end
