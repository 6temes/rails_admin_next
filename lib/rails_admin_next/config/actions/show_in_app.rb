# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class ShowInApp < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :member do
          true
        end

        register_instance_option :visible? do
          authorized? && begin
            bindings[:controller].main_app.url_for(bindings[:object])
          rescue
            false
          end
        end

        register_instance_option :controller do
          proc do
            redirect_to main_app.url_for(@object)
          end
        end

        register_instance_option :link_icon do
          :show_in_app
        end

        register_instance_option :turbo? do
          false
        end
      end
    end
  end
end
