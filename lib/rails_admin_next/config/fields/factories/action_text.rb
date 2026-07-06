# frozen_string_literal: true

require "rails_admin_next/config/fields"
require "rails_admin_next/config/fields/types"

RailsAdminNext::Config::Fields.register_factory do |parent, properties, fields|
  if defined?(::ActionText) && properties.try(:association?) && (match = /\Arich_text_(.+)\Z/.match properties.name) && properties.klass.to_s == "ActionText::RichText"
    field = RailsAdminNext::Config::Fields::Types.load(:action_text).new(parent, match[1], properties)
    fields << field
    true
  else
    false
  end
end
