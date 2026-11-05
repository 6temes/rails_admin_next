# frozen_string_literal: true

require "active_support/core_ext/string/strip"

module RailsAdminNext
  module Extensions
    module PaperTrail
      class VersionProxy
        def initialize(version, user_class = User)
          @version = version
          @user_class = user_class
        end

        def message
          @message = @version.event
          (@version.respond_to?(:changeset) && @version.changeset.present?) ? @message + " [" + @version.changeset.to_a.collect { |c| "#{c[0]} = #{c[1][1]}" }.join(", ") + "]" : @message
        end

        def created_at
          @version.created_at
        end

        def table
          @version.item_type
        end

        def username
          begin
            @user_class.find(@version.whodunnit).try(:email)
          rescue
            nil
          end || @version.whodunnit
        end

        def item
          @version.item_id
        end
      end

      module ControllerExtension
        def user_for_paper_trail
          _current_user.try(:id) || _current_user
        end
      end

      class AuditingAdapter
        COLUMN_MAPPING = {
          table: :item_type,
          username: :whodunnit,
          item: :item_id,
          created_at: :created_at,
          message: :event
        }.freeze
        E_USER_CLASS_NOT_SET = <<~ERROR
          Please set up PaperTrail's user class explicitly.

              config.audit_with :paper_trail do
                user_class { User }
              end
        ERROR
        E_VERSION_MODEL_NOT_SET = <<~ERROR
          Please set up PaperTrail's version model explicitly.

              config.audit_with :paper_trail do
                version_class { PaperTrail::Version }
              end

          If you have configured a model to use a custom version class
          (https://github.com/paper-trail-gem/paper_trail#6a-custom-version-classes)
          that configuration will take precedence over what you specify in `audit_with`.
        ERROR

        include RailsAdminNext::Config::Configurable

        def self.setup
          raise "PaperTrail not found" unless defined?(::PaperTrail)

          RailsAdminNext::Extensions::ControllerExtension.include ControllerExtension
        end

        def initialize(controller, user_class_name = nil, version_class_name = nil, &block)
          @controller = controller
          @controller&.send(:set_paper_trail_whodunnit)

          user_class { user_class_name.to_s.constantize } if user_class_name
          version_class { version_class_name.to_s.constantize } if version_class_name

          instance_eval(&block) if block
        end

        register_instance_option :user_class do
          User
        rescue NameError
          raise E_USER_CLASS_NOT_SET
        end

        register_instance_option :version_class do
          PaperTrail::Version
        rescue NameError
          raise E_VERSION_MODEL_NOT_SET
        end

        register_instance_option :sort_by do
          {id: :desc}
        end

        # +scopes+ maps each AbstractModel the user may list to the relation that user may see; nil
        # means unrestricted. Under scopes, a version shows only while its item is in its model's
        # relation, so a deleted record's versions drop out.
        def latest(count = 100, scopes: nil)
          versions = scopes ? versions_within(scopes) : version_class.all
          versions
            .order(sort_by).includes(:item).limit(count)
            .collect { |version| VersionProxy.new(version, user_class) }
        end

        # Optional in the auditing adapter contract: the history actions hide themselves for a model
        # whose adapter answers false, and stay visible for an adapter that does not define it.
        def auditable?(abstract_model)
          versioned?(abstract_model.model)
        end

        def delete_object(_object, _model, _user)
          # do nothing
        end

        def update_object(_object, _model, _user, _changes)
          # do nothing
        end

        def create_object(_object, _abstract_model, _user)
          # do nothing
        end

        # +scope+ is the relation of the model's records the user may see; nil means unrestricted.
        def listing_for_model(model, query, sort, sort_reverse, all, page, per_page = RailsAdminNext::Config.default_items_per_page || 20, scope: nil)
          listing_for_model_or_object(model, nil, query, sort, sort_reverse, all, page, per_page, scope:)
        end

        def listing_for_object(model, object, query, sort, sort_reverse, all, page, per_page = RailsAdminNext::Config.default_items_per_page || 20)
          listing_for_model_or_object(model, object, query, sort, sort_reverse, all, page, per_page)
        end

        protected

        # - model - a RailsAdminNext::AbstractModel
        def listing_for_model_or_object(model, object, query, sort, sort_reverse, all, page, per_page, scope: nil)
          sort =
            if sort.present?
              {COLUMN_MAPPING[sort.to_sym] => sort_reverse ? :desc : :asc}
            else
              sort_by
            end

          versions =
            if !auditable?(model) then version_class.none
            elsif object.nil? then versions_for_model(model, scope)
            else object.public_send(model.model.versions_association_name)
            end
          versions = versions.where("event LIKE ?", "%#{query}%") if query.present?
          versions = versions.reorder(sort)

          paginate_versions(versions, all, (page.presence || 1).to_i, per_page.to_i)
        end

        # Maps a page of PaperTrail versions onto VersionProxy objects and wraps
        # them in the shared view-facing pagination collection. The `all` mode
        # skips offset pagination and exposes every version on a single page.
        def paginate_versions(versions, all, current_page, per_page)
          if all
            proxies = versions.map { |version| VersionProxy.new(version, user_class) }
            return RailsAdminNext::PaginatedCollection.new(proxies, current_page: 1, per_page: [proxies.size, 1].max, total_count: proxies.size, total_pages: 1)
          end

          recordset = GearedPagination::Recordset.new(versions, per_page:)
          page = recordset.page(current_page)
          proxies = page.records.map { |version| VersionProxy.new(version, user_class) }
          RailsAdminNext::PaginatedCollection.new(proxies, current_page: page.number, per_page:, total_count: recordset.records_count)
        end

        def versions_for_model(model, scope = nil)
          version_class_for(model.model).where(versions_condition(model.model, scope))
        end

        def versions_condition(model, scope)
          if scope
            {item_type: model.base_class.name, item_id: scope.reselect(model.primary_key)}
          elsif model.base_class == model
            {item_type: model.name}
          else
            {item_type: model.base_class.name, item_id: model.all}
          end
        end

        def versions_within(scopes)
          scopes.filter_map { |abstract_model, scope|
            model = abstract_model.model
            version_class.where(versions_condition(model, scope)) if versioned?(model)
          }.reduce(:or) || version_class.none
        end

        def versioned?(model)
          model.respond_to?(:paper_trail_options)
        end

        # PT can be configured to use [custom version
        # classes](https://github.com/paper-trail-gem/paper_trail#6a-custom-version-classes)
        #
        # ```ruby
        # has_paper_trail versions: { class_name: 'MyVersion' }
        # ```
        def version_class_for(model)
          model.paper_trail.version_class
        end
      end
    end
  end
end
