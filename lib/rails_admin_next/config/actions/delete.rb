# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class Delete < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :member do
          true
        end

        register_instance_option :route_fragment do
          "delete"
        end

        register_instance_option :http_methods do
          %i[get delete]
        end

        register_instance_option :authorization_key do
          :destroy
        end

        register_instance_option :controller do
          proc do
            if request.get? # DELETE

              respond_to do |format|
                format.html { render @action.template_name }
                format.js { render @action.template_name, layout: false }
              end

            elsif request.delete? # DESTROY

              begin
                if @object.destroy
                  @auditing_adapter&.delete_object(@object, @abstract_model, _current_user)
                  flash[:success] = t("admin.flash.successful", name: @model_config.label, action: t("admin.actions.delete.done"))
                  redirect_to index_path
                else
                  handle_save_error :delete
                end
              rescue ActiveRecord::DeleteRestrictionError => e
                # dependent: :restrict_with_exception raises instead of adding an error to the
                # record, so there is nothing for handle_save_error to render — report the
                # association the exception names and send the admin back where they came from.
                flash[:error] = t("admin.flash.delete_restricted", name: @model_config.label, reason: e.message)
                redirect_to back_or_index, status: :see_other
              end

            end
          end
        end

        register_instance_option :link_icon do
          :delete
        end

        register_instance_option :writable? do
          !(bindings[:object] && bindings[:object].readonly?)
        end
      end
    end
  end
end
