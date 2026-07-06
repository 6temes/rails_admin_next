# frozen_string_literal: true

require "rails_admin_next/config/fields"
require "rails_admin_next/config/fields/types"
require "rails_admin_next/config/fields/types/password"

# Register a custom field factory for models with an encrypted_password column (e.g. Devise, has_secure_password variants)
RailsAdminNext::Config::Fields.register_factory do |parent, properties, fields|
  if properties.name == :encrypted_password
    extensions = %i[password_salt reset_password_token remember_token]
    fields << RailsAdminNext::Config::Fields::Types.load(:password).new(parent, :password, properties)
    fields << RailsAdminNext::Config::Fields::Types.load(:password).new(parent, :password_confirmation, properties)
    extensions.each do |ext|
      properties = parent.abstract_model.properties.detect { |p| ext == p.name }
      next unless properties

      field = fields.detect { |f| f.name == ext }
      unless field
        RailsAdminNext::Config::Fields.default_factory.call(parent, properties, fields)
        field = fields.last
      end
      field.hide
    end
    true
  else
    false
  end
end
