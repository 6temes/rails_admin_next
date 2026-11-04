# frozen_string_literal: true

module RailsAdminNext
  class MainController < RailsAdminNext::ApplicationController
    include ActionView::Helpers::TextHelper
    include RailsAdminNext::MainHelper
    include RailsAdminNext::ApplicationHelper

    MAX_PICKER_SOURCE_PARENTS = 10

    before_action :check_for_cancel

    helper_method :list_scopes

    def bulk_action
      get_model
      process(params[:bulk_action]) if params[:bulk_action].in?(RailsAdminNext::Config::Actions.all(:bulkable, controller: self, abstract_model: @abstract_model).collect(&:route_fragment))
    end

    def list_entries(model_config = @model_config, auth_scope_key = :index, additional_scope = nil, pagination = !(params[:all] || params[:bulk_ids]))
      scope = model_config.scope
      auth_scope = authorization_scope(auth_scope_key, model_config.abstract_model)
      scope = scope.merge(auth_scope) if auth_scope
      tab = list_scope if model_config == @model_config
      if tab
        scope = scope.public_send(tab)
        scope = within_authorized(scope, auth_scope) if auth_scope
      end
      scope = scope.instance_eval(&additional_scope) if additional_scope
      get_collection(model_config, scope, pagination)
    end

    # The association scope chains after get_collection, which only works on an unpaginated relation.
    def association_entries(model_config, collection_scope)
      scope = model_config.scope
      auth_scope = authorization_scope(:index, model_config.abstract_model)
      scope = scope.merge(auth_scope) if auth_scope
      scope = get_collection(model_config, scope, false)
      collection_scope ? scope.instance_eval(&collection_scope) : scope
    end

    private

    def action_missing(name, *_args)
      action = RailsAdminNext::Config::Actions.find(name.to_sym)
      raise AbstractController::ActionNotFound.new("The action '#{name}' could not be found for #{self.class.name}") unless action

      get_model unless action.root?
      get_object if action.member?
      @authorization_adapter&.authorize(action.authorization_key, @abstract_model, @object)
      @action = action.with({controller: self, abstract_model: @abstract_model, object: @object})
      raise(ActionNotAllowed) unless @action.enabled?

      @page_name = wording_for(:title)

      instance_eval(&@action.controller)
    end

    def method_missing(name, *, &)
      action = RailsAdminNext::Config::Actions.find(name.to_sym)
      if action
        action_missing(name, *, &)
      else
        super
      end
    end

    def respond_to_missing?(sym, include_private)
      if RailsAdminNext::Config::Actions.find(sym)
        true
      else
        super
      end
    end

    def back_or_index
      allowed_return_to?(params[:return_to].to_s) ? params[:return_to] : index_path
    end

    # A leading '/' alone isn't enough to prove same-origin: browsers normalize a leading
    # backslash to '/', so '/\evil.com' would render as the protocol-relative '//evil.com'.
    # Parsing with URI and comparing scheme+host+port (rather than a raw string prefix) also
    # rejects userinfo tricks ('http://legit@evil.com') and no-boundary substring host
    # confusion ('http://legit.com.evil.com').
    def allowed_return_to?(url)
      return false if url.blank? || url == request.fullpath

      uri = URI.parse(url)
      if uri.host
        uri.scheme == request.scheme && uri.host == request.host && uri.port == request.port
      else
        url.start_with?("/") && !url.start_with?("//")
      end
    rescue URI::InvalidURIError
      false
    end

    def get_sort_hash(model_config)
      field = sort_field(model_config)

      column =
        if field.nil? || field.sortable == false # use default sort, asked field does not exist or is not sortable
          model_config.list.sort_by
        else
          field.sort_column
        end

      params[:sort_reverse] ||= "false"
      {sort: column, sort_reverse: (params[:sort_reverse] == (field&.sort_reverse&.to_s || "true"))}
    end

    def sort_field(model_config)
      field = model_config.list.fields.detect { |f| f.name.to_s == params[:sort] }
      # If no sort param, default to the `sort_by` specified in the list config
      field || model_config.list.possible_fields.detect { |f| f.name == model_config.list.sort_by.try(:to_sym) }
    end

    def redirect_to_on_success
      notice = I18n.t("admin.flash.successful", name: @model_config.label, action: I18n.t("admin.actions.#{@action.key}.done"))
      if params[:_add_another]
        redirect_to new_path(return_to: params[:return_to]), flash: {success: notice}
      elsif params[:_add_edit]
        redirect_to edit_path(id: @object.id, return_to: params[:return_to]), flash: {success: notice}
      else
        redirect_to back_or_index, flash: {success: notice}
      end
    end

    def visible_fields(action, model_config = @model_config)
      model_config.send(action).with(controller: self, view: view_context, object: @object).visible_fields
    end

    # Memoized, as export renders through index, which switches @action
    def serialization_schema
      @serialization_schema ||= begin
        section = %i[export show].include?(@action.key) ? @model_config.send(@action.key) : @model_config.list
        SerializationSchema.new(
          section.with(controller: self, view: view_context, object: @object || @abstract_model.model.new),
          include_associations: @action.key == :export
        )
      end
    end

    def sanitize_params_for!(action, model_config = @model_config, target_params = params[@abstract_model.param_key], nested_in = nil)
      return unless target_params.present?

      # A subform never draws the child's link back to the record being edited — the parent
      # association names it, and FormBuilder#nested_field_association? skips it on that name.
      # Deriving the allowlist from visible_fields alone would keep permitting keys no form of
      # ours submits, so drop that one field here too. Only at nested depth: editing a Comment
      # on its own is a legitimate way to set its commentable.
      fields = visible_fields(action, model_config).reject do |field|
        nested_in && field.is_a?(Config::Fields::Association) && field.name == nested_in.inverse_of
      end
      allowed_methods = fields.collect(&:allowed_methods).flatten.uniq.collect(&:to_s) << "id" << "_destroy"
      fields.each { |field| field.parse_input(target_params) }
      target_params.slice!(*allowed_methods)
      target_params.permit! if target_params.respond_to?(:permit!)
      fields.select(&:nested_form).each do |association|
        nested = target_params[association.method_name]
        # accepts_nested_attributes_for takes a hash-of-records ({idx => {…}}) or an
        # array-of-records ([{…}]) for collections, and a single record ({…}) for singular
        # associations. Recurse into every record regardless of the submitted cardinality so a
        # cardinality-flipped param (e.g. an array sent to a has_many) can't smuggle keys past
        # the slice that permit! has already blanket-permitted.
        children_params =
          if nested.is_a?(Array)
            nested
          elsif nested.respond_to?(:values)
            association.multiple? ? nested.values : [nested]
          else
            []
          end
        children_params.each do |children_param|
          sanitize_params_for!(:nested, association.associated_model_config, children_param, association) if children_param.respond_to?(:values)
        end
      end
    end

    def handle_save_error(whereto = :new)
      flash.now[:error] = I18n.t("admin.flash.error", name: @model_config.label, action: I18n.t("admin.actions.#{@action.key}.done").html_safe).html_safe
      # full_messages can carry user-supplied values (e.g. interpolated into a custom validation
      # message), so escape each before marking the assembled list html_safe — otherwise a
      # `<script>` in a validation message would render live in the flash.
      escaped_messages = @object.errors.full_messages.map { |message| ERB::Util.html_escape(message) }
      flash.now[:error] += %(<br>- #{escaped_messages.join("<br>- ")}).html_safe

      respond_to do |format|
        format.html { render whereto, status: :not_acceptable }
        format.js { render whereto, layout: "rails_admin_next/modal", status: :not_acceptable, content_type: Mime[:html].to_s }
      end
    end

    def check_for_cancel
      cancelling = params[:_continue] || (params[:bulk_action] && !params[:bulk_ids])
      return unless cancelling

      redirect_to(back_or_index, notice: I18n.t("admin.flash.noaction"))
    end

    def get_collection(model_config, scope, pagination)
      section = (@action.key == :export) ? model_config.export : model_config.list
      # The sort comes from the list, so export must also load the association a list sort orders by.
      eager_loads = (section.fields + Array(sort_field(model_config))).flat_map(&:eager_load_values).uniq
      options = {}
      options = options.merge(page: (params[:page] || 1).to_i, per: params[:per] || model_config.list.items_per_page) if pagination
      options = options.merge(include: eager_loads) unless eager_loads.blank?
      options = options.merge(get_sort_hash(model_config))
      options = options.merge(query: params[:query]) if params[:query].present?
      options = options.merge(filters: params[:f]) if params[:f].present?
      options = options.merge(bulk_ids: params[:bulk_ids]) if params[:bulk_ids]
      model_config.abstract_model.all(options, scope)
    end

    def list_scopes
      @_list_scopes ||= @model_config.list.with(controller: self, view: view_context, object: @abstract_model.model.new).scopes
    end

    # Export's included associations hold only the rows the user may list on the associated model.
    # Loaded rows are filtered rather than the preload scoped: a through association with a where
    # scope ignores a preload scope, and a through preload reuses its through association's rows,
    # so every association loads in full before any is narrowed.
    def authorize_included(records)
      names = @schema&.dig(:include)&.keys
      return records if @authorization_adapter.nil? || names.blank?

      records = records.to_a
      ActiveRecord::Associations::Preloader.new(records:, associations: names).call
      names.each do |name|
        klass = @abstract_model.model.reflect_on_association(name).klass
        associations = records.map { it.association(name) }
        loaded = klass.where(klass.primary_key => associations.flat_map { Array.wrap(it.target) }.map(&:id))
        allowed = within_authorized(loaded, authorization_scope(:index, RailsAdminNext::AbstractModel.new(klass))).pluck(*Array(klass.primary_key)).to_set
        associations.each do |association|
          association.target =
            if association.collection?
              association.target.select { allowed.include?(it.id) }
            elsif allowed.include?(association.target&.id)
              association.target
            end
        end
      end
      records
    end

    # A row-value IN: `where(primary_key => relation)` renders an empty condition for composite keys.
    def within_authorized(scope, auth_scope)
      key = Array(scope.primary_key).map { scope.arel_table[it] }
      scope.where(Arel::Nodes::In.new(Arel::Nodes::Grouping.new(key), auth_scope.reselect(*key).arel.ast))
    end

    def list_scope
      return if params[:compact]

      if list_scopes.empty? || params[:scope].blank?
        list_scopes.first
      elsif list_scopes.collect(&:to_s).include?(params[:scope])
        params[:scope].to_sym
      end
    end

    def get_association_scope_from_params
      return nil unless params[:associated_collection].present? && params[:source_abstract_model].present?
      return nil unless (source_abstract_model = visible_abstract_model(to_model_name(params[:source_abstract_model])))

      source_model_config = source_abstract_model.config
      action = params[:current_action].in?(%w[create update]) ? params[:current_action] : "edit"
      field = source_model_config.send(action).fields.detect { |f| f.name == params[:associated_collection].to_sym }
      # The picker's params are client-supplied; a field that doesn't target this model would run its scope and labels on the wrong records.
      # Polymorphic pickers never send associated_collection, and their collection ignores the listed records.
      return nil unless field&.association? && !field.polymorphic? && field.associated_model_config == @model_config

      # A new record's picker names no source. A named source that is missing, outside the model's
      # scope or not editable lists the same way, so the response does not reveal which ids exist.
      source_object = nil
      if params[:source_object_id].present?
        source_object = source_abstract_model.get(params[:source_object_id], source_model_config.scope)
        return nil unless source_object && source_editable?(source_abstract_model, source_object, picker_source_parents)
      end

      @association = field.with(controller: self, object: source_object)
      @association.associated_collection_scope
    end

    # The persisted records a nested subform's source sits under, innermost first. Capped because
    # each level costs queries and the chain is client-supplied.
    def picker_source_parents
      Array.wrap(params[:source_parents]).first(MAX_PICKER_SOURCE_PARENTS).map do |parent|
        return [] unless parent.is_a?(ActionController::Parameters) && parent[:model].is_a?(String) && parent[:id].is_a?(String)

        parent
      end
    end

    # A nested subform's record is edited through its parent's form, so it counts as editable when
    # the parent is and the record really belongs to that parent's nested association.
    # Asks the adapter directly: going through the edit action's authorized? would also apply its
    # enabled?/visible settings, changing pickers for hosts that only hide the edit link.
    def source_editable?(abstract_model, object, parents)
      return true unless @authorization_adapter

      edit = RailsAdminNext::Config::Actions.find(:edit)
      return false unless edit

      key = edit.with(controller: self, abstract_model:, object:).authorization_key
      return true if @authorization_adapter.authorized?(key, abstract_model, object)

      parent_ref, *outer_parents = parents
      return false unless parent_ref && (parent_model = visible_abstract_model(to_model_name(parent_ref[:model])))
      return false unless (parent = parent_model.get(parent_ref[:id], parent_model.config.scope))
      return false unless nested_under?(parent_model, parent, abstract_model, object)

      source_editable?(parent_model, parent, outer_parents)
    end

    def nested_under?(parent_model, parent, abstract_model, object)
      parent_model.config.edit.with(controller: self, object: parent).visible_fields.any? do |field|
        next false unless field.nested_form && !field.read_only? && field.associated_model_config == abstract_model.config

        field.multiple? ? parent.public_send(field.name).include?(object) : parent.public_send(field.name) == object
      end
    end
  end
end
