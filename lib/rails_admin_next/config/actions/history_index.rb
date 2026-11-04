# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class HistoryIndex < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :authorization_key do
          :history
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :visible? do
          authorized? && auditable?
        end

        register_instance_option :route_fragment do
          "history"
        end

        register_instance_option :controller do
          proc do
            @general = true
            listing = [@abstract_model, params[:query], params[:sort], params[:sort_reverse], params[:all], params[:page]]
            @history =
              if @authorization_adapter
                @auditing_adapter&.listing_for_model(*listing, scope: authorization_scope(:history, @abstract_model))
              else
                @auditing_adapter&.listing_for_model(*listing)
              end || []

            render @action.template_name
          end
        end

        register_instance_option :template_name do
          :history
        end

        register_instance_option :link_icon do
          :history
        end
      end
    end
  end
end
