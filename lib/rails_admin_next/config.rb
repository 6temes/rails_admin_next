# frozen_string_literal: true

require "rails_admin_next/config/lazy_model"
require "rails_admin_next/config/sections/list"
require "rails_admin_next/support/composite_keys_serializer"
require "active_support/core_ext/module/attribute_accessors"

module RailsAdminNext
  module Config
    # RailsAdminNext authentication is fully pluggable — set authenticate_with to any proc.
    # Works with Devise, Rodauth, authentication-zero, has_secure_password, or any Warden setup.
    #
    # @see RailsAdminNext::Config.authenticate_with
    # @see RailsAdminNext::Config.authorize_with
    DEFAULT_AUTHENTICATION = proc {}

    DEFAULT_AUTHORIZE = proc {}

    DEFAULT_AUDIT = proc {}

    DEFAULT_CURRENT_USER = proc {}

    class << self
      # Configuration option to specify which models you want to exclude.
      attr_accessor :excluded_models

      # Configuration option to specify a allowlist of models you want to RailsAdminNext to work with.
      # The excluded_models list applies against the allowlist as well and further reduces the models
      # RailsAdminNext will use.
      # If included_models is left empty ([]), then RailsAdminNext will automatically use all the models
      # in your application (less any excluded_models you may have specified).
      attr_accessor :included_models

      # Fields to be hidden in show, create and update views
      attr_reader :default_hidden_fields

      # Default items per page value used if a model level option has not
      # been configured
      attr_accessor :default_items_per_page

      # Default association limit
      attr_accessor :default_associated_collection_limit

      attr_reader :default_search_operator

      # Configuration option to specify which method names will be searched for
      # to be used as a label for object records. This defaults to [:name, :title]
      attr_accessor :label_methods

      # hide blank fields in show view if true
      attr_accessor :compact_show_view

      # Tell browsers whether to use the native HTML5 validations (novalidate form option).
      attr_accessor :browser_validations

      # Color scheme of the admin UI: :auto (default) follows the OS preference,
      # :light or :dark pins it. Rendered as the layout's <meta name="color-scheme">,
      # which every light-dark() token pair in the engine stylesheets resolves against.
      attr_reader :color_scheme

      # set parent controller
      attr_reader :parent_controller

      # Stores model configuration objects in a hash identified by model's class
      # name.
      #
      # @see RailsAdminNext.config
      attr_reader :registry

      # Bootstrap CSS classes used for Navigation bar
      attr_accessor :navbar_css_classes

      # show Gravatar in Navigation bar
      attr_accessor :show_gravatar

      # accepts a hash of static links to be shown below the main navigation
      attr_accessor :navigation_static_links
      attr_accessor :navigation_static_label

      # For customization of composite keys representation
      attr_accessor :composite_keys_serializer

      # Setup authentication to be run as a before filter
      # This is run inside the controller instance so you can setup any authentication you need to
      #
      # By default, the authentication will run via warden if available
      # and will run the default.
      #
      # Works with any auth: Devise, Rodauth, authentication-zero, has_secure_password.
      #
      # @example Warden (any setup)
      #   RailsAdminNext.config do |config|
      #     config.authenticate_with do
      #       warden.authenticate! scope: :user
      #     end
      #   end
      #
      # @example Custom scope
      #   RailsAdminNext.config do |config|
      #     config.authenticate_with do
      #       warden.authenticate! scope: :paranoid
      #     end
      #   end
      #
      # @see RailsAdminNext::Config::DEFAULT_AUTHENTICATION
      def authenticate_with(&blk)
        @authenticate = blk if blk
        @authenticate || DEFAULT_AUTHENTICATION
      end

      # Content Security Policy for the admin. Opt-in: the engine enforces no policy by default.
      #
      # Pass a block receiving an `ActionDispatch::ContentSecurityPolicy`; it is applied per-request
      # to admin responses only. The engine threads a per-request nonce onto every inline tag it
      # emits (the importmap JSON, the import entry point, the index column-width style), so a
      # policy may use `:self` + nonces without breaking the admin's own modules.
      # Pass `report_only: true` to send `Content-Security-Policy-Report-Only` instead of enforcing.
      #
      # NOTE: the admin still renders a few inline `style="…"` attributes (enumerated in
      # docs/security.md), so a `style-src` directive currently needs `:unsafe_inline`.
      #
      # @example Enforce a locked-down policy for the admin
      #   RailsAdminNext.config do |config|
      #     config.content_security_policy do |policy|
      #       policy.default_src :self
      #       policy.script_src  :self
      #       policy.style_src   :self, :unsafe_inline
      #       policy.img_src     :self, :data
      #     end
      #   end
      #
      # @example Report-only while tuning it
      #   RailsAdminNext.config do |config|
      #     config.content_security_policy(report_only: true) { |policy| policy.default_src :self }
      #   end
      def content_security_policy(report_only: false, &block)
        if block
          @content_security_policy = block
          @content_security_policy_report_only = report_only
        end
        @content_security_policy
      end

      # Whether the opt-in CSP is sent as report-only (set via #content_security_policy).
      attr_reader :content_security_policy_report_only

      # Setup auditing/versioning provider that observe objects lifecycle
      def audit_with(*args, &block)
        extension = args.shift
        if extension
          klass = RailsAdminNext::AUDITING_ADAPTERS[extension]
          klass.setup if klass.respond_to? :setup
          @audit = proc do
            @auditing_adapter = klass.new(*([self] + args).compact, &block)
          end
        elsif block
          @audit = block
        end
        @audit || DEFAULT_AUDIT
      end

      # Setup authorization to be run as a before filter
      # This is run inside the controller instance so you can setup any authorization you need to.
      #
      # By default, there is no authorization.
      #
      # @example Custom
      #   RailsAdminNext.config do |config|
      #     config.authorize_with do
      #       redirect_to root_path unless warden.user.is_admin?
      #     end
      #   end
      #
      # To use an authorization adapter, pass the name of the adapter. For example,
      # to use with CanCanCan[https://github.com/CanCanCommunity/cancancan/], pass it like this.
      #
      # @example CanCanCan
      #   RailsAdminNext.config do |config|
      #     config.authorize_with :cancancan
      #   end
      #
      # See the wiki[https://github.com/railsadminteam/rails_admin/wiki] for more on authorization.
      #
      # @see RailsAdminNext::Config::DEFAULT_AUTHORIZE
      def authorize_with(*args, &block)
        extension = args.shift
        if extension
          klass = RailsAdminNext::AUTHORIZATION_ADAPTERS[extension]
          klass.setup if klass.respond_to? :setup
          @authorize = proc do
            @authorization_adapter = klass.new(*([self] + args).compact, &block)
          end
        elsif block
          @authorize = block
        end
        @authorize || DEFAULT_AUTHORIZE
      end

      # Setup configuration using an extension-provided ConfigurationAdapter
      #
      # @example Custom configuration for role-based setup.
      #   RailsAdminNext.config do |config|
      #     config.configure_with(:custom) do |config|
      #       config.models = ['User', 'Comment']
      #       config.roles  = {
      #         'Admin' => :all,
      #         'User'  => ['User']
      #       }
      #     end
      #   end
      def configure_with(extension)
        configuration = RailsAdminNext::CONFIGURATION_ADAPTERS[extension].new
        yield(configuration) if block_given?
      end

      # Setup a different method to determine the current user or admin logged in.
      # This is run inside the controller instance and made available as a helper.
      #
      # By default, _request.env["warden"].user_ or _current_user_ will be used (auth-library agnostic).
      #
      # @example Custom
      #   RailsAdminNext.config do |config|
      #     config.current_user_method do
      #       current_admin
      #     end
      #   end
      #
      # @see RailsAdminNext::Config::DEFAULT_CURRENT_USER
      def current_user_method(&block)
        @current_user = block if block
        @current_user || DEFAULT_CURRENT_USER
      end

      # Validate at configuration time so a typo fails with an actionable
      # message instead of a bare KeyError on the first admin page render.
      def color_scheme=(scheme)
        raise ArgumentError.new("color_scheme must be :auto, :light or :dark (got #{scheme.inspect})") unless %i[auto light dark].include?(scheme)

        @color_scheme = scheme
      end

      def default_search_operator=(operator)
        if %w[default like not_like starts_with ends_with is =].include? operator
          @default_search_operator = operator
        else
          raise ArgumentError.new("Search operator '#{operator}' not supported")
        end
      end

      # pool of all found model names from the whole application
      def models_pool
        (viable_models - excluded_models.collect(&:to_s)).uniq.sort
      end

      # Loads a model configuration instance from the registry or registers
      # a new one if one is yet to be added.
      #
      # First argument can be an instance of requested model, its class object,
      # its class name as a string or symbol or a RailsAdminNext::AbstractModel
      # instance.
      #
      # If a block is given it is evaluated in the context of configuration instance.
      #
      # Returns given model's configuration
      #
      # @see RailsAdminNext::Config.registry
      def model(entity, &block)
        key =
          case entity
          when RailsAdminNext::AbstractModel
            entity.model.try(:name).try :to_sym
          when Class, ConstLoadSuppressor::ConstProxy
            entity.name.to_sym
          when String, Symbol
            entity.to_sym
          else
            entity.class.name.to_sym
          end

        @registry[key] ||= RailsAdminNext::Config::LazyModel.new(key.to_s)
        @registry[key].add_deferred_block(&block) if block
        @registry[key]
      end

      # The engine ships a single zero-build asset path: browser-native ESM + CSS served by Propshaft
      # and pinned via an engine-owned importmap. The option is vestigial — assignment is deprecated
      # and ignored, kept only so a host's legacy `config.asset_source = :sprockets` doesn't raise.
      def asset_source
        :importmap
      end

      def asset_source=(_)
        RailsAdminNext.deprecator.warn("The asset_source configuration option was removed, RailsAdminNext serves a single importmap + Propshaft asset pipeline now.")
      end

      def default_hidden_fields=(fields)
        if fields.is_a?(Array)
          @default_hidden_fields = {}
          @default_hidden_fields[:edit] = fields
          @default_hidden_fields[:show] = fields
        else
          @default_hidden_fields = fields
        end
      end

      def parent_controller=(name)
        @parent_controller = name

        if defined?(RailsAdminNext::ApplicationController) || defined?(RailsAdminNext::MainController)
          RailsAdminNext::Config::ConstLoadSuppressor.allowing do
            RailsAdminNext.send(:remove_const, :ApplicationController)
            RailsAdminNext.send(:remove_const, :MainController)
            load RailsAdminNext::Engine.root.join("app/controllers/rails_admin_next/application_controller.rb")
            load RailsAdminNext::Engine.root.join("app/controllers/rails_admin_next/main_controller.rb")
          end
        end
      end

      def total_columns_width=(_)
        RailsAdminNext.deprecator.warn("The total_columns_width configuration option is deprecated and has no effect.")
      end

      def sidescroll=(_)
        RailsAdminNext.deprecator.warn("The sidescroll configuration option was removed, it is always enabled now.")
      end

      # Setup actions to be used.
      def actions(&block)
        return unless block

        RailsAdminNext::Config::Actions.reset
        RailsAdminNext::Config::Actions.instance_eval(&block)
      end

      # Returns all model configurations
      #
      # @see RailsAdminNext::Config.registry
      def models
        RailsAdminNext::AbstractModel.all.collect { |m| model(m) }
      end

      # Reset all configurations to defaults.
      #
      # @see RailsAdminNext::Config.registry
      def reset
        @compact_show_view = true
        @browser_validations = true
        @color_scheme = :auto
        @authenticate = nil
        @authorize = nil
        @audit = nil
        @current_user = nil
        @default_hidden_fields = {}
        @default_hidden_fields[:base] = [:_type]
        @default_hidden_fields[:edit] = %i[id _id created_at created_on deleted_at updated_at updated_on deleted_on]
        @default_hidden_fields[:show] = %i[id _id created_at created_on deleted_at updated_at updated_on deleted_on]
        @default_items_per_page = 20
        @default_associated_collection_limit = 100
        @default_search_operator = "default"
        @excluded_models = []
        @included_models = []
        @label_methods = %i[name title]
        @registry = {}
        @navbar_css_classes = %w[navbar-dark bg-primary border-bottom]
        @show_gravatar = true
        @navigation_static_links = {}
        @navigation_static_label = nil
        @composite_keys_serializer = RailsAdminNext::Support::CompositeKeysSerializer
        @parent_controller = "::ActionController::Base"
        @content_security_policy = nil
        @content_security_policy_report_only = false
        RailsAdminNext::Config::Actions.reset
        RailsAdminNext::AbstractModel.reset
      end

      # Reset a provided model's configuration.
      #
      # @see RailsAdminNext::Config.registry
      def reset_model(model)
        key = model.is_a?(Class) ? model.name.to_sym : model.to_sym
        @registry.delete(key)
      end

      # Perform reset, then load RailsAdminNext initializer again
      def reload!
        reset
        load RailsAdminNext::Engine.config.initializer_path
      end

      # Get all models that are configured as visible sorted by their weight and label.
      #
      # @see RailsAdminNext::Config::Hideable
      def visible_models(bindings)
        visible_models_with_bindings(bindings).sort do |a, b|
          if (weight_order = a.weight <=> b.weight) == 0
            a.label.casecmp(b.label)
          else
            weight_order
          end
        end
      end

      private

      def viable_models
        included_models.collect(&:to_s).presence || begin
          @@system_models ||= # memoization for tests
            ([Rails.application] + Rails::Engine.subclasses.collect(&:instance)).flat_map do |app|
              (app.paths["app/models"].to_a + app.config.eager_load_paths).collect do |load_path|
                Dir.glob(app.root.join(load_path)).collect do |load_dir|
                  path_prefix = "#{app.root.join(load_dir)}/"
                  Dir.glob("#{load_dir}/**/*.rb").collect do |filename|
                    # app/models/module/class.rb => module/class.rb => module/class => Module::Class
                    filename.delete_prefix(path_prefix).chomp(".rb").camelize
                  end
                end
              end
            end.flatten.reject { |m| m.starts_with?("Concerns::") } # rubocop:disable Style/MultilineBlockChain

          @@system_models + @registry.keys.collect(&:to_s)
        end
      end

      def visible_models_with_bindings(bindings)
        models.collect { |m| m.with(bindings) }.select do |m|
          m.visible? &&
            RailsAdminNext::Config::Actions.find(:index, bindings.merge(abstract_model: m.abstract_model)).try(:authorized?) &&
            (!m.abstract_model.embedded? || m.abstract_model.cyclic?)
        end
      end
    end

    # Set default values for configuration options on load
    reset
  end
end
