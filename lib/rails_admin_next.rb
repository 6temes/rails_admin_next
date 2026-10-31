# frozen_string_literal: true

require "rails_admin_next/engine"
require "rails_admin_next/abstract_model"
require "rails_admin_next/config"
require "rails_admin_next/config/const_load_suppressor"
require "rails_admin_next/icons"
require "rails_admin_next/extension"
require "rails_admin_next/extensions/cancancan"
require "rails_admin_next/extensions/pundit"
require "rails_admin_next/extensions/action_policy"
require "rails_admin_next/extensions/paper_trail"
require "rails_admin_next/support/csv_converter"
require "rails_admin_next/support/hash_helper"
require "rails_admin_next/support/paginated_collection"
require "rails_admin_next/support/serialization_schema"
require "yaml"

module RailsAdminNext
  extend RailsAdminNext::Config::ConstLoadSuppressor

  # Setup RailsAdminNext
  #
  # Given the first argument is a model class, a model class name
  # or an abstract model object proxies to model configuration method.
  #
  # If only a block is passed it is stored to initializer stack to be evaluated
  # on first request in production mode and on each request in development. If
  # initialization has already occurred (in other words RailsAdminNext.setup has
  # been called) the block will be added to stack and evaluated at once.
  #
  # Otherwise returns RailsAdminNext::Config class.
  #
  # @see RailsAdminNext::Config
  def self.config(entity = nil, &)
    if entity
      RailsAdminNext::Config.model(entity, &)
    elsif block_given?
      RailsAdminNext::Config::ConstLoadSuppressor.suppressing { yield(RailsAdminNext::Config) }
    else
      RailsAdminNext::Config
    end
  end

  # Deprecator for RailsAdminNext's own configuration options. Rails 8.1 made the class-level
  # ActiveSupport::Deprecation.warn private, so deprecations go through an instance deprecator.
  # Intentionally left unregistered, so a deprecated-but-removed option warns rather than raising
  # even in a host whose deprecation behavior is :raise — upgrading must never blow up at boot.
  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new(RailsAdminNext::Version.to_s, "RailsAdminNext")
  end

  def self.yaml_load(yaml)
    deprecator.warn("RailsAdminNext.yaml_load is deprecated and will be removed. Call YAML.safe_load directly.")
    YAML.safe_load(yaml)
  end

  def self.yaml_dump(object)
    deprecator.warn("RailsAdminNext.yaml_dump is deprecated and will be removed. Call YAML.dump directly.")
    YAML.dump(object)
  end
end
