# frozen_string_literal: true

require "rails_admin_next/config/fields/collection_association"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class HasAndBelongsToManyAssociation < RailsAdminNext::Config::Fields::CollectionAssociation
          # Register field type for the type loader
          RailsAdminNext::Config::Fields::Types.register(self)
        end
      end
    end
  end
end
