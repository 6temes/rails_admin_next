# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class Export < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          %i[get post]
        end

        register_instance_option :controller do
          proc do
            format = params[:json] && :json || params[:csv] && :csv || params[:xml] && :xml
            # Stream the table only on a non-GET, CSRF-protected request. GET (forgery-exempt)
            # renders the form so `GET /export?json=1&schema[...]` can't exfiltrate the whole
            # table with attacker-chosen columns; the export form posts back to this same action.
            if format && !request.get?
              request.format = format
              @schema = HashHelper.symbolize(params[:schema].slice(:except, :include, :methods, :only).permit!.to_h) if params[:schema] # to_json and to_xml expect symbols for keys AND values.
              @objects = list_entries(@model_config, :export)
              index
            else
              render @action.template_name
            end
          end
        end

        register_instance_option :bulkable? do
          true
        end

        register_instance_option :link_icon do
          :export
        end
      end
    end
  end
end
