# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class Dashboard < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :root? do
          true
        end

        register_instance_option :breadcrumb_parent do
          nil
        end

        register_instance_option :auditing_versions_limit do
          100
        end

        register_instance_option :controller do
          proc do
            history = @action.history? && @auditing_adapter
            if history || @action.statistics?
              model_configs = RailsAdminNext::Config.visible_models(controller: self)
              scopes = model_configs.to_h { [it.abstract_model, authorization_scope(:index, it.abstract_model)] }
            end
            if history
              @history =
                if @authorization_adapter
                  @auditing_adapter.latest(@action.auditing_versions_limit, scopes:)
                else
                  @auditing_adapter.latest(@action.auditing_versions_limit)
                end
            end
            if @action.statistics?
              @abstract_models = model_configs.map(&:abstract_model)
              @most_recent_created = {}
              @count = {}
              @max = 0
              model_configs.each do |config|
                current_count = config.abstract_model.count({}, scopes[config.abstract_model])
                @max = (current_count > @max) ? current_count : @max
                name = config.abstract_model.model.name
                @count[name] = current_count
                @most_recent_created[name] = config.last_created_at
              end
            end
            render @action.template_name, status: @status_code || :ok
          end
        end

        register_instance_option :route_fragment do
          ""
        end

        register_instance_option :link_icon do
          :dashboard
        end

        register_instance_option :statistics? do
          true
        end

        register_instance_option :history? do
          true
        end
      end
    end
  end
end
