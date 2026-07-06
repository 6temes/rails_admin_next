# frozen_string_literal: true

require "rails_admin_next/config/fields"
require "rails_admin_next/config/fields/types/password"

# Register a custom field factory for properties named as password. More property
# names can be registered in RailsAdminNext::Config::Fields::Password.column_names
# array.
#
# @see RailsAdminNext::Config::Fields::Types::Password.column_names
# @see RailsAdminNext::Config::Fields.register_factory
RailsAdminNext::Config::Fields.register_factory do |parent, properties, fields|
  if [:password].include?(properties.name)
    fields << RailsAdminNext::Config::Fields::Types::Password.new(parent, properties.name, properties)
    true
  else
    false
  end
end
