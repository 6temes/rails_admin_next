# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class HistoryShow < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :authorization_key do
          :history
        end

        register_instance_option :member do
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
            @general = false
            @history = @auditing_adapter&.listing_for_object(@abstract_model, @object, params[:query], params[:sort], params[:sort_reverse], params[:all], params[:page]) || []

            # A frame request from the next-batch frame gets the rows alone, as on the index.
            if turbo_frame_request? && !@model_config.list.numbered_pagination? && @history.respond_to?(:full_page?)
              render partial: "rails_admin_next/main/batch", layout: false, locals: {
                collection: @history, frame_prefix: "history_batch", target: "history_rows", row_partial: "history_row", row_locals: {},
                url_proc: ->(page) { url_for(request.query_parameters.except("page").merge(page:, only_path: true)) }
              }
            else
              render @action.template_name
            end
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
