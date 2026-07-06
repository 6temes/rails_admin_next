# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Boolean < RailsAdminNext::Config::Fields::Base
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)

          register_instance_option :labels do
            {
              true => RailsAdminNext::Icons.svg(:check),
              false => RailsAdminNext::Icons.svg(:cancel),
              nil => RailsAdminNext::Icons.svg(:minus)
            }
          end

          register_instance_option :css_classes do
            {
              true => "success",
              false => "danger",
              nil => "default"
            }
          end

          register_instance_option :filter_operators do
            %w[_discard true false] + (required? ? [] : %w[_separator _present _blank])
          end

          register_instance_option :nullable? do
            properties&.nullable?
          end

          register_instance_option :view_helper do
            :check_box
          end

          register_instance_option :pretty_value do
            %(<span class="badge bg-#{css_classes[form_value]}">#{labels[form_value]}</span>).html_safe
          end

          register_instance_option :export_value do
            value.inspect
          end

          register_instance_option :partial do
            :form_boolean
          end

          def form_value
            case value
            when true, false
              value
            end
          end

          # Accessor for field's help text displayed below input field.
          def generic_help
            ""
          end

          def parse_input(params)
            params[name] = params[name].presence if params.key?(name)
          end
        end
      end
    end
  end
end
