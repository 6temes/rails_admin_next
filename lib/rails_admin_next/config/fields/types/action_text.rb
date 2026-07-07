# frozen_string_literal: true

require "rails_admin_next/config/fields/types/text"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class ActionText < Text
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)

          register_instance_option :partial do
            :form_action_text
          end
        end
      end
    end
  end
end
