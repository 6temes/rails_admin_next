# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class Show < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :member do
          true
        end

        register_instance_option :route_fragment do
          ""
        end

        register_instance_option :breadcrumb_parent do
          [:index, bindings[:abstract_model]]
        end

        register_instance_option :controller do
          proc do
            # HTML first: an Accept-less request arrives as */*, which matches every
            # registered type, so Rails falls back to whichever is declared first.
            respond_to do |format|
              format.html { render @action.template_name }
              format.json { render json: @object }
            end
          end
        end

        register_instance_option :link_icon do
          :show
        end
      end
    end
  end
end
