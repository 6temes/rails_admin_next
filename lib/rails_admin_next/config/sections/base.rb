# frozen_string_literal: true

require "rails_admin_next/config/proxyable"
require "rails_admin_next/config/configurable"
require "rails_admin_next/config/inspectable"
require "rails_admin_next/config/has_fields"
require "rails_admin_next/config/has_groups"
require "rails_admin_next/config/has_description"

module RailsAdminNext
  module Config
    module Sections
      # Configuration of the show view for a new object
      class Base
        include RailsAdminNext::Config::Proxyable
        include RailsAdminNext::Config::Configurable
        include RailsAdminNext::Config::Inspectable

        include RailsAdminNext::Config::HasFields
        include RailsAdminNext::Config::HasGroups
        include RailsAdminNext::Config::HasDescription

        attr_reader :abstract_model, :parent, :root

        NAMED_INSTANCE_VARIABLES = %i[@parent @root @abstract_model].freeze

        def initialize(parent)
          @parent = parent
          @root = parent.root

          @abstract_model = root.abstract_model
        end
      end
    end
  end
end
