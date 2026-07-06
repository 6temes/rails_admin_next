# frozen_string_literal: true

require "rails_admin_next/config/fields/types/datetime"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Time < RailsAdminNext::Config::Fields::Types::Datetime
          RailsAdminNext::Config::Fields::Types.register(self)

          def parse_value(value)
            parsed = super
            return unless parsed

            # Anchor to the dummy date in the zone *before* serializing so the wall-clock time is
            # preserved at that date's UTC offset. A native <input type="time"> submits a bare
            # %H:%M:%S, which Time.zone.parse resolves against today — whose DST offset can differ
            # from the time column's 2000-01-01 storage date and would otherwise shift the hour.
            abstract_model.model.type_for_attribute(name.to_s).serialize(parsed.change(year: 2000, month: 1, day: 1))
          end

          register_instance_option :filter_operators do
            %w[default between] + (required? ? [] : %w[_separator _not_null _null])
          end

          register_instance_option :strftime_format do
            "%H:%M"
          end

          # The native <input type="time" step="1"> control accepts and emits %H:%M:%S.
          def form_value
            value&.in_time_zone&.strftime("%H:%M:%S") || form_default_value
          end
        end
      end
    end
  end
end
