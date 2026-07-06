# frozen_string_literal: true

require "rails_admin_next/config/fields/group"

module RailsAdminNext
  module Config
    module Groupable
      # Register a group instance variable and accessor methods for objects
      # extending the has groups mixin. The extended objects must implement
      # reader for a parent object which includes this module.
      #
      # @see RailsAdminNext::Config::HasGroups.group
      # @see RailsAdminNext::Config::Fields::Group
      def group(name = nil)
        @group = parent.group(name) unless name.nil? # setter
        @group ||= parent.group(:default) # getter
      end
    end
  end
end
