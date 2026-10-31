# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class Index < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          %i[get post]
        end

        register_instance_option :route_fragment do
          ""
        end

        register_instance_option :breadcrumb_parent do
          parent_model = bindings[:abstract_model].try(:config).try(:parent)
          am = parent_model && RailsAdminNext.config(parent_model).try(:abstract_model)
          if am
            [:index, am]
          else
            [:dashboard]
          end
        end

        register_instance_option :controller do
          proc do
            @objects ||=
              if params[:associated_collection].present?
                association_entries(@model_config, get_association_scope_from_params)
              else
                list_entries
              end

            respond_to do |format|
              format.html do
                render @action.template_name, status: @status_code || :ok
              end

              format.json do
                output =
                  if params[:compact]
                    if @association
                      @association.collection(@objects).collect { |(label, id)| {id: id, label: label} }
                    else
                      @objects.collect { |object| {id: object.id.to_s, label: object.send(@model_config.object_label_method).to_s} }
                    end
                  else
                    @objects.to_json(@schema || serialization_schema.default)
                  end

                if params[:send_data]
                  send_data output, filename: "#{params[:model_name]}_#{DateTime.now.strftime("%Y-%m-%d_%Hh%Mm%S")}.json"
                else
                  render json: output, root: false
                end
              end

              format.xml do
                output = @objects.map { |object| object.serializable_hash(@schema || serialization_schema.default) }.to_xml(root: @abstract_model.model.model_name.plural)
                if params[:send_data]
                  send_data output, filename: "#{params[:model_name]}_#{DateTime.now.strftime("%Y-%m-%d_%Hh%Mm%S")}.xml"
                else
                  render xml: output
                end
              end

              format.csv do
                header, encoding, output = CSVConverter.new(@objects, @schema).to_csv(params[:csv_options].permit!.to_h)
                if params[:send_data]
                  send_data output,
                    type: "text/csv; charset=#{encoding}; #{"header=present" if header}",
                    disposition: "attachment; filename=#{params[:model_name]}_#{DateTime.now.strftime("%Y-%m-%d_%Hh%Mm%S")}.csv"
                else
                  render plain: output
                end
              end
            end
          end
        end

        register_instance_option :link_icon do
          :list
        end
      end
    end
  end
end
